# Repair and trigger M365 Apps Updates

Set startup type of M365 Apps "Click to Run Service" to Automatic and trigger updates on each check via resetting UpdateDetectionLastRunTime and start Office C2R Process.

Detect next Update on RegistryKey "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Updates\UpdatesReadyToApply" and run Update Process with User prompt.

Adapted from example script in Intune: "Restart stopped Office C2R svc".
