#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detection Script which checks the registry key for Windows update notification
# Changelog:           2025-22-01: initial version
#                      2025-01-24: clean-up
# 
#
#=============================================================================================================================

$RegPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
$RegName = "RestartNotificationsAllowed2"
$RegValue = 1                               # 1 = activated | 0 = not activated

# check if the registry key exists and if the value is set to $value
$RegValueCheck = (Get-ItemProperty -Path $RegPath -Name $RegName -ErrorAction Ignore).$RegName

if ($RegValueCheck -eq $RegValue) 
{
    Write-Output "Update restart notification is activated"
    exit 0
} 
else 
{
    Write-Output "Update restart notification is not activated"
    exit 1
} 