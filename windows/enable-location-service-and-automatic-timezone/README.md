# Enable Windows Location Service with end-user control & Automatic Time Zone Feature

Enables Windows Location Service globally while still allowing the user to allow/deny location access for individual apps. In addition, enables the Automatic Time Zone Service which requires the Windows Location Service to work.

## Deployment

| | |
|---|---|
| Assignment | **Users** (not devices) |
| Run as | SYSTEM |
| PowerShell host | 64-bit |

User assignment is required: the scripts resolve the logged-on user's SID via `WTSQueryUserToken` and write per-user ConsentStore (HKU) and CAM database entries. Under Device assignment, no interactive user can be resolved and both scripts exit 0.

## Prerequisites

SQLite is needed to read/write the CAM database. The scripts pick whichever is available:

1. **Default** — the built-in `winsqlite3.dll`.
2. **Alternative** — `sqlite3.exe` at `%ProgramData%\sqlite-tools\sqlite3.exe`. Deploy it as a Win32 app alongside this remediation. If present, remediation will switch to sqlite3.exe automatically.

## Scope of changes

- **Registry:** `AllowLocation` CSP removed; `DisableLocation` → `0`; ConsentStore `Value`/`LastSetTime` set in HKLM + HKU; OOBE `PrivacyConsentStatus` → `1`.
- **CAM database:** `UserGlobal` row `('location', <sid>)` → `Value = 1`.
- **Services:** `lfsvc` and `tzautoupdate` set to `Manual` + Running; `camsvc` stopped during CAM DB write and started again after.
- **Master switch:** `SystemSettingsAdminFlows.exe SetCamSystemGlobal location 1` invoked when drift exists.

## On-disk trail

- **Activity log** (both scripts) — `C:\Windows\Logs\glueckkanja\Remediations\enable-location-service-and-automatic-timezone\activity.log`. Concise, structured, rotates at 1 MB with a single backup.
- **Forensic transcript** (remediate only) — `C:\Windows\Logs\glueckkanja\Remediations\enable-location-service-and-automatic-timezone\transcripts\remediation-<stamp>.log`. Verbose `Start-Transcript` per run, last 10 retained. Only produced when the run gets past the no-user guard and the readiness check — the runs that actually do work.

## Exit codes

- `detect.ps1` — `0` compliant or no user; `1` drift detected or detection failed.
- `remediate.ps1` — `0` success (with or without drift correction) or no user; `1` failure.

## Output

Detect emits a per-check list when drift is found:

```
Drift detected. Remediation required:
 - HKLM ConsentStore Value is 'Deny' (expected 'Allow').
 - CAM DB UserGlobal('location', 'S-1-5-21-...') is '' (expected 1).
```

Remediate emits one of:

- `Remediation successful: drift corrected.`
- `Remediation successful: no drift detected.`
- `No interactive console user detected. Skipping remediation; Intune will retry on the next cycle.`
- `Remediation failed: <reason>.`
