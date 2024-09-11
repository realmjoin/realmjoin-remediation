#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Set registry keys
#
#=============================================================================================================================

# define Variables
$path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
$name = "HiberbootEnabled"
$value = "0"
$type = [Microsoft.Win32.RegistryValueKind]::DWord

try {
    # set registry key
    if(!(Test-Path $path)) {
        New-Item -Path $path -Force | Out-Null
        Set-ItemProperty -Path $path -Name $name -Value $value -Type $type -Force | Out-Null
    }
    else {
        Set-ItemProperty -Path $path -Name $name -Value $value -Type $type -Force | Out-Null
    }
    
} catch {
    # error occured
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}
