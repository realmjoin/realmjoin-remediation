<#
.SYNOPSIS
    Intune Remediation - automatically repairs High-confidence duplicate
    ProfileList SIDs that block Windows Reset / in-place upgrade.

.DESCRIPTION
    ONLY acts on High-confidence cases as defined by the detection logic:
      1. Same-path: one plain key + one-or-more .bak variants -> keep plain
      2. Different paths, exactly one folder exists on disk    -> keep that one
      3. Different paths, exactly one entry has a State value  -> keep that one

    REFUSES to act on:
      - Medium / Low / None confidence cases
      - Devices where any matching SID hive is currently loaded in HKEY_USERS
      - Devices where FSLogix profile management is detected
      - Any case where the deterministic pre-checks fail

    Exit codes:
      0 = repaired (or nothing to do; script runs clean)
      1 = deliberate refusal (skip condition hit); will remain flagged for review

    Deployment:
      - 64-bit PowerShell
      - Run as SYSTEM
      - Pair with the matching detection script

    Every action produces:
      - A registry export (.reg) of every affected key to
          C:\ProgramData\glueckkanja\Remediations\fix-duplicate-profile-list-sids\backup-<stamp>\
      - A per-run Start-Transcript at
          C:\Windows\Logs\glueckkanja\Remediations\fix-duplicate-profile-list-sids\transcripts\remediation-<stamp>.log
          (forensic evidence; last 10 retained)
      - Concise operational entries in
          C:\Windows\Logs\glueckkanja\Remediations\fix-duplicate-profile-list-sids\activity.log
          (structured, rotates at 1 MB)
      - An Application event log entry (source: glueckkanja.ProfileListRepair; ID 1000 on repair, 2000 on refusal, 4000 on error)

.NOTES
    Read the transcript before ever concluding this script "worked" on a device.
    The Intune remediation output is deliberately terse; full evidence is on disk.
#>

[CmdletBinding()]
param()

#region Bootstrap
$ErrorActionPreference = 'Stop'

# glueckkanja convention — persistent activity log + forensic transcript for a destructive remediation.
# activity.log  : concise, rotating (1 MB), structured.                      C:\Windows\Logs\glueckkanja\Remediations\<pkg>\activity.log
# transcript    : verbose per-run Start-Transcript evidence (keep last 10).  C:\Windows\Logs\glueckkanja\Remediations\<pkg>\transcripts\remediation-<stamp>.log
# backup .reg   : persistent artifact of every affected key before deletion. C:\ProgramData\glueckkanja\Remediations\<pkg>\backup-<stamp>\
$script:LogSource = 'Remediation'
$script:PersistentLogPath = "$env:windir\Logs\glueckkanja\Remediations\fix-duplicate-profile-list-sids\activity.log"

function Write-PersistentLog {
    param (
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet('Info','Warn','Error')][string]$Level = 'Info'
    )
    try {
        $logDir = Split-Path -Parent $script:PersistentLogPath
        if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
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

function Start-ForensicTranscript {
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

$base      = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
$stamp     = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $env:ProgramData "glueckkanja\Remediations\fix-duplicate-profile-list-sids\backup-$stamp"

New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
$transcriptPath = Start-ForensicTranscript -Source 'remediation'

# Best-effort event source registration. Fails silently if not admin enough;
# script still runs, just without event-log evidence.
$eventSource = 'glueckkanja.ProfileListRepair'
try {
    if (-not [System.Diagnostics.EventLog]::SourceExists($eventSource)) {
        [System.Diagnostics.EventLog]::CreateEventSource($eventSource, 'Application')
    }
} catch { }

function Write-RepairEvent {
    param(
        [ValidateSet('Information','Warning','Error')]$EntryType,
        [int]$EventId,
        [string]$Message
    )
    try {
        Write-EventLog -LogName Application -Source $eventSource `
            -EntryType $EntryType -EventId $EventId -Message $Message
    } catch { }
}

Write-Host "=== ProfileList remediation $stamp ===" -ForegroundColor Cyan
Write-Host "Transcript: $transcriptPath"
Write-Host "Backups:    $backupDir"
Write-PersistentLog -Message "Remediation invoked. Transcript: $transcriptPath. Backups: $backupDir."
#endregion

#region Helpers (mirror detection script logic so behavior stays in sync)
$userSidPatterns = @('S-1-5-21-*', 'S-1-12-1-*')

function Test-IsUserSid {
    param([string]$Sid)
    foreach ($pat in $userSidPatterns) {
        if ($Sid -like $pat) { return $true }
    }
    return $false
}

function ConvertTo-StateDescription {
    param([Nullable[int]]$State)
    if ($null -eq $State)  { return '<missing>' }
    if ($State -eq 0)      { return 'Normal (no flags set)' }
    $bits = [ordered]@{
        0x0001 = 'Mandatory'; 0x0002 = 'UseCache (Roaming)'
        0x0004 = 'NewLocal';  0x0008 = 'NewCentral'
        0x0010 = 'UpdateCentral'; 0x0020 = 'Restored'
        0x0040 = 'Guest'; 0x0080 = 'Admin'
        0x0100 = 'DefaultNetReady (profile failed to load, default used)'
        0x0200 = 'Partial'; 0x0400 = 'Roaming preference'
        0x0800 = 'Temporary'; 0x1000 = 'Loading'
        0x2000 = 'Background upload'; 0x4000 = 'Prepared for upload'
        0x8000 = 'Updating / not yet loaded'
    }
    $flags = foreach ($bit in $bits.Keys) {
        if (($State -band $bit) -eq $bit) { $bits[$bit] }
    }
    if (-not $flags) { return ('Unknown (0x{0:X})' -f $State) }
    return ($flags -join ', ')
}

function Get-ProfileEntryInfo {
    param([string]$KeyPath)
    $props      = Get-ItemProperty -Path $KeyPath -ErrorAction SilentlyContinue
    $path       = $props.ProfileImagePath
    $pathExists = if ($path) { Test-Path -LiteralPath $path -PathType Container } else { $false }
    $ntuserMtime = $null
    if ($pathExists) {
        $ntuser = Join-Path $path 'NTUSER.DAT'
        if (Test-Path -LiteralPath $ntuser -PathType Leaf) {
            try { $ntuserMtime = (Get-Item -LiteralPath $ntuser -Force).LastWriteTime } catch { }
        }
    }
    $hasState = $null -ne $props -and
                $null -ne ($props.PSObject.Properties['State'])
    $stateValue = if ($hasState) { [int]$props.State } else { $null }
    [pscustomobject]@{
        KeyName          = Split-Path $KeyPath -Leaf
        KeyPath          = $KeyPath
        IsBak            = (Split-Path $KeyPath -Leaf) -match '\.bak(_\d+)?$'
        ProfilePath      = $path
        PathExists       = $pathExists
        NTUserMtime      = $ntuserMtime
        HasState         = $hasState
        State            = $stateValue
        StateDescription = ConvertTo-StateDescription -State $stateValue
    }
}

function Resolve-InUseEntry {
    param([object[]]$Entries)

    # Same path across all entries
    $distinctPaths = @($Entries | Where-Object ProfilePath |
                       Select-Object -ExpandProperty ProfilePath -Unique)
    if ($distinctPaths.Count -eq 1) {
        $nonBak   = @($Entries | Where-Object { -not $_.IsBak })
        $plainBak = @($Entries | Where-Object { $_.KeyName -match '\.bak$' })

        if ($nonBak.Count -eq 1) {
            return @{ Winner = $nonBak[0]; Confidence = 'High'
                Reason = "Same-path duplicate; non-.bak is the active key." }
        }
        if ($plainBak.Count -eq 1) {
            return @{ Winner = $plainBak[0]; Confidence = 'Medium'
                Reason = "All .bak variants, same path; keeping plain .bak over numbered variants." }
        }
        return @{ Winner = $null; Confidence = 'None'
            Reason = "Same-path duplicates with no plain or plain-.bak key; unexpected shape." }
    }

    # State-based disambiguation
    $withState = @($Entries | Where-Object HasState)
    if ($withState.Count -eq 1 -and $Entries.Count -gt 1) {
        return @{ Winner = $withState[0]; Confidence = 'High'
            Reason = "Only one entry has State; sibling(s) missing State are incomplete keys." }
    }

    # Folder-based
    $withFolder = @($Entries | Where-Object PathExists)
    if ($withFolder.Count -eq 1) {
        return @{ Winner = $withFolder[0]; Confidence = 'High'
            Reason = "Only one entry has an existing ProfileImagePath folder." }
    }
    if ($withFolder.Count -eq 0) {
        return @{ Winner = $null; Confidence = 'None'
            Reason = "No folders exist; possibly FSLogix or fully orphaned." }
    }

    # Multiple folders -> mtime heuristics (Medium/Low/None). This remediation
    # script will NOT act on any of these. Return Low to force a refusal.
    return @{ Winner = $null; Confidence = 'Low'
        Reason = "Multiple folders on disk; remediation refuses mtime-based choices." }
}

function Get-LoadedUserHives {
    Get-ChildItem 'Registry::HKEY_USERS' -ErrorAction SilentlyContinue |
        Where-Object {
            (Test-IsUserSid $_.PSChildName) -and $_.PSChildName -notlike '*_Classes'
        } | ForEach-Object { $_.PSChildName }
}

function Test-FSLogixPresent {
    # FSLogix stores configuration under HKLM\SOFTWARE\FSLogix\Profiles.
    # Also check the service as belt-and-braces.
    if (Test-Path 'HKLM:\SOFTWARE\FSLogix\Profiles') { return $true }
    if (Get-Service -Name 'frxsvc' -ErrorAction SilentlyContinue) { return $true }
    return $false
}

function Backup-RegistryKey {
    param([string]$KeyName, [string]$OutFile)
    $regPath = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$KeyName"
    & reg.exe export $regPath $OutFile /y | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "reg export failed for $KeyName (exit $LASTEXITCODE)"
    }
}
#endregion

#region Pre-flight refusals
try {
    if (Test-FSLogixPresent) {
        $msg = "REFUSED: FSLogix detected on this device. ProfileList heuristics are unreliable when containers may be unmounted."
        Write-Host $msg -ForegroundColor Yellow
        Write-RepairEvent -EntryType Warning -EventId 2000 -Message $msg
        Write-PersistentLog -Message $msg -Level 'Warn'
        Write-Output $msg
        Stop-Transcript | Out-Null
        exit 1
    }

    $keys = Get-ChildItem -Path $base -ErrorAction Stop

    $grouped = $keys | Group-Object -Property {
        $_.PSChildName -replace '\.bak(_\d+)?$',''
    } | Where-Object {
        $_.Count -gt 1 -and (Test-IsUserSid $_.Name)
    }

    if (-not $grouped) {
        $msg = "Healthy: no duplicate user SIDs."
        Write-Host "No duplicates found. Nothing to do." -ForegroundColor Green
        Write-Output $msg
        Write-PersistentLog -Message $msg
        Stop-Transcript | Out-Null
        exit 0
    }

    $loadedHives = Get-LoadedUserHives
}
catch {
    $msg = "ERROR during pre-flight: [$($_.Exception.GetType().Name)] $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))"
    Write-Host $msg -ForegroundColor Red
    Write-RepairEvent -EntryType Error -EventId 4000 -Message $msg
    Write-PersistentLog -Message $msg -Level 'Error'
    Write-Output $msg
    Stop-Transcript | Out-Null
    exit 1
}
#endregion

#region Process
$actionsTaken = 0
$refusals     = 0
$errors       = 0
$summaryLines = @()

foreach ($group in $grouped) {
    $sid = $group.Name
    Write-Host ""
    Write-Host "--- SID: $sid ---" -ForegroundColor Cyan

    if ($sid -in $loadedHives) {
        $line = "SKIP ${sid}: hive currently loaded in HKEY_USERS"
        Write-Host $line -ForegroundColor Yellow
        Write-PersistentLog -Message $line -Level 'Warn'
        $summaryLines += $line
        $refusals++
        continue
    }

    $entries = foreach ($k in $group.Group) {
        Get-ProfileEntryInfo -KeyPath $k.PSPath
    }

    $resolution = Resolve-InUseEntry -Entries $entries

    # Log every entry's full state for forensic trail
    foreach ($e in $entries) {
        $mt = if ($e.NTUserMtime) { $e.NTUserMtime.ToString('s') } else { 'n/a' }
        $st = if ($e.HasState) { $e.State } else { '<missing>' }
        Write-Host ("  {0} | path={1} | exists={2} | ntuser={3} | state={4} ({5})" -f `
            $e.KeyName, $e.ProfilePath, $e.PathExists, $mt, $st, $e.StateDescription)
    }
    Write-Host ("  Determination: Winner={0}, Confidence={1}" -f `
        ($(if ($resolution.Winner) { $resolution.Winner.KeyName } else { 'NONE' })),
        $resolution.Confidence)
    Write-Host ("  Reason: {0}" -f $resolution.Reason)

    if ($resolution.Confidence -ne 'High') {
        $line = "SKIP ${sid}: confidence=$($resolution.Confidence) - human review required"
        Write-Host $line -ForegroundColor Yellow
        Write-RepairEvent -EntryType Warning -EventId 2000 -Message "$line | $($resolution.Reason)"
        Write-PersistentLog -Message "$line | $($resolution.Reason)" -Level 'Warn'
        $summaryLines += $line
        $refusals++
        continue
    }

    # Winner survives, everyone else is a loser
    $winner = $resolution.Winner
    $losers = @($entries | Where-Object { $_.KeyName -ne $winner.KeyName })

    # The same-path "High" case needs a rename, not just a delete:
    # if winner is the plain key and losers are .bak siblings -> delete losers
    # Case "only one has State" / "only one has folder" -> same pattern
    #   (winner keeps its current name; losers are deleted)
    # The original different-paths Case-A rule (".bak wins, rename to SID") is
    # NOT reachable here because that resolution returned Medium historically
    # and we only act on High. So every High case is "keep winner as-is, delete losers".

    try {
        # Back up every key in the group (winner included - belt-and-braces)
        foreach ($e in $entries) {
            $bkFile = Join-Path $backupDir "$($e.KeyName).reg"
            Backup-RegistryKey -KeyName $e.KeyName -OutFile $bkFile
        }

        # Delete losers
        foreach ($loser in $losers) {
            Remove-Item -Path $loser.KeyPath -Recurse -Force
            Write-Host ("  DELETED {0}" -f $loser.KeyName) -ForegroundColor Green
        }

        $line = "REPAIRED ${sid}: kept $($winner.KeyName), deleted $($losers.Count) sibling(s) [$($resolution.Reason)]"
        Write-Host $line -ForegroundColor Green
        Write-RepairEvent -EntryType Information -EventId 1000 -Message $line
        Write-PersistentLog -Message $line
        $summaryLines += $line
        $actionsTaken++
    }
    catch {
        $line = "ERROR ${sid}: [$($_.Exception.GetType().Name)] $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))"
        Write-Host $line -ForegroundColor Red
        Write-RepairEvent -EntryType Error -EventId 4000 -Message $line
        Write-PersistentLog -Message $line -Level 'Error'
        $summaryLines += $line
        $errors++
    }
}
#endregion

#region Summary + exit
Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Repaired: $actionsTaken | Refused: $refusals | Errors: $errors"

# Intune dashboard output: one Write-Output with `r`n-joined bullet list so the portal renders the summary readably.
$headline = "Repaired=$actionsTaken; Refused=$refusals; Errors=$errors"
$lines = @($headline)
if ($summaryLines) { $lines += $summaryLines | ForEach-Object { " - $_" } }
$output = $lines -join "`r`n"
Write-Output $output
# activity.log stays inline-separated — one timestamped log line per run, not a multi-line entry.
$summaryLevel = if ($errors -gt 0) { 'Error' } elseif ($refusals -gt 0) { 'Warn' } else { 'Info' }
$logLine = $headline + $(if ($summaryLines) { " | " + ($summaryLines -join ' ;; ') } else { '' })
Write-PersistentLog -Message $logLine -Level $summaryLevel

Stop-Transcript | Out-Null

# Exit 0 only if no errors and no pending refusals
# (refusals = device still flagged, so detection will keep surfacing it)
if ($errors -gt 0 -or $refusals -gt 0) { exit 1 } else { exit 0 }
#endregion
