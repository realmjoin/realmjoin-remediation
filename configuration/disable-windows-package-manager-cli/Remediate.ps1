#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Disable winget cli.
# Changelog:           2023-11-17: Inital version
#
#=============================================================================================================================

try {

    ##Variable declaration
    $path = "HKLM:\Software\Policies\Microsoft\Windows\AppInstaller\"
    $key = "EnableWindowsPackageManagerCommandLineInterfaces"
    $value = "0"
    $type = "DWord"
    
    ##Check reg path and create path if missing
    if (!(Test-Path $path)) {
        New-Item -Path "$path" -Force
    }
    $actualValue = (Get-Item -Path "$path").GetValue("$key")
    if ($actualValue -ne $value) {
        ##Create key and set value
        Set-ItemProperty -Path "$path" -Name "$key" -Value "$value" -Type "$type" -Force
    }

    #Succes if no errors occured.
    exit 0

}
catch {
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}