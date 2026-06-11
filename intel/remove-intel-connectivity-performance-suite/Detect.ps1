#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detects Intel Connectivity Performance Suite components:
#                      AppxPackage, ICPS PnP drivers and Intel Network Connectivity Service.
# Changelog:           2025-06-10: Initial release.
#                      2026-06-11: Just report ICPS PnP Drivers.
# References:          https://www.intel.com/content/www/us/en/support/articles/000093451/wireless/wireless-software.html
#
#=============================================================================================================================

$ErrorActionPreference = 'SilentlyContinue'

# check for Intel system
if (!((Get-CimInstance Win32_Processor).Name -like '*Intel*')) { 
    Write-Host "No Intel system."
    #exit 0
}

$nonCompliant = $false

# Tracking variables for one-liner summary
$foundAppx     = $false
$foundProvAppx = $false
$foundDrivers  = [System.Collections.Generic.List[string]]::new()
$foundService  = $null

# ── 1. AppxPackage ────────────────────────────────────────────
# PackageName
$icpsName = 'AppUp.IntelConnectivityPerformanceSuite'

# Check all-user installations
$icpsAppx = Get-AppxPackage -AllUsers -PackageTypeFilter Main `
    | Where-Object { $_.Name -eq $icpsName   } `
    | Select-Object -First 1

if ($icpsAppx) {
    $nonCompliant = $true
    $foundAppx    = $true
}

# Also check provisioned (pre-staged for new user profiles)
$icpsProvision = Get-AppxProvisionedPackage -Online `
    | Where-Object { $_.DisplayName -eq $icpsName } `
    | Select-Object -First 1

if ($icpsProvision) {
    $nonCompliant  = $true
    $foundProvAppx = $true
}

# ── 2. PnP Drivers (icpsExtension / icpsComponent) ──────────────────────────
try {
    $pnpOutput    = & pnputil /enum-drivers 2>&1
    $driverBlocks = ($pnpOutput -join "`n") -split '(?=Published Name\s*:)'

    foreach ($block in $driverBlocks) {
        if ($block -match 'Original Name\s*:\s*(icpsExtension|icpsComponent)') {
            $pubName = if ($block -match 'Published Name\s*:\s*(oem\d+\.inf)') { $Matches[1] } else { 'unknown' }
            # $nonCompliant = $true     # drivers are not triggering remediation as Windows Update installs them again
            $foundDrivers.Add($pubName)
        }
    }
}
catch {
    Write-Host "WARNING: Could not enumerate PnP drivers - $_"
}

# ── 3. Intel Network Connectivity Service ───────────────────────────────────
$serviceNames = @('IntelNCS', 'IntelNCS2', 'Intel Network Connectivity Service', 'Intel Connectivity Network Service')

foreach ($svcName in $serviceNames) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc) {
        $nonCompliant = $true
        $foundService = $svc.DisplayName
        break
    }
}

# ── Result ───────────────────────────────────────────────────────────────────
if ($nonCompliant) {
    # Detailed output
    if ($foundAppx)                { Write-Host "  - AppxPackage found: $($icpsAppx.PackageFullName)" }
    if ($foundProvAppx)            { Write-Host "  - Provisioned AppxPackage found: $($icpsProvision.PackageName)" }
    foreach ($drv in $foundDrivers){ Write-Host "  - ICPS driver found: $drv" }
    if ($foundService)             { Write-Host "  - Service found: '$foundService' [Status: $($svc.Status)]" }

    # one-liner output
    $parts = [System.Collections.Generic.List[string]]::new()
    if ($foundAppx)                  { $parts.Add('Appx') }
    if ($foundProvAppx)              { $parts.Add('Prov. Appx') }
    if ($foundDrivers.Count -gt 0)   { $parts.Add("$($foundDrivers.Count) driver$(if ($foundDrivers.Count -ne 1) {'s'})") }
    if ($foundService)               { $parts.Add('Service') }
    Write-Host "ICPS components found: $($parts -join ', ')"
    exit 1
} else {
    Write-Host "No ICPS components found."
    exit 0
}