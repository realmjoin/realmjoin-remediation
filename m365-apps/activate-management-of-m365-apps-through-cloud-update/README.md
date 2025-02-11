# Activate the management of M365 Apps through cloud update

## Explanation

As soon as devices/users are onboarded to Cloud Update (managed via the M365 Apps Admin Center), they are locked to Cloud Update and ignore settings coming via other means (like Intune) by setting a registry key.
This remediation makes sure that devices are properly onboarded to Cloud Update by restoring the desired value of the registry key.

## Technical details

This remediation (re)activates the management through cloud update.
To reenable control the following reg key is set accordingly:

- Path: HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\cloud\office\16.0\Common\officeupdate
- Key: IgnoreGPO
- Value: 1

## Recommended assignment

Assign this remediation to your M365 Apps Update Channel Entra groups that are supported by Cloud Update as INCLUDE. Currently supported by Cloud Update are the Update Channels Current Channel and Monthly Enterprise Channel.

For TF-managed environments that means:

INCLUDE:

- CFG - M365 Apps - Channel - 3 (Current) - TF
- CFG - M365 Apps - Channel - 4 (MonthlyEnterprise) - TF

EXCLUDE:

- None - to avoid conflicts with the remediations that DEACTIVATES Cloud Update.

Make sure to set an appropiate filter, e.g. EXCLUDE: Win - DeviceType - MTR, Surface Hub, HoloLens, AVD Pooled - TF

## Recommended schedule

Hourly - Repeat every 4 hours.
