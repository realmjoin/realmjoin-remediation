# Prefer IPv4 over IPv6

Changes the prefix policy table so that IPv4 is preferred over IPv6, without disabling IPv6 itself. Useful when dual-stack clients run into slow or failing name resolution / connections because IPv6 is tried first.

path:   HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\
key:    DisabledComponents
value:  32 (0x20)

Note: IPv6 stays enabled on all interfaces, only the preference order changes. A reboot is required for the setting to take effect.

Do not use the value 0xFF / 255 here - that disables IPv6 components entirely and is not supported by Microsoft.

see: [Guidance for configuring IPv6 in Windows](https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/configure-ipv6-in-windows)
