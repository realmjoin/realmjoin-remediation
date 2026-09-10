#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detect if the Automatic Time Zone Updater service (tzautoupdate) is set to startup type Automatic.
# Changelog:           2026-09-09: Initial version
# References:          https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-system#allowlocation
# Notes:               Only the startup type is checked. tzautoupdate is a trigger-start service that stops itself after
#                      adjusting the time zone, so the running state is not a reliable compliance indicator.
#                      Stripped-down variant of "enable-location-service-and-automatic-timezone" for tenants where the
#                      Location Service is already enforced via policy and only the time zone part is missing.
#
#=============================================================================================================================

try {

    ##Variable declaration
    $serviceName = "tzautoupdate"
    $startupType = "Automatic"

    ##Get current service state, throws if the service does not exist
    $service = Get-Service -Name $serviceName -ErrorAction Stop

    ##Compare startup type
    if ($service.StartType -ne $startupType) {
        #MATCH. Remediate. Startup type is not set to target value.
        Write-Host "Service $serviceName startup type is '$($service.StartType)' (expected '$startupType')."
        exit 1
    }

    #NO MATCH. Do not remediate. Startup type is already set to target value.
    Write-Host "Service $serviceName startup type is '$startupType'."
    exit 0

}
catch {
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}
