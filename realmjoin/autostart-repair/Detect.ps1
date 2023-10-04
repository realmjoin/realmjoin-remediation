#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detect RJ startup
#
#=============================================================================================================================

if (Test-Path -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\RealmJoin CloudTray.lnk")
{
    Write-Host "RJ startup intact (system)."
    exit 0
}

if (Test-Path -Path "$($env:APPDATA)\Microsoft\Windows\Start Menu\Programs\Startup\RealmJoinCloudTray.lnk")
{
    Write-Host "RJ startup intact (user)."
    exit 0
}

Write-Host "RJ Startup not intact."
exit 1