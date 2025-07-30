#====================================
#
# Script Name:     Remediate.ps1
# Description:     Delete RealmJoin token file if found.
# Changelog:       2022-12-09: Fixes, Improved handling in case of missing token file - Only remediate if token file is found but never kill RealmJoin.
# References:      https://gist.github.com/Diagg/73275dff62381eb85ad96c6fc15fea81#file-convert-dsregcmd-ps1
#
#====================================

try {
    # Vars
    $oldTokenPath = "$env:LOCALAPPDATA\RealmJoin\token2.dat"
    $newTokenPath = "$env:LOCALAPPDATA\RealmJoin\msal_cache.dat"

    # determine if new msal_cache.dat file already used
    if (Test-Path $newTokenPath) {
        $TokenFileFullPath = $newTokenPath
        Write-Output "Token file msal_cache.dat found."
    } else {
        $TokenFileFullPath = $oldTokenPath
        Write-Output "Token file token2.dat found."
    }

    # Precheck if token file exists
    $TokenFileExists = Test-Path -Path $TokenFileFullPath

    # Only remediate if token file exists
    if ($TokenFileExists) {
        # Delete token file and wait 5 seconds
        Remove-Item $TokenFileFullPath -Force
        Start-Sleep 5
        Write-Output "OK. token file found and deleted."
    }
    else {
        Write-Output "NOT OK. token file not found, but we still consider this as a non-error."
    }

    # Success if no errors occured
    exit 0
}# End of try block
    
catch {
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}# End of catch block

