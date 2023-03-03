#=============================================================================================================================
#
# Script Name:     Remediate-OpenSSHClient.ps1
# Description:     Remediate OpenSSHClient
#                 
#=============================================================================================================================

$clients = Get-WindowsCapability -Online | Where-Object { $_.Name -like "OpenSSH.Client*" }

foreach ($client in $clients) {
    try {
        Remove-WindowsCapability -Online -Name $client.Name
        write-host "Removal of '$($client.Name)' succeeded."
    }
    catch {
        write-host "Removal of '$($client.Name)' failed."
    }
}