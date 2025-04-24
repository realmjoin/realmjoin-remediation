#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Start scheduled task Tpm-HASCertRetr.
# Changelog:           2025-04-24: Updated execution logic.
#
#=============================================================================================================================

# define Variables
$path = "HKLM:\SOFTWARE\RealmJoin\Custom\PAR\trigger-tpm-healthattestationcertificate-retrieval"
$name = "Executed"
$value = 1
$type = [Microsoft.Win32.RegistryValueKind]::DWord

try {
    
    # start task
    Write-Host "Trigger task Tpm-HASCertRetr"
    Start-ScheduledTask -TaskName "Tpm-HASCertRetr" -TaskPath "\Microsoft\Windows\TPM\"

    # store execution status
    if(!(Test-Path $path)) {
        New-Item -Path $path -Force | Out-Null
        Set-ItemProperty -Path $path -Name $name -Value $value -Type $type -Force | Out-Null
    } else {
        Set-ItemProperty -Path $path -Name $name -Value $value -Type $type -Force | Out-Null
    }

    exit 0

} catch {
    # error occured
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}