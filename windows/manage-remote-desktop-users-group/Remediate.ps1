#=============================================================================================================================
#
# Script Name:         Remediate-RDPUsers.ps1
# Description:         Populates the local "Remote Desktop Users" group with all Entra accounts that have been
#                      active within the last 8 weeks. Removes inactive Entra accounts from the group.
# Changelog:           2025-06-04: Initial version.
#                      2026-07-22: Use Entra SIDs for membership comparison and updates.
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
                $low      = [uint32]$_.LocalProfileLoadTimeLow
                $high     = [uint32]$_.LocalProfileLoadTimeHigh
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
        } |
        Where-Object { ($null -ne $_.LastUse) -and ($_.LastUse -ge $cutoffDate) }

    $expectedSIDs = @($profileList | ForEach-Object { $_.SIDValue })

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

    $toRemove = @($currentMembers | Where-Object { $_.SIDValue -notin $expectedSIDs })
    $toAdd = @($profileList | Where-Object { $_.SIDValue -notin $currentSIDs })
    $operationFailed = $false

    # Remove inactive Entra accounts
    foreach ($member in $toRemove) {
        if ($DryRun) {
            Write-Host "Would remove: $($member.Name) [$($member.SIDValue)]"
        } else {
            try {
                Remove-LocalGroupMember -SID $rdpGroupSID -Member $member.SIDValue -ErrorAction Stop
                Write-Host "Removed: $($member.SIDValue)"
            } catch {
                $operationFailed = $true
                Write-Host "Error removing SID '$($member.SIDValue)': $($_.Exception.Message)"
            }
        }
    }

    # Add missing Entra accounts
    foreach ($userProfile in $toAdd) {
        if ($DryRun) {
            Write-Host "Would add: $($userProfile.ProfilePath) [$($userProfile.SIDValue)]"
        } else {
            try {
                Add-LocalGroupMember -SID $rdpGroupSID -Member $userProfile.SIDValue -ErrorAction Stop
                Write-Host "Added: $($userProfile.SIDValue)"
            } catch {
                $operationFailed = $true
                Write-Host "Error adding SID '$($userProfile.SIDValue)': $($_.Exception.Message)"
            }
        }
    }

    if ($toRemove.Count -eq 0 -and $toAdd.Count -eq 0) {
        Write-Host "No changes needed."
    }

    if ($DryRun) {
        Write-Host "=== DRY RUN completed - no changes were made ==="
    } elseif ($operationFailed) {
        Write-Host "One or more group membership updates failed."
        exit 1
    } else {
        $updatedSIDs = @(
            Get-LocalGroupMember -SID $rdpGroupSID -ErrorAction Stop |
                Where-Object { ($null -ne $_.SID) -and ($_.SID.Value -match $entraSIDPattern) } |
                ForEach-Object { $_.SID.Value }
        )
        $missingSIDs = @($expectedSIDs | Where-Object { $_ -notin $updatedSIDs })
        $unexpectedSIDs = @($updatedSIDs | Where-Object { $_ -notin $expectedSIDs })

        if ($missingSIDs.Count -gt 0 -or $unexpectedSIDs.Count -gt 0) {
            Write-Host "Group membership verification failed. Missing SIDs: $($missingSIDs -join ', ') | Unexpected SIDs: $($unexpectedSIDs -join ', ')"
            exit 1
        }

        # problem fixed
        Write-Host "Group memberships updated and verified."
    }
    exit 0

} catch {
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}