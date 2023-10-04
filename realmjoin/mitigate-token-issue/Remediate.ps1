#====================================
#
# Script Name:     Remediate.ps1
# Description:     Delete RealmJoin token2.dat if found.
# Changelog:       2022-12-09: Fixes, Improved handling in case of missing token2.dat - Only remediate if token2.dat is found but never kill RealmJoin.
# References:      https://gist.github.com/Diagg/73275dff62381eb85ad96c6fc15fea81#file-convert-dsregcmd-ps1
#
#====================================

try {
    # Vars
    $TokenFileFullPath = "$env:LOCALAPPDATA\RealmJoin\token2.dat"

    # Precheck if token2.dat exists
    $TokenFileExists = Test-Path -Path $TokenFileFullPath

    # Only remediate if token2.dat exists
    if ($TokenFileExists) {
        # Delete token2.dat and wait 5 seconds
        Remove-Item "$env:LOCALAPPDATA\RealmJoin\token2.dat" -Force
        Start-Sleep 5
        Write-Output "OK. Token2.dat found and deleted."
    }
    else {
        Write-Output "NOT OK. Token2.dat not found, but we still consider this as a non-error."
    }

    # Success if no errors occured
    exit 0
}# End of try block
    
catch {
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}# End of catch block

