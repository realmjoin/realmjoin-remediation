#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Set registry keys
#
#=============================================================================================================================

# define Variables
$path = "HKLM:\Software\Microsoft\Cryptography\Wintrust\Config"
$name = "EnableCertPaddingCheck"
$value = 1
$type = [Microsoft.Win32.RegistryValueKind]::DWord

$path64Bit = "HKLM:\Software\Wow6432Node\Microsoft\Cryptography\Wintrust\Config"
$name64Bit = "EnableCertPaddingCheck"
$value64Bit = 1
$type64Bit = [Microsoft.Win32.RegistryValueKind]::DWord

try {

    # set registry key
    if(!(Test-Path $path)) {
        New-Item -Path $path -Force | Out-Null
        Set-ItemProperty -Path $path -Name $name -Value $value -Type $type -Force | Out-Null
    }
    else {
        Set-ItemProperty -Path $path -Name $name -Value $value -Type $type -Force | Out-Null
    }

    # set registry key (64 bit)
    if(!(Test-Path $path64Bit)) {
        New-Item -Path $path64Bit -Force | Out-Null
        Set-ItemProperty -Path $path64Bit -Name $name64Bit -Value $value64Bit -Type $type64Bit -Force | Out-Null
    }
    else {
        Set-ItemProperty -Path $path64Bit -Name $name64Bit -Value $value64Bit -Type $type64Bit -Force | Out-Null
    }
    
} catch {
    # error occured
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}