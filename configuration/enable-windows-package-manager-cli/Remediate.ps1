#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Delete key EnableWindowsPackageManagerCommandLineInterfaces
# Changelog:           2023-12-22: Inital version
#
#=============================================================================================================================

try {

    ##Variable declaration
    $path = "HKLM:\Software\Policies\Microsoft\Windows\AppInstaller\"
    $key = "EnableWindowsPackageManagerCommandLineInterfaces"
    
    Get-Item $path | Remove-ItemProperty -Name $key -Force

    #Succes if no errors occured.
    exit 0

}
catch {
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}