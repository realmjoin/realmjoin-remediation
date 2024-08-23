# Check if Sense service is visible and install Defender sense client if not.

Searches for Sense service (required for Defender for Endpoint). If not found, Sense client gets installed via Add-WindowsCapability.

Windows 11 Home devices that have been upgraded to Enterprise/Pro might require this manual sense client installation before onboarding. Also, Windows 11 ARM-based devices can be affected (even with Pro version pre-installed). See: [Onboarding Copilot+ PCs to Intune with Defender for Endpoint](https://www.manage-everything.cloud/post/onboarding-copilot-pcs-to-intune-with-defender-for-endpoint)