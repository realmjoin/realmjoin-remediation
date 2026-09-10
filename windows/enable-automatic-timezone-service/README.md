# Enable Automatic Time Zone Service

Sets the startup type of the Automatic Time Zone Updater service (`tzautoupdate`) to **Automatic**, which corresponds to the Windows setting "Set time zone automatically".

This is a stripped-down variant of [Enable Windows Location Service with end-user control & Automatic Time Zone Feature](../enable-location-service-and-automatic-timezone). That remediation also enables the Location Service and hands the location consent to the end user. Use this script instead for tenants where the Location Service is already enforced via policy (e.g. `AllowLocation` / `DisableLocation`) and only the time zone part is missing - the service startup type cannot be set via policy.

service:        tzautoupdate
startup type:   Automatic

Detection reports drift when the startup type is anything other than Automatic (e.g. Disabled after a user switched "Set time zone automatically" off). The running state is not checked, `tzautoupdate` is a trigger-start service that stops itself after adjusting the time zone.

Remediation sets the startup type, verifies it and then starts the service once on a best-effort basis so the time zone is adjusted without waiting for the next reboot. A failed start is not treated as a remediation failure.

Note: The Location Service must be allowed on the device, otherwise `tzautoupdate` cannot determine the time zone even with the correct startup type.

## Deployment

| | |
|---|---|
| Assignment | Devices |
| Run as | SYSTEM |
| PowerShell host | 64-bit |

## Exit codes

- `Detect.ps1` - `0` startup type is Automatic; `1` drift detected or detection failed.
- `Remediate.ps1` - `0` startup type set (or already set); `1` failure.
