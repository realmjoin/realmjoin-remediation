#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Delete WHfB Container
# Changelog:           2025-04-24: Updated execution logic.
#
#=============================================================================================================================

# define Variables
$path = "HKCU:\SOFTWARE\RealmJoin\Custom\PAR\reset-windowshelloforbusiness"
$name = "Executed"
$value = 1
$type = [Microsoft.Win32.RegistryValueKind]::DWord

try {
    
    Write-Host "Running certutil.exe -DeleteHelloContainer"
    Start-Process -FilePath "certutil.exe" -ArgumentList "-DeleteHelloContainer" -Wait

    # store execution status
    if(!(Test-Path $path)) {
        New-Item -Path $path -Force | Out-Null
        Set-ItemProperty -Path $path -Name $name -Value $value -Type $type -Force | Out-Null
    } else {
        Set-ItemProperty -Path $path -Name $name -Value $value -Type $type -Force | Out-Null
    }

    exit 0

} catch {
    # error occured
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}