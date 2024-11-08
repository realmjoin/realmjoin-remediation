#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Set dot3svc service as start mode automatic and started.
# Changelog:           2024-11-07: Create remediation.
#
#=============================================================================================================================


try {
    # do some crazy stuff
    Set-Service -Name dot3svc -StartupType Automatic -Status Running -ErrorAction Stop
    Write-Host "Successfully configured and started dot3svc service."
    exit 0
} catch {
    # error occured
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}