#====================================
#
# Script Name:     Detect-RealmJoinTokenIssue.ps1
# Description:     Detect if RealmJoin token has not updated due to authentication problems of client. 
# Run Scope:       USER
# Changelog:       2022-12-09: Fixes, Improved handling in case of missing token2.dat - Do not remediate if token2.dat is missing completely
# References:      https://gist.github.com/Diagg/73275dff62381eb85ad96c6fc15fea81#file-convert-dsregcmd-ps1
#
#====================================

try {
    # Vars
    $TokenFileFullPath = "$env:LOCALAPPDATA\RealmJoin\token2.dat"
    $AllowedTimeDriftInDays = 10

    # Precheck if token2.dat exists
    $TokenFileExists = Test-Path -Path $TokenFileFullPath
    
    # Check status depending on existence and age of token2.dat file
    if ($TokenFileExists) {
        # Get last PRT update time via dsregcmd and extract/convert value to DateTime
        $Dsregcmd = New-Object PSObject; Dsregcmd /status | Where-Object {$_ -match ' : '} | ForEach-Object {$Item = $_.Trim() -split '\s:\s'; $Dsregcmd | Add-Member -MemberType NoteProperty -Name $($Item[0] -replace '[:\s]','') -Value $Item[1] -ErrorAction SilentlyContinue}
        # Convert output to DateTime, therefore string " UTC" must be removed
        [DateTime]$PrtUpdateUTC = ($Dsregcmd.AzureAdPrtUpdateTime).replace(" UTC","")

        # Get last modified timestamp of RealmJoin token2.dat
        $TokenFileModUTC = ((Get-Item $TokenFileFullPath).LastWriteTime).ToUniversalTime()

        # To avoid false positives, we allow token2.dat to be a lot older in comparison to last PRT Update Time
        $referenceTime=$PrtUpdateUTC.AddDays(-$AllowedTimeDriftInDays)

        If ( $TokenFileModUTC -gt $referenceTime ) {
            Write-Output "OK. token2.dat modified $(($TokenFileModUTC).tostring("dd.MM.yyyy HH:mm:ss")) UTC // Last PRT Update at $(($PrtUpdateUTC).tostring("dd.MM.yyyy HH:mm:ss")) UTC. Token2.dat is newer or less than $AllowedTimeDriftInDays Days older than last PRT Update Time."
            exit 0
        }
        else {
            Write-Output "NOT OK. token2.dat modified $(($TokenFileModUTC).tostring("dd.MM.yyyy HH:mm:ss")) UTC // Last PRT Update at $(($PrtUpdateUTC).tostring("dd.MM.yyyy HH:mm:ss")) UTC. Token2.dat is more than $AllowedTimeDriftInDays Days older than last PRT Update Time."
            exit 1
        }
    }
    else {
        Write-Output "OK. token2.dat not found - should remediate itself on next reboot/logon."
        exit 0
    }
}# End of try block
    
catch {
    $errMsg = $_.Exception.Message
    return $errMsg
    exit 1
}# End of catch block