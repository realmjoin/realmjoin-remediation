#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Deactivate firewall rules
#
#=============================================================================================================================

# define variables
$results = 0

try {   
    # Check if there are any enabled rules for Group "Network Discovery" = @FirewallAPI.dll,-32752
    $results = Get-NetFirewallRule -Direction Inbound -Enabled True  | `
    Where-Object {(($_.Profile -contains "Any") -or ($_.Profile -contains "Public"))} | `
    Where-Object {($_.Group -eq "@FirewallAPI.dll,-32752")}

    # Check if there are any enabled rules for Group "File and Printer Sharing" = @FirewallAPI.dll,-28502
    $results += Get-NetFirewallRule -Direction Inbound -Enabled True | `
    Where-Object {(($_.Profile -contains "Any") -or ($_.Profile -contains "Public"))} | `
    Where-Object {($_.Group -eq "@FirewallAPI.dll,-28502")}

    if (($null -ne $results)){
        foreach ($result in $results) {
            Disable-NetFirewallRule -Name $result.Name
        }
    }  
    exit 0
} catch {
    # error occured
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}