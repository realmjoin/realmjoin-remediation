#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Check if task Tpm-HASCertRetr exists and is ready to run.
#
#=============================================================================================================================

# define Variables
$task = Get-ScheduledTask -TaskName "Tpm-HASCertRetr" -TaskPath "\Microsoft\Windows\TPM\" -ErrorAction SilentlyContinue

# check status
if($task.State -eq "Ready") {
    # task found and ready to run
    Write-Host "Task found and ready to run."
    exit 1
} elseif ($task.State -eq "Running") {
    # task found and running
    Write-Host "Task found and already running. Nothing to do."
    exit 0
} else {
    # task not found or not ready
    Write-Host "Task not found. Cannot proceed."
    exit 0
}