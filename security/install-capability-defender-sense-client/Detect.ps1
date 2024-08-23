#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Check if Sense service is found
# Changelog:           2024-08-20: Inital version.
#
#=============================================================================================================================

# Get Sense service
$senseService = Get-Service "Sense" -ErrorAction SilentlyContinue

# Check if service has been found
if($null -eq $senseService) {
    Write-Output "Sense service not found."
    exit 1
} else {
    Write-Output "Sense service found. OK."
    exit 0
}