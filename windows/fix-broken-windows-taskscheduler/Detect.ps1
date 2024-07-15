#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detect if Windows TaskScheduler is broken.
#
#=============================================================================================================================

# In case of a broken Task Scheduler, Get-ScheduledTask will throw errors.
try {
    Get-ScheduledTask -EA Stop
    Write-Output "OK - No error while performing Get-ScheduledTask"
    exit 0
} catch {
    # problem detected
    Write-Output "Remediate - Error while performing Get-ScheduledTask."
    exit 1
}