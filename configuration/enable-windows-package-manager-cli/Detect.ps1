#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detect if EnableWindowsPackageManagerCommandLineInterfaces key is existing.
# Changelog:           2023-12-21: Inital version
#
#=============================================================================================================================

try {

    ##Variable declaration
    $path = "HKLM:\Software\Policies\Microsoft\Windows\AppInstaller\"
    $key = "EnableWindowsPackageManagerCommandLineInterfaces"
    
    $property = Get-ItemProperty -Path $path -Name $key -ErrorAction SilentlyContinue
    
    if ($null -ne $property) {
        #MATCH. Remediate. Key is present
        exit 1
    }
        
    #NO MATCH. Do not remediate. Key is not existing.
    exit 0  
    
}
catch {
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}