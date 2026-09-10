#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Set the Automatic Time Zone Updater service (tzautoupdate) to startup type Automatic.
# Changelog:           2026-09-09: Initial version
# References:          https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-system#allowlocation
# Notes:               Requires the Windows Location Service to be allowed (e.g. via policy), otherwise the service
#                      cannot determine the time zone. After setting the startup type the service is started once on a
#                      best-effort basis so the time zone is adjusted without waiting for the next reboot.
#
#=============================================================================================================================

##Fail loud, service errors are non-terminating by default and would be reported as a successful remediation
$ErrorActionPreference = "Stop"

try {

    ##Variable declaration
    $serviceName = "tzautoupdate"
    $startupType = "Automatic"

    ##Get current service state, throws if the service does not exist
    $service = Get-Service -Name $serviceName -ErrorAction Stop

    ##Set startup type if different
    if ($service.StartType -ne $startupType) {
        Set-Service -Name $serviceName -StartupType $startupType
        Write-Host "Service $serviceName startup type changed from '$($service.StartType)' to '$startupType'."
    } else {
        Write-Host "Service $serviceName startup type is already '$startupType'."
    }

    ##Verify the write
    $service = Get-Service -Name $serviceName -ErrorAction Stop
    if ($service.StartType -ne $startupType) {
        Write-Error "Service $serviceName startup type could not be set to '$startupType' (current: '$($service.StartType)')."
        exit 1
    }

    ##Trigger the service once so the time zone is adjusted right away. The service stops itself after doing its job,
    ##a failed start (e.g. location currently unavailable) is not a remediation failure.
    try {
        if ($service.Status -ne "Running") {
            Start-Service -Name $serviceName -ErrorAction Stop
            Write-Host "Service $serviceName started."
        } else {
            Write-Host "Service $serviceName is already running."
        }
    }
    catch {
        Write-Host "Service $serviceName could not be started ($($_.Exception.Message)). Startup type is set; Windows will retry when the service is next triggered."
    }

    #Success if no errors occurred.
    exit 0

}
catch {
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}
