#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Remediation Script which set the registry key for new Windows update notification if not set
# Changelog:           2025-01-22: initial version
#                      2025-01-24: clean-up
# 
#
#=============================================================================================================================

$RegPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
$RegName = "RestartNotificationsAllowed2"
$RegValue = 1                               # 1 = activated | 0 = not activated

# remediate the issue
Write-Output  "Detection has reported Error 1, attempting to remediate"
if (!(Test-Path $RegPath)) 
{
    New-Item -Path $RegPath -Force
    Set-ItemProperty -Path $RegPath -Name $RegName -Type DWord -Value $RegValue -Force
    Write-Output "$RegName is set to $RegValue"
} 
else 
{
    Set-ItemProperty -Path $RegPath -Name $RegName -Type DWord -Value $RegValue -Force
    Write-Output "$RegName is set to $RegValue"
    exit 0
}