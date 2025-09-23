# Check if Sense service is visible and install Defender sense client if not.

Searches for Sense service (required for Defender for Endpoint). If not found, Sense client gets installed via Add-WindowsCapability.

The installation status can transition through several states before the service becomes available (a system reboot may be required):
- NotPresent
- InstallPending
- Staged

Windows 11 Home devices that have been upgraded to Enterprise/Pro might require this manual sense client installation before onboarding. Also, Windows 11 24H2 devices can be affected. Even on Pro version, the Defender sense client might be missing. So, onboarding the device to Defender portal is not possible and Intune will show "Not applicable" (or "Error" – depending on the deployment method) for the onboarding policy.

See [KB5043950](https://support.microsoft.com/en-us/topic/kb5043950-microsoft-defender-for-endpoint-known-issue-2fd719b6-8c26-469f-99fe-832eb1b702d7) and [Onboarding Copilot+ PCs and Win11 24H2 to Intune with Defender for Endpoint](https://www.manage-everything.cloud/post/onboarding-copilot-pcs-to-intune-with-defender-for-endpoint) for more details.