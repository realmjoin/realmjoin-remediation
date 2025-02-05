#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Start scheduled task Tpm-HASCertRetr.
#
#=============================================================================================================================

try {
    
    # start task
    Write-Host "Trigger task Tpm-HASCertRetr"
    Start-ScheduledTask -TaskName "Tpm-HASCertRetr" -TaskPath "\Microsoft\Windows\TPM\"
    exit 0

} catch {
    # error occured
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}