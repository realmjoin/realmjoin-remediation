#=============================================================================================================================
#
# Script Name:         Detect-WinREPatch-2024Issue.ps1
# Description:         Detect the 0x80070643 WinRE-Pach Installation issue
# Changelog:           2024-02-16: Initial.
#
#=============================================================================================================================

# define Variables
$check = $true
$ErrorCode = "0x8024200B"

if ($check) {
#Search the system event log for events that indicate the error code.
$ErrorEvents = Get-WinEvent -LogName System | Where-Object {
    $_.Message -match $ErrorCode -and ($_.ProviderName -match "WindowsUpdate" -or $_.ProviderName -match "Installer")
}

#Check if any error events have been found
if ($ErrorEvents.Count -gt 0) {
    Write-Host "Error found"
    exit 1
} else {
    # no problem detected
    Write-Host "No error detected!"
    exit 0
}
}
