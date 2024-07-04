#=============================================================================================================================
#
# Script Name:     Remediate.ps1
# Description:     Remediate by disabling Powershell v2 on the machine.
#                 
#=============================================================================================================================

try
{
    Write-Host "Disabling Powershell v2..."
    Disable-WindowsOptionalFeature -Online -NoRestart -FeatureName MicrosoftWindowsPowerShellV2Root
    exit 0
}
catch{
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}