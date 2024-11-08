#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detect if dot3svc service is configured as start mode automatic and started.
# Changelog:           2024-11-07: Create detection.
#
#=============================================================================================================================

$Service = Get-Service -Name dot3svc

if (($Service.Status -ne "Running") -or ($Service.StartType -ne "Automatic")) {
    # problem detected
    write-Host "dot3svc service is not configured correctly"
    #exit 1
}     else {
    # no problem detected
    Write-Host "dot3svc service is configured correctly"
    #exit 0
}