#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Check if Sense service is found
# Changelog:           2025-09-23: Package Status added.
#                      2024-08-20: Inital version.
#
#=============================================================================================================================

# Get Sense service
$senseService = Get-Service "Sense" -ErrorAction SilentlyContinue
 
# Check if service has been found
if($null -eq $senseService) {
    $sensePackage = Get-WindowsCapability -Name "Microsoft.Windows.Sense.Client~~~~" -Online
    Write-Output ("State: " + $sensePackage.State)
    exit 1
} else {
    Write-Output "State: Present"
    exit 0
}