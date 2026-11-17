# Disable optional system services

Disables the system services that the CIS Microsoft Intune for Windows 11 Benchmark v5.0.0 lists in
section 82 (the 20 Level 1 recommendations between 82.3 and 82.40): Computer Browser, IIS Admin
Service, Infrared monitor service, LxssManager (Windows Subsystem for Linux as a Windows feature), Microsoft FTP
Service, OpenSSH SSH Server, RPC Locator, Routing and Remote Access, Simple TCP/IP Services, Special
Administration Console Helper, SSDP Discovery, UPnP Device Host, Web Management Service, Windows
Media Player Network Sharing Service, Windows Mobile Hotspot Service, World Wide Web Publishing
Service and the four Xbox services.

- `Detect.ps1` lists every service of the list that is installed and not disabled, and exits with 1
  if it finds one.
- `Remediate.ps1` sets the startup type of those services to Disabled through the Service Control
  Manager. It does not stop a running service, but the service does not start again after the next
  restart. A service that is not installed is skipped. If a service cannot be set, the script lists
  it and exits with 1.

Run it on a schedule (daily) so that a service that a feature update, an app or a user turns back on
is disabled again. Removing the remediation does not re-enable the services.

Check the list against your devices before you assign it. For example, users may need the mobile
hotspot, the OpenSSH server or the Windows Subsystem for Linux.
