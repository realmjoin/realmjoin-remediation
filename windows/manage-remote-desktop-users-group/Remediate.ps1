#=============================================================================================================================
#
# Script Name:         Remediate-RDPUsers.ps1
# Description:         Populates the local "Remote Desktop Users" group with all Entra accounts that have been
#                      active within the last 8 weeks. Removes inactive Entra accounts from the group.
# Changelog:           2025-06-04: Initial version.
# References:          ...
# Notes:               Dry Run (interactive test): .\Remediate-RDPUsers.ps1 -DryRun
#                      Normal run (Intune):        .\Remediate-RDPUsers.ps1
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
        } |
        Where-Object { ($null -ne $_.LastUse) -and ($_.LastUse -ge $cutoffDate) }

    $expectedUsers = @($profileList | ForEach-Object { "AzureAD\$($_.Username)" })

    # Get current AzureAD members of the group
    $currentAzureADMembers = @(
        Get-LocalGroupMember -SID $rdpGroupSID -ErrorAction Stop |
            Where-Object { $_.PrincipalSource -eq "AzureAD" -or $_.Name -match "AzureAD\\" } |
            ForEach-Object { $_.Name }
    )

    $toRemove = @($currentAzureADMembers | Where-Object { $_ -notin $expectedUsers })
    $toAdd    = @($expectedUsers | Where-Object { $_ -notin $currentAzureADMembers })

    # Remove inactive Entra accounts
    foreach ($user in $toRemove) {
        if ($DryRun) {
            Write-Host "Would remove: $user"
        } else {
            try {
                Remove-LocalGroupMember -SID $rdpGroupSID -Member $user -ErrorAction Stop
                Write-Host "Removed: $user"
            } catch {
                Write-Host "Error removing $user : $_"
            }
        }
    }

    # Add missing Entra accounts
    foreach ($user in $toAdd) {
        if ($DryRun) {
            Write-Host "Would add: $user"
        } else {
            try {
                Add-LocalGroupMember -SID $rdpGroupSID -Member $user -ErrorAction Stop
                Write-Host "Added: $user"
            } catch {
                Write-Host "Error adding $user : $_"
            }
        }
    }

    if ($toRemove.Count -eq 0 -and $toAdd.Count -eq 0) {
        Write-Host "No changes needed."
    }

    if ($DryRun) {
        Write-Host "=== DRY RUN completed - no changes were made ==="
    } else {
        # problem fixed
        Write-Host "Group memberships updated."
    }
    exit 0

} catch {
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}