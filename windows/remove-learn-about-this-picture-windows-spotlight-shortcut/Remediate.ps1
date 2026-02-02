#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Creates Reg key for hiding Windows spotlights "Learn about this picture" shortcut
# Changelog:           2026-01-23 v1 created
# References:          ...
# Notes:               ...
#
#=============================================================================================================================

$RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
$ValueName = "{2cc5ca98-6485-489a-920e-b3e88a6ccce3}"
$DesiredValue = 1


try {

  # Ensure the registry path exists
  if (-not (Test-Path $RegPath)) {
    New-Item -Path $RegPath -Force | Out-Null
  }
  
  # Create or update the registry value
  New-ItemProperty -Path $RegPath -Name $ValueName -PropertyType DWord -Value $DesiredValue -Force | Out-Null

  exit 0
} catch {
  # error occured
  $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}