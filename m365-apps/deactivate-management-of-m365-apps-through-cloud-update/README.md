# Deactivate the management of M365 Apps through cloud update

## Explanation

Cloud Update (managed via the M365 Apps Admin Center) only supports Current Channel and Monthly Enterprise Channel.
As soon as devices/users are onboarded to Cloud Update, they are locked and can't be moved to another channel as Cloud Update overwrites and ingores any policy/channel set via Intune or other means.

To be able to move users/devices to another channel, they must be offboarded from cloud update. This remediation deactivates the management through cloud update by making sure the registry key IgnoreGPO has a value of zero.

## Technical details

This remediation deactivates the management through cloud update.
To regain control the following reg key is set accordingly:

- Path: HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\cloud\office\16.0\Common\officeupdate
- Key: IgnoreGPO
- Value: 0

## Recommended assignment

Assign this remediation to all your M365 Apps Update Channel entra groups as INCLUDE and also assign it as EXCLUDE to the M365 Apps Update Channel entra groups for Current Channel and Monthly Enterprise Channel.

For TF-managed environments that means:

INCLUDE:

- CFG - M365 Apps - Channel - 0 (Choose your own) - TF
- CFG - M365 Apps - Channel - 1 (Beta) - TF
- CFG - M365 Apps - Channel - 2 (CurrentPreview) - TF
- CFG - M365 Apps - Channel - 5 (SemiAnnualPreview) - TF
- CFG - M365 Apps - Channel - 6 (SemiAnnual) - TF

EXCLUDE:

- CFG - M365 Apps - Channel - 3 (Current) - TF
- CFG - M365 Apps - Channel - 4 (MonthlyEnterprise) - TF

Make sure to set an appropiate filter, e.g. EXCLUDE: Win - DeviceType - MTR, Surface Hub, HoloLens, AVD Pooled - TF

## Recommended schedule

Hourly - Repeat every 4 hours.
