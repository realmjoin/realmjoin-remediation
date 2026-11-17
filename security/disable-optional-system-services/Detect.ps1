#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Lists the optional system services of CIS Microsoft Intune for Windows 11 Benchmark v5.0.0,
#                      section 82 (Level 1), that are installed and not disabled.
# Changelog:           2026-11-17: Initial version.
# References:          CIS Microsoft Intune for Windows 11 Benchmark v5.0.0, the 20 Level 1 recommendations of section 82
# Notes:               Exits with 1 if at least one listed service is installed and its startup type is not
#                      Disabled, or cannot be read, so that Intune runs Remediate.ps1. A name that the Service
#                      Control Manager does not list as a service name counts as compliant.
#                      Keep the service list equal to Remediate.ps1.
#
#=============================================================================================================================

$ErrorActionPreference = 'Stop'

# Service names (not display names) of CIS 82.x Level 1
$serviceNames = @(
    'Browser'        # Computer Browser
    'IISADMIN'       # IIS Admin Service
    'irmon'          # Infrared monitor service
    'LxssManager'    # LxssManager (Windows Subsystem for Linux, Windows feature)
    'FTPSVC'         # Microsoft FTP Service
    'sshd'           # OpenSSH SSH Server
    'RpcLocator'     # Remote Procedure Call (RPC) Locator
    'RemoteAccess'   # Routing and Remote Access
    'simptcp'        # Simple TCP/IP Services
    'sacsvr'         # Special Administration Console Helper
    'SSDPSRV'        # SSDP Discovery
    'upnphost'       # UPnP Device Host
    'WMSvc'          # Web Management Service
    'WMPNetworkSvc'  # Windows Media Player Network Sharing Service
    'icssvc'         # Windows Mobile Hotspot Service
    'W3SVC'          # World Wide Web Publishing Service
    'XboxGipSvc'     # Xbox Accessory Management Service
    'XblAuthManager' # Xbox Live Auth Manager
    'XblGameSave'    # Xbox Live Game Save
    'XboxNetApiSvc'  # Xbox Live Networking Service
)

# Looked up by exact service name in the list of services: Get-Service -Name tries the name as a
# display name first, so 'Browser' resolves to the driver 'bowser' (display name "Browser"). The
# list without -Name contains services only, no drivers.
$installedServices = @(Get-Service -ErrorAction SilentlyContinue)

$notDisabled = [System.Collections.Generic.List[string]]::new()
foreach ($name in $serviceNames) {
    $service = $installedServices | Where-Object Name -eq $name | Select-Object -First 1
    if ($null -eq $service) {
        continue
    }
    # A start type that cannot be read comes back as $null and counts as not disabled.
    $startType = $service.StartType
    if ($startType -ne [System.ServiceProcess.ServiceStartMode]::Disabled) {
        $notDisabled.Add("$($name) ($startType)")
    }
}

if ($notDisabled.Count -gt 0) {
    Write-Output "Not disabled: $($notDisabled -join ', ')"
    exit 1
}
Write-Output "All listed services are disabled or not installed"
exit 0
