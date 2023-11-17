# Disable Windows Package Manager CLI

Disable Windows Package Manager Command Line Interfaces via settings this registry key (to prevent usage by end users):

path:   HKLM:\Software\Policies\Microsoft\Windows\AppInstaller\
key:    EnableWindowsPackageManagerCommandLineInterfaces
value:  0

see: [Policy CSP - DesktopAppInstaller](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-desktopappinstaller#enablewindowspackagemanagercommandlineinterfaces)