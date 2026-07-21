<#
.SYNOPSIS
    Detection — Enable Windows Location Service with end-user control & Automatic Time Zone Feature.

.DESCRIPTION
    Exits 1 when any of the following is not in the desired state:
      - AllowLocation CSP value present (should be removed)
      - DisableLocation != 0
      - ConsentStore Value != 'Allow' (HKLM or HKU)
      - ConsentStore LastSetTime missing (HKLM or HKU)
      - OOBE PrivacyConsentStatus != 1
      - CAM DB UserGlobal row for ('location', <sid>) != 1
      - lfsvc or tzautoupdate StartType != Manual

    If no interactive console user is present, exits 0 — Intune retries next cycle.

.NOTES
    Run as:       SYSTEM, 64-bit PowerShell
    Assignment:   Users (not devices) — required to resolve the console user SID
    Dependencies: winsqlite3.dll (Windows 10+ has this in the system by default) *OR* sqlite3.exe (must be copied to the device via other means if used; detection looks for it in %ProgramData%\sqlite-tools\sqlite3.exe)
    Exit codes:   0 = compliant or no user; 1 = drift detected or detection failed
#>
$ErrorActionPreference = 'Stop'

# Persistent logging: IME cleans up its per-run stdout/stderr files after reporting results,
# so failures during Autopilot leave no on-disk trail. Append-only log survives that cleanup.
$script:LogSource = 'Detection'
$script:PersistentLogPath = "$env:windir\Logs\glueckkanja\Remediations\enable-location-service-and-automatic-timezone\activity.log"

try {
    # Functions
    Function Write-PersistentLog {
        param (
            [Parameter(Mandatory=$true)][string]$Message,
            [ValidateSet('Info','Warn','Error')][string]$Level = 'Info'
        )
        try {
            $logDir = Split-Path -Parent $script:PersistentLogPath
            if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
            # Rotate when the log exceeds 1 MB: any previous backup (.log.1) is overwritten, current file becomes the new .log.1, a fresh file starts.
            if ((Test-Path $script:PersistentLogPath) -and ((Get-Item $script:PersistentLogPath).Length -gt 1MB)) {
                $backupPath = "$script:PersistentLogPath.1"
                if (Test-Path $backupPath) { Remove-Item -Path $backupPath -Force -ErrorAction SilentlyContinue }
                Move-Item -Path $script:PersistentLogPath -Destination $backupPath -Force -ErrorAction SilentlyContinue
            }
            $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
            Add-Content -Path $script:PersistentLogPath -Value ("{0} [{1}] [{2}] {3}" -f $stamp, $Level, $script:LogSource, $Message) -ErrorAction SilentlyContinue
        } catch {
            # Logging is best-effort; never let it fail the script
        }
    }

    Function Wait-ForReadiness {
        # Polls for two preconditions that may briefly be unavailable during early Autopilot User ESP:
        #   - CAM DB file exists (camsvc creates it on first user sign-in)
        #   - HKU hive for the user SID is loaded
        # Returns $true as soon as both are present, $false if the timeout elapses.
        param (
            [Parameter(Mandatory=$true)][string]$UserSid,
            [Parameter(Mandatory=$true)][string]$CamDbPath,
            [int]$MaxAttempts = 12,
            [int]$DelaySeconds = 10
        )
        for ($i = 1; $i -le $MaxAttempts; $i++) {
            $dbReady = Test-Path -Path $CamDbPath -PathType Leaf
            $hiveReady = Test-Path -Path "Registry::HKEY_USERS\$UserSid"
            if ($dbReady -and $hiveReady) { return $true }
            if ($i -lt $MaxAttempts) { Start-Sleep -Seconds $DelaySeconds }
        }
        return $false
    }

    Function Test-RegistryValueExists {
        # Non-throwing existence check. Avoid -ErrorAction Stop inside try/catch because PS 5.1's
        # Start-Transcript logs the raised ErrorRecord verbatim even when it's caught — creates
        # noise in the forensic transcript.
        param (
            [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Path,
            [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$ValueName
        )
        if (-not (Test-Path -LiteralPath $Path)) { return $false }
        $props = Get-ItemProperty -LiteralPath $Path -ErrorAction SilentlyContinue
        return ($null -ne $props -and $props.PSObject.Properties.Name -contains $ValueName)
    }

    Function Get-RegistryValueOrNull {
        param (
            [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Path,
            [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$ValueName
        )
        if (-not (Test-Path -LiteralPath $Path)) { return $null }
        $props = Get-ItemProperty -LiteralPath $Path -ErrorAction SilentlyContinue
        if ($null -eq $props -or $props.PSObject.Properties.Name -notcontains $ValueName) { return $null }
        return $props.$ValueName
    }

    Function Get-CamUserGlobalValue {
        # Returns the Value for ('location', $UserSid) in UserGlobal, or $null if no matching row exists.
        param (
            [Parameter(Mandatory=$true)][string]$UserSid
        )
        if ($useSQLiteExe) {
            $sql = "SELECT Value FROM UserGlobal WHERE Capability = 'location' AND User = '$UserSid';"
            $result = $sql | & $sqlitePath $CamDatabasePath
            if ($LASTEXITCODE -ne 0) {
                throw "sqlite3.exe exited with code $LASTEXITCODE while reading from the CAM database."
            }
            if ($null -eq $result -or [string]::IsNullOrWhiteSpace("$result")) { return $null }
            if ($result -is [array]) { $result = $result[0] }
            return [int]$result.ToString().Trim()
        }
        else {
            $dbHandle = [IntPtr]::Zero
            if ([Win32.NativeSQLiteRead]::Open($CamDatabasePath, [ref]$dbHandle) -ne 0) {
                throw "Could not open CAM database file at $CamDatabasePath."
            }
            try {
                $sql = "SELECT Value FROM UserGlobal WHERE Capability = 'location' AND User = '$UserSid';"
                $stmt = [IntPtr]::Zero
                $tail = [IntPtr]::Zero
                $prep = [Win32.NativeSQLiteRead]::Prepare($dbHandle, $sql, -1, [ref]$stmt, [ref]$tail)
                if ($prep -ne 0) {
                    throw "CAM database read failed: sqlite3_prepare_v2 returned $prep."
                }
                try {
                    $step = [Win32.NativeSQLiteRead]::Step($stmt)
                    if ($step -eq 100) {        # SQLITE_ROW
                        return [Win32.NativeSQLiteRead]::ColumnInt($stmt, 0)
                    } elseif ($step -eq 101) {  # SQLITE_DONE (no matching row)
                        return $null
                    } else {
                        throw "CAM database read failed: sqlite3_step returned $step."
                    }
                } finally {
                    [void][Win32.NativeSQLiteRead]::FinalizeStmt($stmt)
                }
            } finally {
                [void][Win32.NativeSQLiteRead]::Close($dbHandle)
            }
        }
    }


    ## Get current User SID via Windows Terminal Services API (active console session)
    if (-not ('Win32.Wts' -as [type])) {
        Add-Type -Namespace Win32 -Name Wts -MemberDefinition @'
[DllImport("kernel32.dll")]
public static extern uint WTSGetActiveConsoleSessionId();
[DllImport("wtsapi32.dll", SetLastError=true)]
public static extern bool WTSQueryUserToken(uint sessionId, out IntPtr token);
[DllImport("kernel32.dll")]
public static extern bool CloseHandle(IntPtr h);
'@
    }

    $sessionId = [Win32.Wts]::WTSGetActiveConsoleSessionId()
    $userToken = [IntPtr]::Zero
    $userSid = $null
    # [uint32]::MaxValue (0xFFFFFFFF) is the "no attached session" sentinel returned by WTSGetActiveConsoleSessionId
    if ($sessionId -ne [uint32]::MaxValue -and [Win32.Wts]::WTSQueryUserToken($sessionId, [ref]$userToken)) {
        try {
            $userSid = (New-Object System.Security.Principal.WindowsIdentity($userToken)).User.Value
        } finally {
            [Win32.Wts]::CloseHandle($userToken) | Out-Null
        }
    }

    Write-PersistentLog -Message "Detection invoked."

    ## Guard: without an interactive user, the per-user HKU and CAM DB state cannot be evaluated, and remediation would no-op anyway.
    ## Report clean so Intune doesn't retrigger; detection will re-run on the next cycle once a user is logged on.
    if (-not $userSid) {
        $msg = "No interactive console user detected; skipping detection."
        Write-Output $msg
        Write-PersistentLog -Message $msg
        exit 0
    }


    # Vars
    ## Services (must match remediate)
    $locationServiceSvcName = "lfsvc"
    $locationServiceSvcStartupType = "Manual"
    $timeZoneServiceSvcName = "tzautoupdate"
    $timeZoneServiceSvcStartupType = "Manual"

    ## Registry keys + expected values (must match remediate)
    $AllowLocationPolicyManagerRegKey = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\System"
    $AllowLocationPolicyManagerRegValueName = "AllowLocation"

    $DisableLocationHklmRegKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"
    $DisableLocationHklmRegValueName = "DisableLocation"
    $DisableLocationHklmRegValueData = 0

    $ConsentStoreHklmRegKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
    $ConsentStoreHklmRegValue1Name = "Value"
    $ConsentStoreHklmRegValue1Data = "Allow"
    $ConsentStoreHklmRegValue2Name = "LastSetTime"

    $OobeConsentRegKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE"
    $OobeConsentRegValueName = "PrivacyConsentStatus"
    $OobeConsentRegValueData = 1

    $ConsentStoreUserRegKey = "Registry::HKEY_USERS\$userSid\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
    $ConsentStoreUserRegValue1Name = "Value"
    $ConsentStoreUserRegValue1Data = "Allow"
    $ConsentStoreUserRegValue2Name = "LastSetTime"

    ## Files
    $CamDatabasePath = "$env:ProgramData\Microsoft\Windows\CapabilityAccessManager\CapabilityConsentStorage.db"
    $sqlitePath = "$env:ProgramData\sqlite-tools\sqlite3.exe"


    # Mode Switch: sqlite3.exe vs native winsqlite3.dll
    $useSQLiteExe = (Test-Path -Path $sqlitePath -PathType Leaf)

    # Native SQLite P/Invoke surface (only declared if we'll actually need it)
    if (-not $useSQLiteExe -and -not ('Win32.NativeSQLiteRead' -as [type])) {
        Add-Type -Namespace Win32 -Name NativeSQLiteRead -MemberDefinition @'
[DllImport("winsqlite3.dll", EntryPoint = "sqlite3_open", CallingConvention = CallingConvention.Cdecl)]
public static extern int Open(string filename, out IntPtr db);
[DllImport("winsqlite3.dll", EntryPoint = "sqlite3_prepare_v2", CharSet = CharSet.Ansi, CallingConvention = CallingConvention.Cdecl)]
public static extern int Prepare(IntPtr db, string sql, int nBytes, out IntPtr stmt, out IntPtr tail);
[DllImport("winsqlite3.dll", EntryPoint = "sqlite3_step", CallingConvention = CallingConvention.Cdecl)]
public static extern int Step(IntPtr stmt);
[DllImport("winsqlite3.dll", EntryPoint = "sqlite3_column_int", CallingConvention = CallingConvention.Cdecl)]
public static extern int ColumnInt(IntPtr stmt, int col);
[DllImport("winsqlite3.dll", EntryPoint = "sqlite3_finalize", CallingConvention = CallingConvention.Cdecl)]
public static extern int FinalizeStmt(IntPtr stmt);
[DllImport("winsqlite3.dll", EntryPoint = "sqlite3_close", CallingConvention = CallingConvention.Cdecl)]
public static extern int Close(IntPtr db);
'@
    }


    # Readiness check: during Autopilot User ESP the CAM DB file and/or the HKU hive for the user
    # may briefly not exist yet. Wait up to 120s for them to appear; if still not ready, defer to the next cycle.
    if (-not (Wait-ForReadiness -UserSid $userSid -CamDbPath $CamDatabasePath)) {
        $msg = "Per-user environment not ready after 120s (CAM DB file or HKU hive still missing). Deferring to next cycle."
        Write-Output $msg
        Write-PersistentLog -Message $msg -Level 'Warn'
        exit 0
    }


    # Collect drift reasons so Intune's detection output explains *why* remediation was triggered
    $driftReasons = @()


    # 1. AllowLocation CSP policy should not exist at all (remediate removes the value whenever present, regardless of data)
    if (Test-RegistryValueExists -Path $AllowLocationPolicyManagerRegKey -ValueName $AllowLocationPolicyManagerRegValueName) {
        $driftReasons += "AllowLocation CSP policy present at '$AllowLocationPolicyManagerRegKey' (should be removed)."
    }


    # 2. DisableLocation HKLM reg must be 0
    $disableLocation = Get-RegistryValueOrNull -Path $DisableLocationHklmRegKey -ValueName $DisableLocationHklmRegValueName
    if ($disableLocation -ne $DisableLocationHklmRegValueData) {
        $driftReasons += "DisableLocation is '$disableLocation' (expected 0)."
    }


    # 3. HKLM ConsentStore Value must be 'Allow'
    $hklmConsent = Get-RegistryValueOrNull -Path $ConsentStoreHklmRegKey -ValueName $ConsentStoreHklmRegValue1Name
    if ($hklmConsent -ne $ConsentStoreHklmRegValue1Data) {
        $driftReasons += "HKLM ConsentStore Value is '$hklmConsent' (expected 'Allow')."
    }


    # 4. HKLM ConsentStore LastSetTime must exist (remediate only writes it if missing, so existence is the only check)
    if (-not (Test-RegistryValueExists -Path $ConsentStoreHklmRegKey -ValueName $ConsentStoreHklmRegValue2Name)) {
        $driftReasons += "HKLM ConsentStore LastSetTime missing."
    }


    # 5. OOBE PrivacyConsentStatus must be 1
    $oobe = Get-RegistryValueOrNull -Path $OobeConsentRegKey -ValueName $OobeConsentRegValueName
    if ($oobe -ne $OobeConsentRegValueData) {
        $driftReasons += "OOBE PrivacyConsentStatus is '$oobe' (expected 1)."
    }


    # 6. HKU (per-user) ConsentStore Value must be 'Allow'
    $userConsent = Get-RegistryValueOrNull -Path $ConsentStoreUserRegKey -ValueName $ConsentStoreUserRegValue1Name
    if ($userConsent -ne $ConsentStoreUserRegValue1Data) {
        $driftReasons += "HKU ConsentStore Value is '$userConsent' (expected 'Allow')."
    }


    # 7. HKU (per-user) ConsentStore LastSetTime must exist
    if (-not (Test-RegistryValueExists -Path $ConsentStoreUserRegKey -ValueName $ConsentStoreUserRegValue2Name)) {
        $driftReasons += "HKU ConsentStore LastSetTime missing."
    }


    # 8. CAM DB UserGlobal must have Value = 1 for ('location', $userSid)
    $camValue = Get-CamUserGlobalValue -UserSid $userSid
    if ($camValue -ne 1) {
        $driftReasons += "CAM DB UserGlobal('location', '$userSid') is '$camValue' (expected 1)."
    }


    # 9. lfsvc — correct StartupType (runtime Status intentionally not checked: a transient stopped state should not trigger remediation)
    $lfsvc = Get-Service -Name $locationServiceSvcName
    if ($lfsvc.StartType -ne $locationServiceSvcStartupType) {
        $driftReasons += "lfsvc StartType is '$($lfsvc.StartType)' (expected '$locationServiceSvcStartupType')."
    }


    # 10. tzautoupdate — correct StartupType (runtime Status intentionally not checked)
    $tz = Get-Service -Name $timeZoneServiceSvcName
    if ($tz.StartType -ne $timeZoneServiceSvcStartupType) {
        $driftReasons += "tzautoupdate StartType is '$($tz.StartType)' (expected '$timeZoneServiceSvcStartupType')."
    }


    # Final Output — single Write-Output so the Intune portal renders the full report without fragmenting the drift list
    if ($driftReasons.Count -gt 0) {
        $lines = @("Drift detected. Remediation required:") + ($driftReasons | ForEach-Object { " - $_" })
        $report = $lines -join "`r`n"
        Write-Output $report
        Write-PersistentLog -Message ("Drift detected: " + ($driftReasons -join ' | '))
        exit 1
    } else {
        $msg = "Location and timezone services are correctly configured."
        Write-Output $msg
        Write-PersistentLog -Message $msg
        exit 0
    }

} catch {
    $errMsg = "Detection failed: [$($_.Exception.GetType().Name)] $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))"
    Write-Output $errMsg
    Write-PersistentLog -Message $errMsg -Level 'Error'
    exit 1
}
