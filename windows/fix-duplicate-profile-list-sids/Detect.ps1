<#
.SYNOPSIS
    Detects duplicate SID entries in HKLM\...\ProfileList that break Windows Reset
    and in-place upgrades (MIG: "Duplicate profile detected for S-1-...").

.DESCRIPTION
    Read-only detection for Intune Proactive Remediations.
    Exit 0 = healthy, Exit 1 = duplicate(s) found (triggers remediation flag).

    Scope:
      User account SIDs only:
        - S-1-5-21-*   local & AD domain accounts
        - S-1-12-1-*   Entra ID (Azure AD) accounts
      Everything else is ignored. The MIG duplicate-profile failure only
      affects these two authorities, and allow-listing avoids false positives
      from future built-in SID ranges.

    For each duplicate group, attempts to determine the "in-use" profile by:
      1. Checking ProfileImagePath folder existence
      2. Comparing NTUSER.DAT LastWriteTime (newest = most recently used)

    Reports a confidence level because NTUSER.DAT mtime is NOT a fully
    reliable signal (see notes in script body).

    Deployment: 64-bit PowerShell, run as SYSTEM.

.NOTES
    Read-only. Does NOT modify the registry.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# glueckkanja convention — persistent activity log (rotates at 1 MB, single backup)
$script:LogSource = 'Detection'
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

$base = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'

# User account SID patterns we care about. Everything else is ignored.
$userSidPatterns = @(
    'S-1-5-21-*',      # local & AD domain accounts
    'S-1-12-1-*'       # Entra ID (Azure AD) accounts
)

function Test-IsUserSid {
    param([string]$Sid)
    foreach ($pat in $userSidPatterns) {
        if ($Sid -like $pat) { return $true }
    }
    return $false
}

function ConvertTo-StateDescription {
    <#
      Decodes the ProfileList State bitmask into human-readable flags.
      Source: Microsoft ProfileInfo / ProfSvc documentation and observed behavior.
    #>
    param([Nullable[int]]$State)

    if ($null -eq $State)  { return '<missing>' }
    if ($State -eq 0)      { return 'Normal (no flags set)' }

    $bits = [ordered]@{
        0x0001 = 'Mandatory'
        0x0002 = 'UseCache (Roaming)'
        0x0004 = 'NewLocal'
        0x0008 = 'NewCentral'
        0x0010 = 'UpdateCentral'
        0x0020 = 'Restored'
        0x0040 = 'Guest'
        0x0080 = 'Admin'
        0x0100 = 'DefaultNetReady (profile failed to load, default used)'
        0x0200 = 'Partial'
        0x0400 = 'Roaming preference'
        0x0800 = 'Temporary'
        0x1000 = 'Loading'
        0x2000 = 'Background upload'
        0x4000 = 'Prepared for upload'
        0x8000 = 'Updating / not yet loaded'
    }

    $flags = foreach ($bit in $bits.Keys) {
        if (($State -band $bit) -eq $bit) { $bits[$bit] }
    }

    if (-not $flags) {
        return ('Unknown (0x{0:X})' -f $State)
    }
    return ($flags -join ', ')
}

function Get-ProfileEntryInfo {
    param([string]$KeyPath)
    # Build enriched info for a single ProfileList entry.
    $props      = Get-ItemProperty -Path $KeyPath -ErrorAction SilentlyContinue
    $path       = $props.ProfileImagePath
    $pathExists = if ($path) { Test-Path -LiteralPath $path -PathType Container } else { $false }

    $ntuserMtime = $null
    if ($pathExists) {
        $ntuser = Join-Path $path 'NTUSER.DAT'
        if (Test-Path -LiteralPath $ntuser -PathType Leaf) {
            try {
                $ntuserMtime = (Get-Item -LiteralPath $ntuser -Force).LastWriteTime
            } catch { }
        }
    }

    # Distinguish "value absent" from "value is 0". PSObject.Properties is the
    # reliable way to check because $props.State would coerce either to $null/0.
    $hasState = $null -ne $props -and
                $null -ne ($props.PSObject.Properties['State'])
    $stateValue = if ($hasState) { [int]$props.State } else { $null }

    [pscustomobject]@{
        KeyName          = Split-Path $KeyPath -Leaf
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
    <#
      Returns a hashtable:
        Winner     = entry object judged "in use", or $null
        Confidence = 'High' | 'Medium' | 'Low' | 'None'
        Reason     = human-readable explanation
    #>
    param([object[]]$Entries)

    # --- Same-path duplicates -------------------------------------------------
    # If all entries point at the same ProfileImagePath, NTUSER.DAT comparison
    # is meaningless (same file). The question is which registry key survives,
    # not which folder is real. Rules:
    #   - One non-.bak + one-or-more .bak -> keep non-.bak (the active key)
    #   - All non-.bak                   -> functionally identical; pick first
    #   - All .bak                       -> keep the plain .bak if present,
    #                                       otherwise pick first (arbitrary)
    $distinctPaths = @($Entries | Where-Object ProfilePath |
                       Select-Object -ExpandProperty ProfilePath -Unique)

    if ($distinctPaths.Count -eq 1) {
        # Registry constraint: at most ONE '<SID>' (plain) key and at most ONE
        # '<SID>.bak' key can exist. Additional entries, if any, are numbered
        # variants like '<SID>.bak_1'. A duplicate group therefore always
        # contains EITHER the plain key OR the plain .bak key (or both).
        $nonBak   = @($Entries | Where-Object { -not $_.IsBak })
        $plainBak = @($Entries | Where-Object { $_.KeyName -match '\.bak$' })

        if ($nonBak.Count -eq 1) {
            return @{
                Winner     = $nonBak[0]
                Confidence = 'High'
                Reason     = "Same-path duplicate; non-.bak is the active key (Profile Service reads this on next logon)."
            }
        }

        if ($plainBak.Count -eq 1) {
            return @{
                Winner     = $plainBak[0]
                Confidence = 'Medium'
                Reason     = "All entries are .bak variants pointing to same path; keeping plain .bak over numbered variants."
            }
        }

        # Not expected under Windows' own ProfSvc behavior: would require
        # '<SID>.bak_1' + '<SID>.bak_2' with no plain '<SID>' and no plain '<SID>.bak'.
        # Fall through to 'None' rather than guessing.
        return @{
            Winner     = $null
            Confidence = 'None'
            Reason     = "Same-path duplicates with no plain or plain-.bak key present; unexpected shape, manual review required."
        }
    }

    # --- Different paths: try State-based disambiguation first ----------------
    # A missing State value typically means the key was never fully initialized
    # by the Profile Service (crash, manual edit, failed migration). If exactly
    # one sibling has a State value, the one WITH State is the healthy profile;
    # the others are structurally incomplete.
    $withState = @($Entries | Where-Object HasState)

    if ($withState.Count -eq 1 -and $Entries.Count -gt 1) {
        return @{
            Winner     = $withState[0]
            Confidence = 'High'
            Reason     = "Only one entry has a State value; sibling(s) missing State suggest incomplete/corrupt keys."
        }
    }

    # --- Different paths: folder-existence + mtime heuristics -----------------
    $withFolder = @($Entries | Where-Object PathExists)
    $withMtime  = @($withFolder | Where-Object { $_.NTUserMtime })

    # Case: exactly one entry has a real folder -> that one wins, high confidence.
    if ($withFolder.Count -eq 1) {
        return @{
            Winner     = $withFolder[0]
            Confidence = 'High'
            Reason     = 'Only one entry has an existing ProfileImagePath folder.'
        }
    }

    # Case: no folders exist on disk -> both orphaned.
    if ($withFolder.Count -eq 0) {
        return @{
            Winner     = $null
            Confidence = 'None'
            Reason     = 'No entry has an existing profile folder. Possibly FSLogix-managed or fully orphaned.'
        }
    }

    # Case: multiple folders exist, but NTUSER.DAT missing from at least one ->
    # can't compare timestamps reliably.
    if ($withMtime.Count -lt $withFolder.Count) {
        return @{
            Winner     = $null
            Confidence = 'None'
            Reason     = 'Multiple folders exist but at least one has no readable NTUSER.DAT.'
        }
    }

    # Case: multiple folders with timestamps -> compare.
    $sorted = $withMtime | Sort-Object NTUserMtime -Descending
    $newest = $sorted[0]
    $second = $sorted[1]
    $deltaHours = ($newest.NTUserMtime - $second.NTUserMtime).TotalHours

    # Temp / backup folder name patterns that often indicate a broken profile
    # created by ProfSvc after it failed to load the real one.
    $looksLikeTemp = {
        param($p)
        $leaf = Split-Path $p -Leaf
        $leaf -match '\.(TEMP|OLD|BAK|000|001|002)(\.\d+)?$' -or
        $leaf -match '^TEMP\.'
    }

    $newestIsTemp = & $looksLikeTemp $newest.ProfilePath
    $secondIsTemp = & $looksLikeTemp $second.ProfilePath

    # If the "newer" entry is a TEMP/.OLD-style folder, it's almost certainly
    # the broken profile that got created after the real one failed to load.
    if ($newestIsTemp -and -not $secondIsTemp) {
        return @{
            Winner     = $second
            Confidence = 'Medium'
            Reason     = "Newer entry path looks like a temp/fallback profile ($($newest.ProfilePath)); preferring older non-temp entry."
        }
    }

    if ($deltaHours -ge 24) {
        return @{
            Winner     = $newest
            Confidence = 'Medium'
            Reason     = ("Newest NTUSER.DAT is {0:N1}h ahead of next entry." -f $deltaHours)
        }
    }

    if ($deltaHours -ge 1) {
        return @{
            Winner     = $newest
            Confidence = 'Low'
            Reason     = ("Newest NTUSER.DAT only {0:N1}h ahead; ambiguous." -f $deltaHours)
        }
    }

    return @{
        Winner     = $null
        Confidence = 'None'
        Reason     = ("NTUSER.DAT timestamps within {0:N1}h of each other; indistinguishable." -f $deltaHours)
    }
}

try {
    Write-PersistentLog -Message "Detection invoked."

    $keys = Get-ChildItem -Path $base -ErrorAction Stop

    # Group by SID (strip trailing .bak / .bak_<n> suffixes) and keep only user SIDs.
    $grouped = $keys | Group-Object -Property {
        $_.PSChildName -replace '\.bak(_\d+)?$',''
    } | Where-Object {
        $_.Count -gt 1 -and (Test-IsUserSid $_.Name)
    }

    if (-not $grouped) {
        $msg = "ProfileList healthy: no duplicate user SIDs."
        Write-Output $msg
        Write-PersistentLog -Message $msg
        exit 0
    }

    $reportLines = foreach ($g in $grouped) {
        $entries = foreach ($k in $g.Group) {
            Get-ProfileEntryInfo -KeyPath $k.PSPath
        }

        $resolution = Resolve-InUseEntry -Entries $entries

        $entryStrs = foreach ($e in $entries) {
            $mt = if ($e.NTUserMtime) { $e.NTUserMtime.ToString('s') } else { 'n/a' }
            $stateNum = if ($e.HasState) { $e.State } else { '<missing>' }
            '{0} [path={1}; exists={2}; ntuser={3}; state={4} ({5})]' -f `
                $e.KeyName, $e.ProfilePath, $e.PathExists, $mt,
                $stateNum, $e.StateDescription
        }

        $winnerStr = if ($resolution.Winner) { $resolution.Winner.KeyName } else { 'UNDETERMINED' }

        ("SID={0} | Count={1} | InUse={2} | Confidence={3} | Reason={4} | Entries: {5}" -f `
            $g.Name, $g.Count, $winnerStr, $resolution.Confidence,
            $resolution.Reason, ($entryStrs -join ' ;; '))
    }

    # One Write-Output with real line breaks so the Intune portal renders the list readably.
    $lines = @("Duplicate ProfileList SIDs detected. Remediation required:") + ($reportLines | ForEach-Object { " - $_" })
    $output = $lines -join "`r`n"
    Write-Output $output
    Write-PersistentLog -Message ("Drift detected: " + ($reportLines -join ' | ')) -Level 'Warn'
    exit 1
}
catch {
    # Fail closed: don't flag devices because detection itself broke.
    $errMsg = "Detection error: [$($_.Exception.GetType().Name)] $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))"
    Write-Output $errMsg
    Write-PersistentLog -Message $errMsg -Level 'Error'
    exit 0
}
