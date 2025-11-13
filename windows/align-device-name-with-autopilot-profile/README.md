# Align device name with Autopilot profile

Checks if current hostname matches with device name template defined via Autopilot profile:
- checks for template via registry:
    - path: `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Provisioning\Diagnostics\AutoPilot`
    - value of: `CloudAssignedDeviceName`
- variable `%SERIAL%` must be present in template
- handles special cases:
    - no serial number available (throw error)
    - device name exceeds 15 characters (SN will be cut off from the left)
    - serial number contains hyphens (will be removed)