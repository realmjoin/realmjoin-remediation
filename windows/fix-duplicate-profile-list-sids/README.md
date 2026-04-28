# Fix Duplicate ProfileList SIDs

## Problem solved

Windows Reset, in-place upgrade, and feature updates fail with `MIG: Duplicate profile detected for S-1-...` when `HKLM\...\ProfileList` contains multiple registry keys for the same user SID (e.g. a plain key plus a `.bak` sibling). SetupPlatform's MIG gather phase aborts, and the operation rolls back.

## What the package does

The **detection script** scans `ProfileList` for duplicate SID groups across local, AD, and Entra ID accounts (`S-1-5-21-*` and `S-1-12-1-*`). For each group it reports the profile path, folder existence, `NTUSER.DAT` timestamp, and decoded `State` bitmask, then applies a deterministic resolver that classifies the situation with a confidence level (`High` / `Medium` / `Low` / `None`).

The **remediation script** acts only on **High-confidence** cases, where the winning entry is unambiguous from registry structure alone:

- Same-path `plain + .bak` → keep the plain key
- Only one sibling carries a `State` value → keep that one
- Only one sibling's `ProfileImagePath` folder exists → keep that one

All other cases (`Medium`, `Low`, `None`, loaded user hives, FSLogix-managed devices) are refused and stay flagged for human review.

## Safety

- Every affected key is exported to `.reg` in `C:\ProgramData\glueckkanja\Remediations\fix-duplicate-profile-list-sids\backup-<timestamp>\` before any delete
- Full `Start-Transcript` per run at `C:\Windows\Logs\glueckkanja\Remediations\fix-duplicate-profile-list-sids\transcripts\remediation-<timestamp>.log` (last 10 retained)
- Concise structured operational log at `C:\Windows\Logs\glueckkanja\Remediations\fix-duplicate-profile-list-sids\activity.log` (rotates at 1 MB, single backup)
- Application event log entries (source `glueckkanja.ProfileListRepair`; ID `1000` on repair, `2000` on refusal, `4000` on error)
- Refusal exits non-zero so Intune keeps the device flagged for triage

## Out of scope

Different-path duplicates requiring rename operations, mtime-based heuristics, and anything on FSLogix-backed devices (AVD). These require manual repair.
