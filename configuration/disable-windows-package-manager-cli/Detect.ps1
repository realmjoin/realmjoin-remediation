#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detect if winget cli is disabled.
# Changelog:           2023-11-17: Inital version
#
#=============================================================================================================================

try {

    ##Variable declaration
    $path = "HKLM:\Software\Policies\Microsoft\Windows\AppInstaller\"
    $key = "EnableWindowsPackageManagerCommandLineInterfaces"
    $value = "0"
    
    ##Get current value    
    $actualValue = (Get-Item -Path "$path").GetValue("$key")
    if ($actualValue -ne $value) {
        #MATCH. Remediate. Key is not set to target value or not existent
        exit 1
    }
        
    #NO MATCH. Do not remediate. Key is already set to target value.
    exit 0  
    
}
catch {
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}