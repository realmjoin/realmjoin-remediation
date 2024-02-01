#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Stop the running service and change behaviour to not start running automatically
# Changelog:           01.02.2024
# References:          ...
# Notes:               ...
#
#=============================================================================================================================

# define variables
$serviceName = "HPAudioAnalytics" # define the name of the service that you want to stop

try {
    #this will stop the service and change the behaviour for it to not start automatically
    Get-Service -Name $serviceName | Stop-Service -Force
    Set-Service $serviceName -StartupType  Disabled
    Write-Host "$serviceName has been stopped and startup disabled."
    # problem fixed
    exit 0
} catch {
    # error occured
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}