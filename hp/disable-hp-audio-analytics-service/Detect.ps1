#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detect detect if the service is running on the device
# Changelog:           01.02.2024 initial creation
# References:          ...
# Notes:               ...
#
#=============================================================================================================================

# define Variables
$serviceName = "HPAudioAnalytics" # define the name of the service that you want to stop
$serviceStatus = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

# check if the service is there and running

if ($serviceStatus.Status -eq "Stopped") {
    Write-Host "$serviceName exists, but not running."
    # this means the service is already stopped and will not start a remediation
    # No Problem detected
    exit 0
} elseif ($serviceStatus.Status -eq "Running") {
    Write-Host "$serviceName is running."
    # running service is detected
    # problem detected
    exit 1

} else {
    Write-Host "$serviceName does not exist."
    # this means the service does not exist and will not start a remediation
    # no problem detected
    exit 0
}