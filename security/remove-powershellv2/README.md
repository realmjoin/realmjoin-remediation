# Disable PowerShell 2.0

Sets the correspoding Windows Features to remove it:
- Disable-WindowsOptionalFeature -Online -NoRestart -FeatureName MicrosoftWindowsPowerShellV2Root
