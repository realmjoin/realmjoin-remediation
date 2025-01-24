# Repair and trigger M365 Apps Updates

Check if startup type of M365 Apps "Click to Run Service" is set to Automatic and repair if needed.

Trigger updates on **each detection run**:
- reset "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Updates\UpdateDetectionLastRunTime" and start Office C2R process to **search for updates without user prompt**
- detect **outstanding update installation** via "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Updates\UpdatesReadyToApply" and start update process **with user prompt**

Enhanced version of example script in Intune: "Restart stopped Office C2R svc".