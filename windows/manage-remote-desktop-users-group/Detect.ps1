#=============================================================================================================================
#
# Script Name:         Detect-RDPUsers.ps1
# Description:         Checks if the local "Remote Desktop Users" group contains Entra accounts
#                      that have been active within the last 8 weeks.
# Changelog:           2025-06-04: Initial version.
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
$rdpGroupSID = "S-1-5-32-555"

try {
    $groupName = (Get-LocalGroup | Where-Object { $_.SID -eq $rdpGroupSID }).Name

    if ($DryRun) {
        Write-Host "=== DRY RUN - no changes will be made ==="
        Write-Host "Group: $groupName (SID: $rdpGroupSID)"
        Write-Host "Threshold: $weeksThreshold weeks (since $cutoffDate)"
    }

    # Get all Entra profiles (SID S-1-12-1-* = Entra-joined accounts)
    $profileList = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*" |
        Where-Object { $_.PSChildName -match "^S-1-12-1-" } |
        ForEach-Object {
            $lastUse = $null
            if (($null -ne $_.LocalProfileLoadTimeLow) -and ($null -ne $_.LocalProfileLoadTimeHigh)) {
                $low      = [uint32]$_.LocalProfileLoadTimeLow
                $high     = [uint32]$_.LocalProfileLoadTimeHigh
                $fileTime = ([int64]$high -shl 32) -bor $low
                if ($fileTime -gt 0) {
                    $lastUse = [DateTime]::FromFileTime($fileTime)
                }
            }
            [PSCustomObject]@{
                ProfilePath = $_.ProfileImagePath
                Username    = ($_.ProfileImagePath -split "\\")[-1]
                LastUse     = $lastUse
            }
        }

    if ($DryRun) {
        Write-Host ""
        Write-Host "--- All found Entra profiles ---"
        foreach ($p in $profileList) {
            if ($null -eq $p.LastUse) {
                $status = "LastUse unknown"
            } elseif ($p.LastUse -ge $cutoffDate) {
                $status = "ACTIVE ($($p.LastUse))"
            } else {
                $status = "inactive ($($p.LastUse))"
            }
            Write-Host "  $($p.Username) - $status"
        }
    }

    $activeProfiles = $profileList | Where-Object { ($null -ne $_.LastUse) -and ($_.LastUse -ge $cutoffDate) }
    $expectedUsers  = @($activeProfiles | ForEach-Object { "AzureAD\$($_.Username)" })

    # Get current AzureAD members of the group
    $currentMembers = @(
        Get-LocalGroupMember -SID $rdpGroupSID -ErrorAction Stop |
            Where-Object { $_.PrincipalSource -eq "AzureAD" -or $_.Name -match "AzureAD\\" } |
            ForEach-Object { $_.Name }
    )

    if ($DryRun) {
        Write-Host ""
        Write-Host "--- Current AzureAD members in '$groupName' ---"
        if ($currentMembers.Count -eq 0) {
            Write-Host "  (none)"
        } else {
            foreach ($m in $currentMembers) { Write-Host "  $m" }
        }
        Write-Host ""
        Write-Host "--- Expected members (active profiles) ---"
        if ($expectedUsers.Count -eq 0) {
            Write-Host "  (none)"
        } else {
            foreach ($u in $expectedUsers) { Write-Host "  $u" }
        }
    }

    $toAdd    = @($expectedUsers | Where-Object { $_ -notin $currentMembers })
    $toRemove = @($currentMembers | Where-Object { $_ -notin $expectedUsers })

    if ($DryRun) {
        Write-Host ""
        Write-Host "--- Result ---"
        if ($toAdd.Count -gt 0)    { Write-Host "Would add:    $($toAdd -join ', ')" }
        if ($toRemove.Count -gt 0) { Write-Host "Would remove: $($toRemove -join ', ')" }
        if ($toAdd.Count -eq 0 -and $toRemove.Count -eq 0) { Write-Host "No changes needed." }
        exit 0
    }

    if ($toAdd.Count -eq 0 -and $toRemove.Count -eq 0) {
        # no problem detected
        Write-Host "Group membership OK."
        exit 0
    } else {
        # problem detected
        Write-Host "Update required. Add: $($toAdd -join ', ') | Remove: $($toRemove -join ', ')"
        exit 1
    }

} catch {
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}