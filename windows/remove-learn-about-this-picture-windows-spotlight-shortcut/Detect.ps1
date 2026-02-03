#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Checks if the RegKey for hiding Windows spotlights "Learn about this picture" shortcut is present
# Changelog:           2026-01-23: Inital version
# References:          https://learn.microsoft.com/en-us/answers/questions/2157455/how-to-remove-a-persistent-shortcut-learn-about-th
# Notes:               ...
#
#=============================================================================================================================

$RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
$ValueName = "{2cc5ca98-6485-489a-920e-b3e88a6ccce3}"
$DesiredValue = 1

try {
    $CurrentValue = Get-ItemProperty -Path $RegPath -Name $ValueName -ErrorAction Stop | Select-Object -ExpandProperty $ValueName

    if ($CurrentValue -eq $DesiredValue) {
        Write-Output "Compliant."
        exit 0
    }
    else {
        Write-Output "Not matching desired value."
        exit 1
    }
}
catch {
    Write-Output "Not existing."
    exit 1
}
