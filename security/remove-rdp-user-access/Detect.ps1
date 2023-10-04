#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detect if current user is member of Remote Desktop Users
#
#=============================================================================================================================

param(
    $SID = "S-1-5-32-555"
)
function Get-LoggedOnUser {
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateScript({ Test-Connection -ComputerName $_ -Quiet -Count 1 })]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName = $env:COMPUTERNAME
    )
    foreach ($comp in $ComputerName) {
        $output = @{ 'ComputerName' = $comp }
        $output.UserName = (Get-WmiObject -Class win32_computersystem -ComputerName $comp).UserName
        [PSCustomObject]$output
    }
}

$accounts = Get-LoggedOnUser
$groupMembers = (Get-LocalGroupMember -SID $SID).Name

foreach ($account in $accounts) {
    if ($groupMembers -contains $account.UserName) {
        Write-Host "User '$($account.UserName)' is member of Remote Desktop Users"
        exit 1
    }
}

# No user <-> Remote Desktop Users matches
exit 0