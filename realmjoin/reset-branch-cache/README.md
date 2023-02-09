# Detect if Branch Cache needs to be cleared

Checks if MaxCacheSizeAsNumberOfBytes is abobe 85%. If yes, Clear-BCCache -Force is triggered.

## Settings

- Name: Detect and Remediate - Branch Cache - V1
- Run this script using the logged-on credentials: no
- Enforce script signature check: No
- Run script in 64-bit PowerShell: Yes