#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Check if task Tpm-HASCertRetr exists and is ready to run.
# Changelog:           2025-04-24: Updated execution logic.
#
#=============================================================================================================================

# define Variables
$task = Get-ScheduledTask -TaskName "Tpm-HASCertRetr" -TaskPath "\Microsoft\Windows\TPM\" -ErrorAction SilentlyContinue

$path = "HKLM:\SOFTWARE\RealmJoin\Custom\PAR\trigger-tpm-healthattestationcertificate-retrieval"
$name = "Executed"
$value = 0
$type = [Microsoft.Win32.RegistryValueKind]::DWord

# get status
$parStatus = (Get-ItemPropertyValue -Path $path -Name $name -ErrorAction SilentlyContinue)
if($parStatus -eq 1) {
    Write-Host "Remediation did run."
    # Reset status
    Set-ItemProperty -Path $path -Name $name -Value $value -Type $type -Force | Out-Null
    exit 0
} else {
    Write-Host "Start remediation."

    # check task status
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

}