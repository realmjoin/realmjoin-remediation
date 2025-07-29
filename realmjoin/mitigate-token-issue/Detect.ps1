#====================================
#
# Script Name:     Detect.ps1
# Description:     Detect if RealmJoin token has not updated due to authentication problems of client. 
# Changelog:       2022-12-09: Fixes, Improved handling in case of missing token file - Do not remediate if token file is missing completely
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

    $AllowedTimeDriftInDays = 10

    # Precheck if token file exists
    $TokenFileExists = Test-Path -Path $TokenFileFullPath
    
    # Check status depending on existence and age of token file file

    if ($TokenFileExists) {
        # Get last PRT update time via dsregcmd and extract/convert value to DateTime
        $Dsregcmd = New-Object PSObject; Dsregcmd /status | Where-Object { $_ -match ' : ' } | ForEach-Object { $Item = $_.Trim() -split '\s:\s'; $Dsregcmd | Add-Member -MemberType NoteProperty -Name $($Item[0] -replace '[:\s]', '') -Value $Item[1] -ErrorAction SilentlyContinue }
        # Convert output to DateTime, therefore string " UTC" must be removed
        [DateTime]$PrtUpdateUTC = ($Dsregcmd.AzureAdPrtUpdateTime).replace(" UTC", "")

        # Get last modified timestamp of RealmJoin token file
        $TokenFileModUTC = ((Get-Item $TokenFileFullPath).LastWriteTime).ToUniversalTime()

        # To avoid false positives, we allow token file to be a lot older in comparison to last PRT Update Time
        $referenceTime = $PrtUpdateUTC.AddDays(-$AllowedTimeDriftInDays)

        If ( $TokenFileModUTC -gt $referenceTime ) {
            Write-Output "OK. token file modified $(($TokenFileModUTC).tostring("dd.MM.yyyy HH:mm:ss")) UTC // Last PRT Update at $(($PrtUpdateUTC).tostring("dd.MM.yyyy HH:mm:ss")) UTC. token file is newer or less than $AllowedTimeDriftInDays Days older than last PRT Update Time."
            exit 0
        }
        else {
            Write-Output "NOT OK. token file modified $(($TokenFileModUTC).tostring("dd.MM.yyyy HH:mm:ss")) UTC // Last PRT Update at $(($PrtUpdateUTC).tostring("dd.MM.yyyy HH:mm:ss")) UTC. token file is more than $AllowedTimeDriftInDays Days older than last PRT Update Time."
            exit 1
        }
    }
    else {
        Write-Output "OK. token file not found - should remediate itself on next reboot/logon."
        exit 0
    }
}# End of try block
    
catch {
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}# End of catch block