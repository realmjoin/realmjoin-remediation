#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Update HideFileExt.
# Changelog:           2025-05-13: Inital version
#
#=============================================================================================================================

# define Variables
$path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\"
$name = "HideFileExt"
$value = 0
$type = [Microsoft.Win32.RegistryValueKind]::DWord

try {
    # update HideFileExt
    if(!(Test-Path $path)) {
        Write-Host "Create and set HideFileExt."
        New-Item -Path $path -Force | Out-Null
        Set-ItemProperty -Path $path -Name $name -Value $value -Type $type -Force | Out-Null
    } else {
        Write-Host "Set HideFileExt."
        Set-ItemProperty -Path $path -Name $name -Value $value -Type $type -Force | Out-Null
    }
    Write-Host "Updated HideFileExt."
    exit 0
} catch {
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}