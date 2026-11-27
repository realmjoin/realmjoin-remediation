# Detect Hotpatch bug KB5132043

Detect devices affected by the November 2026 hotpatch issue. Microsoft confirmed that the hotpatch KB5132043 can cause app installation, launch and update failures (error `ERROR_ALLOTTED_SPACE_EXCEEDED` / `0xC0000099`) on Windows 11 24H2, 25H2 and 26H2. Applications that load the 32-bit Windows Installer DLL (`msi.dll`) are affected.

Observed symptoms on affected devices: installers (including .NET updates) fail, and the `Hotpatch-Loader` event 153 is logged repeatedly in the Application log.

A device is reported as **affected** only if all of the following apply:

1. Windows 11 build 261xx, 262xx or 263xx (24H2, 25H2, 26H2)
2. UBR below 9974 (build of the standard November update KB5132061)
3. KB5132043 is installed
4. Event 153 (provider `Hotpatch-Loader`) with `0xC0000099` within the last 30 days (also matched as decimal `-1073741671` / `3221225625`)

**Output:** `AFFECTED | User=<UPN> | Build=<build.ubr> | KB5132043=yes | Event153=<timestamp>` or the reason why the device is not affected.

The reported user is the last logged-on user (UPN, fallback: `LastLoggedOnUser`). It can differ from the primary user of the device. Please check the data protection requirements before assigning, as the output contains a user name.

**Notes**
- Detect only, nothing is changed on the device.
- The standard (non-hotpatch) update KB5132061 resolved the issue on a test device. A restart is required before the build changes.
- Adjust `$minHealthyUbr` in `Detect.ps1` if the fix is delivered with a later build.
- The criteria were derived from a single affected device and have not been verified on every device.

References:
- https://www.bleepingcomputer.com/news/microsoft/microsoft-confirms-app-installation-launch-issues-after-hotpatch/
- https://support.microsoft.com/help/5132061