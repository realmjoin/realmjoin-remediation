#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detect if RjImeHost user part of the RealmJoin IntuneWin M365 Apps for Enterprise Package is present.
# Changelog:           2025-02-20: Initial version
#
#=============================================================================================================================

try {
    # Variable declaration
    ## General
    $m365AppsRjImeHostUserPartPath = "HKLM:\SOFTWARE\RealmJoin\RjImeHost\RegisteredUserParts\generic-microsoft-office-2016-proplus-usersettings"
    $m365AppsRjImeHostUserPartPathExists = $null

    # Functions
    Function Test-RegistryPath {
        param (
            [parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]$Path
        )
        
        try {
            Test-Path $Path -ErrorAction Stop | Out-Null
            return $true
        } catch {
            return $false
        }
    }

    Function Remove-RegistryPath {
        param (
            [parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]$Path
        )
        
        try {
            Remove-Item -Path $Path -Force -Recurse -ErrorAction Stop | Out-Null
        } catch {
            throw "Could not remove reg path $Path"
        }
    }



    # Main
    $m365AppsRjImeHostUserPartPathExists = Test-RegistryPath -Path $m365AppsRjImeHostUserPartPath
    if ($m365AppsRjImeHostUserPartPathExists) {
        # Exists - Remediate
        Write-Output "RjImeHost user part detected - NOK"
        exit 1
    } else {
        Write-Output "Nothing detected - OK"
        exit 0
    }
}
catch {
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}