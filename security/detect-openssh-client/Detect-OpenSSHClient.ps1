#=============================================================================================================================
#
# Script Name:     Detect-OpenSSHClient.ps1
# Description:     Detect OpenSSHClient
#                 
#=============================================================================================================================
$clients = Get-WindowsCapability -Online | Where-Object { $_.Name -like "OpenSSH.Client*" }

if ($clients.count -gt 0) {
    foreach ($client in $clients) {
        if ($client.State -eq "Installed") {
            write-host "Capability '$($client.Name)' found."
            exit 1
        }
        else {
            # Not installed
            exit 0
        }
    }
}
else {
    # No such capability
    exit 0
}
