#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Output members of Remote Desktop Users
#
#=============================================================================================================================

param(
    $SID = "S-1-5-32-555"
)

$groupMembers = (Get-LocalGroupMember -SID $SID).Name
$groupMembersOutput = ""

if($groupMembers.Count -gt 0) {
    foreach ($groupMember in $groupMembers) {
        $groupMembersOutput += "$($groupMember)"
        if ($groupMember -ne $groupMembers[-1]) {
            $groupMembersOutput += ", "
        }
    }
    Write-Host $groupMembersOutput
    exit 1
} else {
    # no user found
    Write-Host "No user found in Remote Desktop Users."
    exit 0
}