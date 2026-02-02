#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Checks if the RegKey for hiding Windows spotlights "Learn about this picture" shortcut is present
# Changelog:           2026-01-23 v1 created
# References:          ...
# Notes:               ...
#
#=============================================================================================================================

$RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
$ValueName = "{2cc5ca98-6485-489a-920e-b3e88a6ccce3}"
$DesiredValue = 1

try {
    $CurrentValue = Get-ItemProperty -Path $RegPath -Name $ValueName -ErrorAction Stop |
        Select-Object -ExpandProperty $ValueName

    if ($CurrentValue -eq $DesiredValue) {
        Write-Output "Compliant: Registry value exists and is set to $DesiredValue"
        exit 0
    }
    else {
        Write-Output "Non-compliant: Registry value exists but is not set to $DesiredValue"
        exit 1
    }
}
catch {
    Write-Output "Non-compliant: Registry path or value does not exist"
    exit 1
}
