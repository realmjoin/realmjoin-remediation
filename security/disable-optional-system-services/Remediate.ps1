#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Disables the optional system services of CIS Microsoft Intune for Windows 11 Benchmark v5.0.0,
#                      section 82 (Level 1).
# Changelog:           2026-11-17: Initial version.
# References:          CIS Microsoft Intune for Windows 11 Benchmark v5.0.0, the 20 Level 1 recommendations of section 82
# Notes:               Sets the startup type of each listed service to Disabled through the Service Control Manager.
#                      A name that the Service Control Manager does not list as a service name is skipped. A
#                      running service is not stopped; it does not start again after the next restart.
#                      Exits with 1 if at least one installed service could not be set.
#                      Keep the service list equal to Detect.ps1.
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

$failed = [System.Collections.Generic.List[string]]::new()

# Looked up by exact service name in the list of services, and set through that object:
# Get-Service -Name tries the name as a display name first, so 'Browser' resolves to the
# driver 'bowser' (display name "Browser"), whether or not the Computer Browser service is
# installed. The list without -Name contains services only, no drivers, and Set-Service
# opens the piped service by its service name.
$installedServices = @(Get-Service -ErrorAction SilentlyContinue)

foreach ($name in $serviceNames) {
    $service = $installedServices | Where-Object Name -eq $name | Select-Object -First 1
    if ($null -eq $service) {
        continue
    }
    try {
        $startType = $service.StartType
        if ($startType -eq [System.ServiceProcess.ServiceStartMode]::Disabled) {
            continue
        }
        $service | Set-Service -StartupType Disabled
        Write-Output "$($name): disabled (was $startType)"
    }
    catch {
        Write-Output "$($name): FAILED - $($_.Exception.Message)"
        $failed.Add($name)
    }
}

if ($failed.Count -gt 0) {
    Write-Output "Could not disable: $($failed -join ', ')"
    exit 1
}
exit 0
