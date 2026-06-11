#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Removes Intel Connectivity Performance Suite components:
#                      AppxPackage and Intel Network Connectivity Service.
# Changelog:           2026-06-10: Initial release.
#                      2026-06-11: Disabled removal of ICPS PnP Drivers as Windows Update installs them again
# References:          https://www.intel.com/content/www/us/en/support/articles/000093451/wireless/wireless-software.html
#
#=============================================================================================================================

try {

    # ── 1. Stop & Remove Intel Network Connectivity Service ────────────────────────────────────────────
    $serviceNames = @('IntelNCS', 'IntelNCS2', 'Intel Network Connectivity Service', 'Intel Connectivity Network Service')

    foreach ($svcName in $serviceNames) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if (-not $svc) {
            Write-Host "Service '$svcName' not found - skipping."
            continue
        }

        Write-Host "Stopping service '$svcName' (current status: $($svc.Status))..."
        if ($svc.Status -ne 'Stopped') {
            Stop-Service -Name $svcName -Force -ErrorAction Stop
            Start-Sleep -Seconds 5
        }

        Write-Host "Disabling service '$svcName'..."
        Set-Service -Name $svcName -StartupType Disabled -ErrorAction SilentlyContinue

        Write-Host "Deleting service '$svcName' via sc.exe..."
        $result = & sc.exe delete $svcName 2>&1
        Write-Host "sc.exe result: $result"
    }

    # ── 2. Remove ICPS PnP Drivers (icpsExtension / icpsComponent) ────────────────────────────────────────────
    # Removal not done as drivers are installed via Windows Update again
    #Write-Host "Enumerating installed PnP drivers..."
    #$pnpRaw = & pnputil /enum-drivers 2>&1

    #$drivers = [System.Collections.Generic.List[hashtable]]::new()
    #$current = $null

    #foreach ($line in $pnpRaw) {
    #    if ($line -match '^Published Name\s*:\s*(.+)$') {
    #        if ($current) { $drivers.Add($current) }
    #        $current = @{ PublishedName = $Matches[1].Trim(); OriginalName = '' }
    #    }
    #    elseif ($line -match '^Original Name\s*:\s*(.+)$' -and $current) {
    #        $current['OriginalName'] = $Matches[1].Trim()
    #    }
    #}
    #if ($current) { $drivers.Add($current) }

    #Write-Host "Total drivers enumerated: $($drivers.Count)"

    #$icpsDrivers = $drivers | Where-Object { $_.OriginalName -match 'icpsExtension|icpsComponent' }

    #if (-not $icpsDrivers) {
    #    Write-Host "No ICPS drivers found - nothing to remove."
    #} else {
    #    foreach ($drv in $icpsDrivers) {
    #        Write-Host "Removing driver: $($drv.PublishedName) (original: $($drv.OriginalName))"
    #        $result = & pnputil /delete-driver $drv.PublishedName /uninstall 2>&1
    #        Write-Host "pnputil result: $($result -join ' | ')"
    #    }
    #}

    # ── 3. Remove Intel Connectivity Performance Suite AppxPackage ────────────────────────────────────────────
    $icpsName = 'AppUp.IntelConnectivityPerformanceSuite'

    # ── 3a. Remove per-user installations (all accounts on this device) ────────────────────────────────────────────
    $packages = Get-AppxPackage -AllUsers -PackageTypeFilter Main |
        Where-Object { $_.Name -eq $icpsName }

    if ($packages) {
        foreach ($pkg in $packages) {
            Write-Host "Removing AppxPackage: $($pkg.PackageFullName)"
            try {
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                Write-Host "Removed: $($pkg.PackageFullName)"
            }
            catch {
                # If -AllUsers throws (e.g. older OS build), fall back to per-SID removal
                Write-Host "AllUsers removal failed, trying per-user fallback: $_"
                foreach ($userInfo in $pkg.PackageUserInformation) {
                    try {
                        Remove-AppxPackage -Package $pkg.PackageFullName `
                            -User $userInfo.UserSecurityId -ErrorAction Stop
                        Write-Host "Removed for SID $($userInfo.UserSecurityId)"
                    }
                    catch {
                        Write-Host "Could not remove for SID $($userInfo.UserSecurityId): $_"
                    }
                }
            }
        }
    } else {
        Write-Host "No AppxPackage with PFN '$icpsName' found for any user - skipping per-user removal."
    }

    # ── 3b. Deprovision - remove from the offline image / new-user staging ────────────────────────────────────────────
    $provisioned = Get-AppxProvisionedPackage -Online |
        Where-Object { $_.DisplayName -eq $icpsName }

    if ($provisioned) {
        foreach ($prov in $provisioned) {
            Write-Host "Deprovisioning: $($prov.PackageName)"
            Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction Stop
            Write-Host "Deprovisioned: $($prov.PackageName)"
        }
    } else {
        Write-Host "No provisioned package found for '$icpsName' - skipping deprovision."
    }

    Write-Host "Finished."
    exit 0

} catch {
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}