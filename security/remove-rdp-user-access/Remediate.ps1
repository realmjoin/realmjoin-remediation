#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Remove current user from Remote Desktop Users group
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

foreach ($account in $accounts) {
    try {
        Remove-LocalGroupMember -SID $SID -Member $account.UserName
        Write-Host "Removed '$($account.UserName)' from Remote Desktop Users"
        exit 0
    } catch {
        $errMsg = $_.Exception.Message
        Write-Host "Failed to remove user $($account.UserName), Error: $($errMsg)"
        exit 1
    }
}
