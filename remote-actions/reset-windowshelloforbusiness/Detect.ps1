#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Check if Windows Hello is configured for local users
# Changelog:           2025-04-24: Updated execution logic.
#
#=============================================================================================================================

# define Variables
$baseRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers\{D6886603-9D2F-4EB2-B667-1971041FA96B}"    # registry path for credential provider "Windows Hello PIN"
$keyName = "LogonCredsAvailable"
$expectedValue = 1

$path = "HKCU:\SOFTWARE\RealmJoin\Custom\PAR\reset-windowshelloforbusiness"
$name = "Executed"
$value = 0
$type = [Microsoft.Win32.RegistryValueKind]::DWord

# get amount of configured WHfB PINs
$foundConfiguredPINs = 0
$pathExists = Test-Path -Path $baseRegistryPath
if ($pathExists) {
    # search for LogonCredsAvailable under all SIDs
    Get-ChildItem -Path $baseRegistryPath | ForEach-Object {
        if ($_.PSIsContainer) {
            $keyValue = Get-ItemPropertyValue -Path $_.PSPath -Name $keyName -ErrorAction SilentlyContinue
            if($keyValue -eq $expectedValue) {
                $foundConfiguredPINs++
                $sid = Split-Path $_.Name -Leaf
                Write-Host "Found configured WHfB PIN for $($sid)."
            }
        }
    }
} else {
    Write-Host "WHfB PIN provider not found. Nothing to do."
    exit 0
}

# get status
$parStatus = (Get-ItemPropertyValue -Path $path -Name $name -ErrorAction SilentlyContinue)
if($parStatus -eq 1) {
    Write-Host "Remediation did run. Configured WHfB PINs now: $($foundConfiguredPINs)"
    # Reset status
    Set-ItemProperty -Path $path -Name $name -Value $value -Type $type -Force | Out-Null
    exit 0
} else {
    Write-Host "Start remediation."
    if($foundConfiguredPINs -gt 0) {
        Write-Host "Found configured WHfB PIN for $($foundConfiguredPINs) user(s)."
        exit 1
    } else {
        Write-Host "No configured WHfB PIN found. Nothing to do."
        exit 0
    }
}