# Disable Windows Package Manager CLI

Enable Windows Package Manager Command Line Interfaces via deleting this registry key (to allow usage by end users):

path:   HKLM:\Software\Policies\Microsoft\Windows\AppInstaller\
key:    EnableWindowsPackageManagerCommandLineInterfaces
value:  0

see: [Policy CSP - DesktopAppInstaller](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-desktopappinstaller#enablewindowspackagemanagercommandlineinterfaces)