# Repair MTR Autologon

Repair Autologon on Microsoft Teams rooms devices (might break after AAD join).

MTR tries to login to AAD with "Skype" as username what fails due to it is only a local account.
Changing DefaultUserName (HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon) from "Skype" to ".\skype" repairs it. Adding ".\" switches authentication back to the local device.