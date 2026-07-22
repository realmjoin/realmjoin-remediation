#=============================================================================================================================
#
# Script Name:         Detect-RDPUsers.ps1
# Description:         Checks if the local "Remote Desktop Users" group contains Entra accounts
#                      that have been active within the last 8 weeks.
# Changelog:           2025-06-04: Initial version.
#                      2026-07-22: Use Entra SIDs for membership comparison.
# References:          ...
# Notes:               Dry Run (interactive test): .\Detect-RDPUsers.ps1 -DryRun
#                      Normal run (Intune):        .\Detect-RDPUsers.ps1
#
#=============================================================================================================================

param(
    [switch]$DryRun
)

$weeksThreshold = 8
$cutoffDate = (Get-Date).AddDays(-$weeksThreshold * 7)
$rdpGroupSID = [System.Security.Principal.SecurityIdentifier]"S-1-5-32-555"
$entraSIDPattern = "^S-1-12-1-\d+-\d+-\d+-\d+$"

try {
    $groupName = (Get-LocalGroup -SID $rdpGroupSID -ErrorAction Stop).Name

    if ($DryRun) {
        Write-Host "=== DRY RUN - no changes will be made ==="
        Write-Host "Group: $groupName (SID: $rdpGroupSID)"
        Write-Host "Threshold: $weeksThreshold weeks (since $cutoffDate)"
    }

    # ProfileList keys provide the canonical Entra identity; profile folder names do not.
    $profileList = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*" -ErrorAction Stop |
    Where-Object { $_.PSChildName -match $entraSIDPattern } |
    ForEach-Object {
        $lastUse = $null
        if (($null -ne $_.LocalProfileLoadTimeLow) -and ($null -ne $_.LocalProfileLoadTimeHigh)) {
            $low = [uint32]$_.LocalProfileLoadTimeLow
            $high = [uint32]$_.LocalProfileLoadTimeHigh
            $fileTime = ([int64]$high -shl 32) -bor $low
            if ($fileTime -gt 0) {
                $lastUse = [DateTime]::FromFileTime($fileTime)
            }
        }
        [PSCustomObject]@{
            ProfilePath = $_.ProfileImagePath
            SIDValue    = $_.PSChildName
            LastUse     = $lastUse
        }
    }

    if ($DryRun) {
        Write-Host ""
        Write-Host "--- All found Entra profiles ---"
        foreach ($p in $profileList) {
            if ($null -eq $p.LastUse) {
                $status = "LastUse unknown"
            }
            elseif ($p.LastUse -ge $cutoffDate) {
                $status = "ACTIVE ($($p.LastUse))"
            }
            else {
                $status = "inactive ($($p.LastUse))"
            }
            Write-Host "  $($p.ProfilePath) [$($p.SIDValue)] - $status"
        }
    }

    $activeProfiles = $profileList | Where-Object { ($null -ne $_.LastUse) -and ($_.LastUse -ge $cutoffDate) }
    $expectedSIDs = @($activeProfiles | ForEach-Object { $_.SIDValue })

    # Entra users and groups use S-1-12-1-* SIDs. Other principal types are left untouched.
    $currentMembers = @(
        Get-LocalGroupMember -SID $rdpGroupSID -ErrorAction Stop |
        Where-Object { ($null -ne $_.SID) -and ($_.SID.Value -match $entraSIDPattern) } |
        ForEach-Object {
            [PSCustomObject]@{
                Name     = $_.Name
                SIDValue = $_.SID.Value
            }
        }
    )
    $currentSIDs = @($currentMembers | ForEach-Object { $_.SIDValue })

    if ($DryRun) {
        Write-Host ""
        Write-Host "--- Current Entra members in '$groupName' ---"
        if ($currentMembers.Count -eq 0) {
            Write-Host "  (none)"
        }
        else {
            foreach ($m in $currentMembers) { Write-Host "  $($m.Name) [$($m.SIDValue)]" }
        }
        Write-Host ""
        Write-Host "--- Expected members (active profiles) ---"
        if ($activeProfiles.Count -eq 0) {
            Write-Host "  (none)"
        }
        else {
            foreach ($p in $activeProfiles) { Write-Host "  $($p.ProfilePath) [$($p.SIDValue)]" }
        }
    }

    $toAdd = @($activeProfiles | Where-Object { $_.SIDValue -notin $currentSIDs })
    $toRemove = @($currentMembers | Where-Object { $_.SIDValue -notin $expectedSIDs })

    if ($DryRun) {
        Write-Host ""
        Write-Host "--- Result ---"
        if ($toAdd.Count -gt 0) { Write-Host "Would add SIDs:    $($toAdd.SIDValue -join ', ')" }
        if ($toRemove.Count -gt 0) { Write-Host "Would remove SIDs: $($toRemove.SIDValue -join ', ')" }
        if ($toAdd.Count -eq 0 -and $toRemove.Count -eq 0) { Write-Host "No changes needed." }
        exit 0
    }

    if ($toAdd.Count -eq 0 -and $toRemove.Count -eq 0) {
        # no problem detected
        Write-Host "Group membership OK."
        exit 0
    }
    else {
        # problem detected
        Write-Host "Update required. Add SIDs: $($toAdd.SIDValue -join ', ') | Remove SIDs: $($toRemove.SIDValue -join ', ')"
        exit 1
    }

}
catch {
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}