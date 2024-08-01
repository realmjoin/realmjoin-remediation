# PKfail Detection Script
# Reference: https://github.com/binarly-io/Vulnerability-REsearch/blob/main/PKfail/BRLY-2024-005.md

$ErrorActionPreference = "SilentlyContinue"

function Test-PKfailVulnerability {
    try {
        $pk = Get-SecureBootUEFI PK
        if ($pk) {
            $pkString = [System.Text.Encoding]::ASCII.GetString($pk.bytes)
            if ($pkString -match "DO NOT TRUST|DO NOT SHIP") {
                return $true
            }
        }
    } catch {
        Write-Host "Error checking SecureBoot UEFI PK: $_"
    }
    return $false
}

function Get-FirmwareVendor {
    try {
        $firmware = Get-WmiObject -Class Win32_BIOS
        return $firmware.Manufacturer
    } catch {
        Write-Host "Error getting firmware vendor: $_"
        return "Unknown"
    }
}

$isVulnerable = Test-PKfailVulnerability
$firmwareVendor = Get-FirmwareVendor

if ($isVulnerable) {
    Write-Host "Device is vulnerable to PKfail. Firmware Vendor: $firmwareVendor"
    exit 1  # Vulnerable, remediation needed
} else {
    Write-Host "Device is not vulnerable to PKfail. Firmware Vendor: $firmwareVendor"
    exit 0  # Not vulnerable, no remediation needed
}