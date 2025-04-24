#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Start remediation directly
# Changelog:           2025-04-24: Release.
#
#=============================================================================================================================

# define Variables
$path = "HKCU:\SOFTWARE\RealmJoin\Custom\PAR\reset-windows-search"
$name = "Executed"
$value = 0
$type = [Microsoft.Win32.RegistryValueKind]::DWord

# get status
$parStatus = (Get-ItemPropertyValue -Path $path -Name $name -ErrorAction SilentlyContinue)
if($parStatus -eq 1) {
    Write-Host "Remediation did run."
    # Reset status
    Set-ItemProperty -Path $path -Name $name -Value $value -Type $type -Force | Out-Null
    exit 0
} else {
    Write-Host "Start remediation."
    exit 1
}