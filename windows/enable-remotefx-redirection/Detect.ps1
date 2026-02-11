#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detect required RemoteFX registry settings for redirecting 3D peripherals to Microsoft VDI (AVD, W365)
# Changes:             2026-02-11: Initial release.
# References:          ...
# Notes:               HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services\Client\fUsbRedirectionEnableMode = 2
#                      HKLM:\System\CurrentControlSet\Control\Class\{36fc9e60-c465-11cf-8056-444553540000}\UpperFilters = TsUsbFlt
#                      HKLM:\System\CurrentControlSet\Services\TsUsbFlt\BootFlags = 4
#                      HKLM:\System\CurrentControlSet\Services\usbhub\hubg\EnableDiagnosticMode = 0x80000000 (2147483648)
#
#=============================================================================================================================


# define Variables
$remediate = $false
$terminalServicesClientPath = 'HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services\Client'
$usbClassPath = 'HKLM:\System\CurrentControlSet\Control\Class\{36fc9e60-c465-11cf-8056-444553540000}'
$tsUsbFltServicePath = 'HKLM:\System\CurrentControlSet\Services\TsUsbFlt'
$usbHubgServicePath = 'HKLM:\System\CurrentControlSet\Services\usbhub\hubg'

# 1) HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services\Client\fUsbRedirectionEnableMode = 2
$usbRedirectionMode = Get-ItemPropertyValue -Path $terminalServicesClientPath -Name 'fUsbRedirectionEnableMode' -ErrorAction SilentlyContinue
if ($usbRedirectionMode -ne 2) {
    Write-Host "Remediate: fUsbRedirectionEnableMode is missing or not 2."
    $remediate = $true
}

# 2) HKLM:\System\CurrentControlSet\Control\Class\{36fc9e60-c465-11cf-8056-444553540000}\UpperFilters = TsUsbFlt
$upperFilters = (Get-ItemProperty -Path $usbClassPath -Name 'UpperFilters' -ErrorAction SilentlyContinue).UpperFilters
if (-not $upperFilters -or $upperFilters.Count -ne 1 -or $upperFilters[0] -ne 'TsUsbFlt') {
    Write-Host "Remediate: UpperFilters is missing or not TsUsbFlt."
    $remediate = $true
}

# 3) HKLM:\System\CurrentControlSet\Services\TsUsbFlt\BootFlags = 4
$bootFlags = Get-ItemPropertyValue -Path $tsUsbFltServicePath -Name 'BootFlags' -ErrorAction SilentlyContinue
if ($bootFlags -ne 4) {
    Write-Host "Remediate: BootFlags is missing or not 4."
    $remediate = $true
}

# 4) HKLM:\System\CurrentControlSet\Services\usbhub\hubg\EnableDiagnosticMode = 0x80000000 (2147483648)
$enableDiagnosticMode = Get-ItemPropertyValue -Path $usbHubgServicePath -Name 'EnableDiagnosticMode' -ErrorAction SilentlyContinue
if ($enableDiagnosticMode -ne 2147483648) {
    Write-Host "Remediate: EnableDiagnosticMode is missing or not 0x80000000 (2147483648)."
    $remediate = $true
}

if ($remediate) {
    Write-Host "Remediation required!"
    exit 1
} else {
    Write-Host "No remediation required!"
    exit 0
}