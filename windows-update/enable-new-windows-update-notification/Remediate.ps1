#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Remediation Script which set the registry key for new Windows update notification if not set
# Changelog:           2025-22-01: initial version
# 
# 
#
#=============================================================================================================================

$Remediate = $true #True = Remediation Script | False = Detection/Discovery Script 

$RegPath = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
$RegName = 'RestartNotificationsAllowed2'
$RegValue = 1 # 1 = activated | 0 = not activated

#Check if the registry key exists and if the value is set to $value
$RegValueCheck = (Get-ItemProperty -Path $RegPath -Name $RegName -ErrorAction Ignore).$RegName

if ($RegValueCheck -eq $RegValue) 
{
    Write-Output "Update notification is activated"
    exit 0
} 
else 
{
    Write-Output "Update notification is not activated"
} 

#If Remediate is set to true, the script will try to remediate the issue
if ($Remediate -eq $true)
{
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
} 
else 
{
    exit 1 
}