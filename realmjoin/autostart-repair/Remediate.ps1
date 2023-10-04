#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Re-create RealmJoinCloudTray.lnk
#
#=============================================================================================================================

try {
    
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$($env:APPDATA)\Microsoft\Windows\Start Menu\Programs\Startup\RealmJoinCloudTray.lnk")
    $Shortcut.TargetPath = "C:\Program Files\RealmJoin\RealmJoin.exe"
    $Shortcut.Arguments = "-tray"
    $Shortcut.Save()

    & "C:\Program Files\RealmJoin\RealmJoin.exe" -tray

    Write-Host "RealmJoinCloudTray.lnk created and CloudTray started."
    exit 0
    
} catch {
    # error occured
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}