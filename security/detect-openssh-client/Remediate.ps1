#=============================================================================================================================
#
# Script Name:     Remediate.ps1
# Description:     Remove OpenSSHClient
#                 
#=============================================================================================================================

$clients = Get-WindowsCapability -Online | Where-Object { $_.Name -like "OpenSSH.Client*" }

foreach ($client in $clients) {
    try {
        Remove-WindowsCapability -Online -Name $client.Name
        Write-Host "Removal of '$($client.Name)' succeeded."
        exit 0
    }
    catch {
        $errMsg = $_.Exception.Message
        Write-Host "Error: $errMsg"
        exit 1
    }
}