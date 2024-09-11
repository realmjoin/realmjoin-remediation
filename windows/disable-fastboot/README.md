# Detect if Fastboot is enabled and ensures that it is disabled.

Checks the state of the FastBoot registry key
- Path: `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power`
- Name: `HiberbootEnabled`
- Type: `DWORD`

A value of `1` indicates that Fastboot is enabled.  
A value of `0` indicates that Fastboot is dsabled.

In case it is enabled this script disables it.