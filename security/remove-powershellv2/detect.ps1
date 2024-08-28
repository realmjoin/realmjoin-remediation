#=============================================================================================================================
#
# Script Name:     Detect.ps1
# Description:     Detect if Powershell v2 is enabled on the machine.
#                 
#=============================================================================================================================

try
{
    # Get current state of Powershell v2 
    $PS2State = (Get-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2).State

    if ($PS2State -eq "Enabled") {
        Write-Host "Powershell v2 is enabled, start remediation"
        exit 1
    } else {
        Write-Host "Powershell v2 is NOT enabled, do nothing"        
        exit 0
    } 
}
catch{
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}