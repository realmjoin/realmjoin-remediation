# PAR - Detect Unauthorized Local Admins

## Description
Validates local administrator accounts against RealmJoin LAPS and Windows LAPS policies. Detects unauthorized admin accounts.

## Technical Details

**Detection Logic:**
1. Reads RealmJoin LAPS config
2. Checks Windows LAPS registry (`HKLM:\Software\Microsoft\Policies\LAPS`)
3. Validates accounts via pattern matching, FullName format, and description markers
4. Detects duplicates: oldest account (by PasswordLastSet) = legitimate, others = manipulated

**Exit Codes:**
- `0` - All checks passed (or no user logged in, checks skipped) - **Without issues** in Device stats
- `1` - Issues detected (unauthorized admins, manipulation, or built-in admin enabled without LAPS) - **With issues** in Device stats

## Output Reference

| Field | Type | Description |
|-------|------|-------------|
| `BuiltInAdminEnabled` | Boolean | Built-in Administrator account enabled |
| `WindowsLapsBuiltInManaged` | Boolean | Windows LAPS manages built-in admin |
| `WindowsLapsCustomAccount` | String | Custom account name/pattern managed by Windows LAPS |
| `RJPolicyTaskExitCode` | Integer | Scheduled task exit code (0=success, 42=user error, 43=task error, 44=timeout, 45=RealmJoin not installed) |
| `RJPolicyReadError` | Boolean | Error reading RealmJoin policy |
| `RJPolicyResult` | Boolean | Realmjoin SetCurrentUserAdministrator policy value |
| `RJLapsConfigured` | Boolean | RealmJoin LAPS is configured |
| `ManipulationDetected` | Boolean | Duplicate accounts with same name syntax detected |
| `ManipulatedAccounts` | Array | List of duplicate accounts matching LAPS pattern (newer accounts by PasswordLastSet) |
| `AllAdmins` | Array | All members of local Administrators group |
| `AllowedAdmins` | Array | Validated legitimate admin accounts |
| `UnauthorizedAdmins` | Array | Accounts marked for removal |

**Example Output:**
```
BuiltInAdminEnabled=True | WindowsLapsBuiltInManaged=True | WindowsLapsCustomAccount= | RJPolicyTaskExitCode=0 | RJPolicyReadError=False | RJPolicyResult=true | RJLapsConfigured=True | ManipulationDetected=False | AllAdmins=[ADM-ABCD1234, ADM-1234ABCD] | AllowedAdmins=[ADM-ABCD1234, ADM-1234ABCD] | UnauthorizedAdmins=[CustomAdmin]
```

**Important Note:**

If `UnauthorizedAdmins` are detected but `RJPolicyTaskExitCode` shows an error (42=user error, 43=task error, 44=timeout), validation is incomplete. The RealmJoin policy check failed, preventing verification of the active LAPS configuration or `SetCurrentUserAdministrator` setting. Results may contain false positives in this scenario.

