#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detect if HideFileExt is configured as desired.
# Changelog:           2025-05-13: Inital version
#
#=============================================================================================================================

# define Variables
$path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\"
$name = "HideFileExt"
$value = 0

# get status
$currentValue = (Get-ItemPropertyValue -Path $path -Name $name -ErrorAction SilentlyContinue)
if($currentValue -eq $value) {
    Write-Host "HideFileExt configured as desired."
    exit 0
} else {
    Write-Host "HideFileExt not configured as desired."
    exit 1
}