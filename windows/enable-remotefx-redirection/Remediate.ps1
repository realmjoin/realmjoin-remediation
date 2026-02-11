#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Set required RemoteFX registry settings for redirecting 3D peripherals to Microsoft VDI (AVD, W365)
# Changes:             2026-02-11: Initial release.
# References:          ...
# Notes:               HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services\Client\fUsbRedirectionEnableMode = 2
#                      HKLM:\System\CurrentControlSet\Control\Class\{36fc9e60-c465-11cf-8056-444553540000}\UpperFilters = TsUsbFlt
#                      HKLM:\System\CurrentControlSet\Services\TsUsbFlt\BootFlags = 4
#                      HKLM:\System\CurrentControlSet\Services\usbhub\hubg\EnableDiagnosticMode = 0x80000000 (2147483648)
#
#=============================================================================================================================

# define Variables
$remediationSucceeded = $true
$terminalServicesClientPath = 'HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services\Client'
$usbClassPath = 'HKLM:\System\CurrentControlSet\Control\Class\{36fc9e60-c465-11cf-8056-444553540000}'
$tsUsbFltServicePath = 'HKLM:\System\CurrentControlSet\Services\TsUsbFlt'
$usbHubgServicePath = 'HKLM:\System\CurrentControlSet\Services\usbhub\hubg'

# 1) HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services\Client\fUsbRedirectionEnableMode = 2
Write-Host "Setting fUsbRedirectionEnableMode = 2"
try {
    if (-not (Test-Path $terminalServicesClientPath)) { New-Item -Path $terminalServicesClientPath -Force | Out-Null }
    New-ItemProperty -Path $terminalServicesClientPath -Name 'fUsbRedirectionEnableMode' -PropertyType DWord -Value 2 -Force | Out-Null
} catch {
    Write-Host "Failed to set fUsbRedirectionEnableMode."
    $remediationSucceeded = $false
}

# 2) HKLM:\System\CurrentControlSet\Control\Class\{36fc9e60-c465-11cf-8056-444553540000}\UpperFilters = TsUsbFlt
Write-Host "Setting UpperFilters = TsUsbFlt"
try {
    if (-not (Test-Path $usbClassPath)) { New-Item -Path $usbClassPath -Force | Out-Null }
    New-ItemProperty -Path $usbClassPath -Name 'UpperFilters' -PropertyType MultiString -Value @('TsUsbFlt') -Force | Out-Null
} catch {
    Write-Host "Failed to set UpperFilters."
    $remediationSucceeded = $false
}

# 3) HKLM:\System\CurrentControlSet\Services\TsUsbFlt\BootFlags = 4
Write-Host "Setting BootFlags = 4"
try {
    if (-not (Test-Path $tsUsbFltServicePath)) { New-Item -Path $tsUsbFltServicePath -Force | Out-Null }
    New-ItemProperty -Path $tsUsbFltServicePath -Name 'BootFlags' -PropertyType DWord -Value 4 -Force | Out-Null
} catch {
    Write-Host "Failed to set BootFlags."
    $remediationSucceeded = $false
}

# 4) HKLM:\System\CurrentControlSet\Services\usbhub\hubg\EnableDiagnosticMode = 0x80000000 (2147483648)
Write-Host "Setting EnableDiagnosticMode = 0x80000000 (2147483648)"
try {
    if (-not (Test-Path $usbHubgServicePath)) { New-Item -Path $usbHubgServicePath -Force | Out-Null }
    New-ItemProperty -Path $usbHubgServicePath -Name 'EnableDiagnosticMode' -PropertyType DWord -Value 2147483648 -Force | Out-Null
} catch {
    Write-Host "Failed to set EnableDiagnosticMode."
    $remediationSucceeded = $false
}

# Verification (exit 0 only when all values are correct)
if ($remediationSucceeded) {
    $usbRedirectionMode = Get-ItemPropertyValue -Path $terminalServicesClientPath -Name 'fUsbRedirectionEnableMode' -ErrorAction SilentlyContinue
    $upperFilters = (Get-ItemProperty -Path $usbClassPath -Name 'UpperFilters' -ErrorAction SilentlyContinue).UpperFilters
    $bootFlags = Get-ItemPropertyValue -Path $tsUsbFltServicePath -Name 'BootFlags' -ErrorAction SilentlyContinue
    $enableDiagnosticMode = Get-ItemPropertyValue -Path $usbHubgServicePath -Name 'EnableDiagnosticMode' -ErrorAction SilentlyContinue

    if ($usbRedirectionMode -ne 2) { $remediationSucceeded = $false }
    if (-not $upperFilters -or $upperFilters.Count -ne 1 -or $upperFilters[0] -ne 'TsUsbFlt') { $remediationSucceeded = $false }
    if ($bootFlags -ne 4) { $remediationSucceeded = $false }
    if ($enableDiagnosticMode -ne 2147483648) { $remediationSucceeded = $false }
}

if ($remediationSucceeded) {
    Write-Host "Remediation completed."
    exit 0
} else {
    Write-Host "Remediation failed."
    exit 1
}