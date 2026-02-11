# Enable RemoteFX redirection for 3D peripherals

This remediation package enables the required registry settings to allow RemoteFX USB redirection for 3D peripheral devices in Microsoft VDI environments (AVD, Windows 365).

The following values are validated and set:

- `HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services\Client`
	- `fUsbRedirectionEnableMode` (DWORD) = `2`
- `HKLM:\System\CurrentControlSet\Control\Class\{36fc9e60-c465-11cf-8056-444553540000}`
	- `UpperFilters` (Multi-String) = `TsUsbFlt`
- `HKLM:\System\CurrentControlSet\Services\TsUsbFlt`
	- `BootFlags` (DWORD) = `4`
- `HKLM:\System\CurrentControlSet\Services\usbhub\hubg`
	- `EnableDiagnosticMode` (DWORD) = `0x80000000` (`2147483648`)

The detect script reports remediation required if any value is missing or differs. The remediate script sets the values and then verifies success.