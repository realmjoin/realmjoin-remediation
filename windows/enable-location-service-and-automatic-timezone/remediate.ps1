<#
.SYNOPSIS
    Remediation — Enable Windows Location Service with end-user control & Automatic Time Zone Feature.

.DESCRIPTION
    Corrects drift to enable the Windows Location capability and Automatic Time Zone:
      - Removes AllowLocation CSP value (takes precedence over other settings)
      - Sets DisableLocation = 0
      - Sets ConsentStore Value = 'Allow' (HKLM + HKU), writes LastSetTime if missing
      - Sets OOBE PrivacyConsentStatus = 1
      - Runs SystemSettingsAdminFlows.exe SetCamSystemGlobal location 1
      - Writes Value = 1 into CAM DB UserGlobal for ('location', <sid>)
      - Ensures lfsvc + tzautoupdate are StartType = Manual and Running

    lfsvc is unconditionally bounced at the start to clear state from any
    previously-applied Intune location policies that could conflict.

    If no interactive console user is present, exits 0 — Intune retries next cycle.

    Every attempted run (past the no-user guard and readiness check) produces:
      - Concise structured entries in
          C:\Windows\Logs\glueckkanja\Remediations\enable-location-service-and-automatic-timezone\activity.log
          (rotates at 1 MB)
      - A verbose Start-Transcript at
          C:\Windows\Logs\glueckkanja\Remediations\enable-location-service-and-automatic-timezone\transcripts\remediation-<stamp>.log
          (forensic evidence; last 10 retained)

.NOTES
    Run as:       SYSTEM, 64-bit PowerShell
    Assignment:   Users (not devices) — required to resolve the console user SID
    Dependencies: winsqlite3.dll (Windows 10+ has this in the system by default) *OR* sqlite3.exe (must be copied to the device via other means if used; detection looks for it in %ProgramData%\sqlite-tools\sqlite3.exe)
    Exit codes:   0 = success (with or without drift correction); 1 = failure
#>
$ErrorActionPreference = 'Stop'

# Persistent logging: IME cleans up its per-run stdout/stderr files after reporting results,
# so failures during Autopilot leave no on-disk trail. Append-only log survives that cleanup.
$script:LogSource = 'Remediation'
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

    Function Start-ForensicTranscript {
        # Starts a Start-Transcript at the convention transcripts path. Retains at most $MaxFiles per source (oldest deleted).
        param(
            [Parameter(Mandatory=$true)][string]$Source,
            [int]$MaxFiles = 10
        )
        $transcriptDir = Join-Path (Split-Path -Parent $script:PersistentLogPath) 'transcripts'
        if (-not (Test-Path $transcriptDir)) { New-Item -Path $transcriptDir -ItemType Directory -Force | Out-Null }
        $existing = Get-ChildItem -Path $transcriptDir -Filter "$Source-*.log" -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending
        if ($existing.Count -ge $MaxFiles) {
            $existing | Select-Object -Skip ($MaxFiles - 1) | Remove-Item -Force -ErrorAction SilentlyContinue
        }
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $transcriptPath = Join-Path $transcriptDir "$Source-$stamp.log"
        Start-Transcript -Path $transcriptPath -Append | Out-Null
        return $transcriptPath
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

    Function Set-RegistryValueIfDifferent {
        param (
            [Parameter(Mandatory=$true)][string]$Path,
            [Parameter(Mandatory=$true)][string]$ValueName,
            [Parameter(Mandatory=$true)]$Value,
            [Parameter(Mandatory=$true)][string]$Type
        )
        $current = Get-RegistryValueOrNull -Path $Path -ValueName $ValueName
        if ($current -ne $Value) {
            if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
            Set-ItemProperty -Path $Path -Name $ValueName -Value $Value -Type $Type -Force
            return $true
        }
        return $false
    }

    Function Set-RegistryValueIfMissing {
        param (
            [Parameter(Mandatory=$true)][string]$Path,
            [Parameter(Mandatory=$true)][string]$ValueName,
            [Parameter(Mandatory=$true)]$Value,
            [Parameter(Mandatory=$true)][string]$Type
        )
        if (-not (Test-RegistryValueExists -Path $Path -ValueName $ValueName)) {
            if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
            Set-ItemProperty -Path $Path -Name $ValueName -Value $Value -Type $Type -Force
            return $true
        }
        return $false
    }

    Function Set-ServiceState {
        param (
            [Parameter(Mandatory=$true)][string]$Name,
            [Parameter(Mandatory=$true)][ValidateSet('Manual','Automatic','Disabled')][string]$StartupType,
            [switch]$ForceRestart
        )
        # Returns $true only when actual drift was corrected (wrong StartType or not Running).
        # A deliberate -ForceRestart on an already-compliant service is a precautionary bounce, not drift correction, so it does not flip the result.
        $svc = Get-Service -Name $Name
        $driftCorrected = $false
        if ($svc.StartType -ne $StartupType) {
            Set-Service -Name $Name -StartupType $StartupType
            $driftCorrected = $true
        }
        if ($svc.Status -ne 'Running') {
            Start-Service -Name $Name
            $driftCorrected = $true
        } elseif ($ForceRestart) {
            Restart-Service -Name $Name -Force
        }
        return $driftCorrected
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
            if ([Win32.NativeSQLiteWrite]::Open($CamDatabasePath, [ref]$dbHandle) -ne 0) {
                throw "Could not open CAM database file at $CamDatabasePath."
            }
            try {
                $sql = "SELECT Value FROM UserGlobal WHERE Capability = 'location' AND User = '$UserSid';"
                $stmt = [IntPtr]::Zero
                $tail = [IntPtr]::Zero
                $prep = [Win32.NativeSQLiteWrite]::Prepare($dbHandle, $sql, -1, [ref]$stmt, [ref]$tail)
                if ($prep -ne 0) {
                    throw "CAM database read failed: sqlite3_prepare_v2 returned $prep."
                }
                try {
                    $step = [Win32.NativeSQLiteWrite]::Step($stmt)
                    if ($step -eq 100) {        # SQLITE_ROW
                        return [Win32.NativeSQLiteWrite]::ColumnInt($stmt, 0)
                    } elseif ($step -eq 101) {  # SQLITE_DONE (no matching row)
                        return $null
                    } else {
                        throw "CAM database read failed: sqlite3_step returned $step."
                    }
                } finally {
                    [void][Win32.NativeSQLiteWrite]::FinalizeStmt($stmt)
                }
            } finally {
                [void][Win32.NativeSQLiteWrite]::Close($dbHandle)
            }
        }
    }


    Write-PersistentLog -Message "Remediation invoked."

    # Vars
    ## Generic
    $timeStamp = [DateTime]::UtcNow.ToFileTime()

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

    ## Guard: if no interactive user (e.g. Autopilot ESP, logon screen), exit 0 so Intune retries cleanly on the next cycle
    if (-not $userSid) {
        $msg = "No interactive console user detected. Skipping remediation; Intune will retry on the next cycle."
        Write-Output $msg
        Write-PersistentLog -Message $msg
        exit 0
    }


    ## Services
    $locationServiceSvcName = "lfsvc"
    $locationServiceSvcStartupType = "Manual"
    $timeZoneServiceSvcName = "tzautoupdate"
    $timeZoneServiceSvcStartupType = "Manual"
    $camServiceSvcName = "camsvc"

    ## Registry
    ### AllowLocationPolicyManagerReg
    $AllowLocationPolicyManagerRegKey = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\System"
    $AllowLocationPolicyManagerRegValueName = "AllowLocation"
    ### DisableLocationHklmReg
    $DisableLocationHklmRegKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"
    $DisableLocationHklmRegValueName = "DisableLocation"
    $DisableLocationHklmRegValueData = 0
    $DisableLocationHklmRegValueType = "DWORD"
    ### ConsentStoreHklmReg
    $ConsentStoreHklmRegKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
    $ConsentStoreHklmRegValue1Name = "Value"
    $ConsentStoreHklmRegValue1Data = "Allow"
    $ConsentStoreHklmRegValue1Type = "String"
    $ConsentStoreHklmRegValue2Name = "LastSetTime"
    $ConsentStoreHklmRegValue2Data = $timeStamp
    $ConsentStoreHklmRegValue2Type = "QWord"
    ### OobeConsentReg
    $OobeConsentRegKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE"
    $OobeConsentRegValueName = "PrivacyConsentStatus"
    $OobeConsentRegValueData = 1
    $OobeConsentRegValueType = "DWORD"

    ### ConsentStoreUserReg
    $ConsentStoreUserRegKey = "Registry::HKEY_USERS\$userSid\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
    $ConsentStoreUserRegValue1Name = "Value"
    $ConsentStoreUserRegValue1Data = "Allow"
    $ConsentStoreUserRegValue1Type = "String"
    $ConsentStoreUserRegValue2Name = "LastSetTime"
    $ConsentStoreUserRegValue2Data = $timeStamp
    $ConsentStoreUserRegValue2Type = "QWord"

    ## Files
    $SystemSettingsAdminFlowsFullPath = "C:\Windows\System32\SystemSettingsAdminFlows.exe"
    $SystemSettingsAdminFlowsArgs = "SetCamSystemGlobal location 1"
    $CamDatabasePath = "$env:ProgramData\Microsoft\Windows\CapabilityAccessManager\CapabilityConsentStorage.db"
    $sqlitePath = "$env:ProgramData\sqlite-tools\sqlite3.exe"


    # Mode Switch: Check if sqlite3.exe is available for use in executing SQL commands against the CAM database, otherwise fallback to native method (may not work on older Windows versions)
    if (Test-Path -Path $sqlitePath -PathType Leaf) {
        $useSQLiteExe = $true
    }
    else {
        Write-Output "sqlite3.exe not found, falling back to native method. Please note that the native method may not work on older Windows versions."
        $useSQLiteExe = $false
    }

    # Native SQLite P/Invoke surface: declare once, up front, so both the pre-check read and the write path can use it
    if (-not $useSQLiteExe -and -not ('Win32.NativeSQLiteWrite' -as [type])) {
        Add-Type -Namespace Win32 -Name NativeSQLiteWrite -MemberDefinition @'
[DllImport("winsqlite3.dll", EntryPoint = "sqlite3_open", CallingConvention = CallingConvention.Cdecl)]
public static extern int Open(string filename, out IntPtr db);
[DllImport("winsqlite3.dll", EntryPoint = "sqlite3_exec", CallingConvention = CallingConvention.Cdecl)]
public static extern int Exec(IntPtr db, string sql, IntPtr callback, IntPtr args, out IntPtr errMsg);
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


    # Forensic transcript: the remediation touches HKLM + HKU regs, the CAM SQLite DB, services, and invokes SystemSettingsAdminFlows.
    # Capture a verbose per-run trail for post-incident review. Started only after the no-user guard and readiness check pass, so we
    # don't accumulate transcripts for runs that never did any destructive work.
    $transcriptPath = Start-ForensicTranscript -Source 'remediation'
    Write-PersistentLog -Message "Transcript: $transcriptPath"


    # Tracks whether registry drift or CAM DB drift was detected. Expensive CAM work and service restarts gate on this so idempotent re-runs are no-ops.
    $changed = $false


    # 1. Remove AllowLocation PolicyManager Reg if it exists (these policies take precedence over GPO/Registry) - this is the master switch for Location in Windows 11
    if (Test-RegistryValueExists -Path $AllowLocationPolicyManagerRegKey -ValueName $AllowLocationPolicyManagerRegValueName) {
        Remove-ItemProperty -Path $AllowLocationPolicyManagerRegKey -Name $AllowLocationPolicyManagerRegValueName
        $changed = $true
    }


    # 2. Set DisableLocation HKLM Reg to 0 to avoid any hard-denies that would disable location globally
    if (Set-RegistryValueIfDifferent -Path $DisableLocationHklmRegKey -ValueName $DisableLocationHklmRegValueName -Value $DisableLocationHklmRegValueData -Type $DisableLocationHklmRegValueType) {
        $changed = $true
    }


    # 3. UNCONDITIONAL: ensure Geolocation service (lfsvc) is running with the desired startup type, and bounce it to clear any lingering state
    #    from previously-applied Intune location policies that could conflict with the settings this remediation is about to write.
    if (Set-ServiceState -Name $locationServiceSvcName -StartupType $locationServiceSvcStartupType -ForceRestart) {
        $changed = $true
    }


    # 4. Set generic HKLM ConsentStore and timestamp regs
    if (Set-RegistryValueIfDifferent -Path $ConsentStoreHklmRegKey -ValueName $ConsentStoreHklmRegValue1Name -Value $ConsentStoreHklmRegValue1Data -Type $ConsentStoreHklmRegValue1Type) {
        $changed = $true
    }
    if (Set-RegistryValueIfMissing -Path $ConsentStoreHklmRegKey -ValueName $ConsentStoreHklmRegValue2Name -Value $ConsentStoreHklmRegValue2Data -Type $ConsentStoreHklmRegValue2Type) {
        $changed = $true
    }


    # 5. Set OOBE Consent status reg
    if (Set-RegistryValueIfDifferent -Path $OobeConsentRegKey -ValueName $OobeConsentRegValueName -Value $OobeConsentRegValueData -Type $OobeConsentRegValueType) {
        $changed = $true
    }


    # 6. Set User ConsentStore and timestamp regs
    if (Set-RegistryValueIfDifferent -Path $ConsentStoreUserRegKey -ValueName $ConsentStoreUserRegValue1Name -Value $ConsentStoreUserRegValue1Data -Type $ConsentStoreUserRegValue1Type) {
        $changed = $true
    }
    if (Set-RegistryValueIfMissing -Path $ConsentStoreUserRegKey -ValueName $ConsentStoreUserRegValue2Name -Value $ConsentStoreUserRegValue2Data -Type $ConsentStoreUserRegValue2Type) {
        $changed = $true
    }


    # 6b. Pre-check CAM DB state — per-user UserGlobal drift on its own should also trigger remediation, not just registry drift
    $camCurrentValue = Get-CamUserGlobalValue -UserSid $userSid
    if ($camCurrentValue -ne 1) {
        $changed = $true
    }
    

    # 7. CAM work: only run the expensive admin flow + CAM DB write + service restarts if any drift was detected above
    if ($changed) {
        ## 7a. Execute the administrative flow to flip the master switch in the CAM database.
        ## Retry on transient launch failures — during early Autopilot, SystemSettingsAdminFlows.exe
        ## can fail to start (CreateProcess returns file-not-found / InvalidOperationException) even
        ## though the binary is on disk, because the UWP/settings runtime it depends on isn't fully up yet.
        $adminFlow = $null
        $adminFlowMaxAttempts = 3
        $adminFlowDelaySeconds = 5
        for ($attempt = 1; $attempt -le $adminFlowMaxAttempts; $attempt++) {
            try {
                $adminFlow = Start-Process -FilePath $SystemSettingsAdminFlowsFullPath -ArgumentList $SystemSettingsAdminFlowsArgs -Wait -PassThru
                break
            } catch {
                if ($attempt -lt $adminFlowMaxAttempts) {
                    Write-PersistentLog -Message "SystemSettingsAdminFlows.exe launch attempt $attempt of $adminFlowMaxAttempts failed: $($_.Exception.Message). Retrying in ${adminFlowDelaySeconds}s." -Level 'Warn'
                    Start-Sleep -Seconds $adminFlowDelaySeconds
                } else {
                    throw
                }
            }
        }
        if ($adminFlow.ExitCode -ne 0) {
            throw "SystemSettingsAdminFlows.exe exited with code $($adminFlow.ExitCode)."
        }

        ## 7b. Stop camsvc before writing to the CAM database to avoid file-lock contention
        if ((Get-Service -Name $camServiceSvcName).Status -eq 'Running') {
            Stop-Service -Name $camServiceSvcName -Force
        }

        ## 7c. Set Consent Status in CAM database for current user
        if ($useSQLiteExe) {
            $sqlQuery = @"
INSERT INTO UserGlobal (Capability, User, Value)
VALUES ('location', '$userSid', 1)
ON CONFLICT (Capability, User)
DO UPDATE SET Value = 1;
"@
            $sqlQuery | & $sqlitePath $CamDatabasePath
            if ($LASTEXITCODE -ne 0) {
                throw "sqlite3.exe exited with code $LASTEXITCODE while writing to the CAM database."
            }
        }
        else {
            # Native method: Win32.NativeSQLiteWrite was already declared at the top of the script
            $sqlQuery = "INSERT INTO UserGlobal (Capability, User, Value) VALUES ('location', '$userSid', 1) ON CONFLICT (Capability, User) DO UPDATE SET Value = 1;"
            $dbHandle = [IntPtr]::Zero
            if ([Win32.NativeSQLiteWrite]::Open($CamDatabasePath, [ref]$dbHandle) -ne 0) {
                throw "Could not open CAM database file at $CamDatabasePath."
            }
            try {
                $errMsg = [IntPtr]::Zero
                # errMsg buffer allocated by sqlite3 on error is not sqlite3_free'd here; negligible for a one-shot script
                $result = [Win32.NativeSQLiteWrite]::Exec($dbHandle, $sqlQuery, [IntPtr]::Zero, [IntPtr]::Zero, [ref]$errMsg)
                if ($result -ne 0) {
                    throw "CAM database write failed with SQLite error code $result."
                }
            } finally {
                [void][Win32.NativeSQLiteWrite]::Close($dbHandle)
            }
        }

        ## 7d. Start camsvc back up
        Start-Service -Name $camServiceSvcName

        # 7e. Set User ConsentStore and timestamp regs again to pick up the CAM changes ($changed is already $true here, return is discarded)
        Set-RegistryValueIfDifferent -Path $ConsentStoreUserRegKey -ValueName $ConsentStoreUserRegValue1Name -Value $ConsentStoreUserRegValue1Data -Type $ConsentStoreUserRegValue1Type | Out-Null
        Set-RegistryValueIfMissing -Path $ConsentStoreUserRegKey -ValueName $ConsentStoreUserRegValue2Name -Value $ConsentStoreUserRegValue2Data -Type $ConsentStoreUserRegValue2Type | Out-Null

        ## 7f. Restart Geolocation service (lfsvc) again to pick up the CAM changes ($changed is already $true here, return is discarded)
        Set-ServiceState -Name $locationServiceSvcName -StartupType $locationServiceSvcStartupType -ForceRestart | Out-Null
    }


    # 8. Ensure Automatic Time Zone service (tzautoupdate) is in the desired state (idempotent: no restart if already compliant)
    if (Set-ServiceState -Name $timeZoneServiceSvcName -StartupType $timeZoneServiceSvcStartupType) {
        $changed = $true
    }


    # Final Output
    if ($changed) {
        $msg = "Remediation successful: drift corrected."
    } else {
        $msg = "Remediation successful: no drift detected."
    }
    Write-Output $msg
    Write-PersistentLog -Message $msg
    try { Stop-Transcript | Out-Null } catch { }
    exit 0

} catch {
    $errMsg = "Remediation failed: [$($_.Exception.GetType().Name)] $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))"
    Write-Output $errMsg
    Write-PersistentLog -Message $errMsg -Level 'Error'
    try { Stop-Transcript | Out-Null } catch { }
    exit 1
}
