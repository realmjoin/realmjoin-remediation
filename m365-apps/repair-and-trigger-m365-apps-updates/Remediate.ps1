#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Start the "Click to Run Service" and change its startup type to Automatic
# Changelog:           2023-11-14: Initial version
#
#=============================================================================================================================

# define Variables
$svcCur = "ClickToRunSvc"
$curSvcStat, $svcCTRSvc, $errMsg = "", "", ""


# First, let's make sure nothing has changed since detection and service exists and is stopped
try {        
    $svcCTRSvc = Get-Service $svcCur
    $curSvcStat = $svcCTRSvc.Status
} catch {    
    $errMsg = $_.Exception.Message
    Write-Host $errMsg
    exit 1
}
        
# if the service got started between detection and now (nested if) then return
# if the service got uninstalled or corrupted between detection and now (else) then return the "Error: " + the error
if ($curSvcStat -ne "Stopped") {
    if ($curSvcStat -eq "Running") {
        Write-Output "Running"
        exit 0
    }
    else {
        Write-Host $errMsg
        exit 1
    }
}

# Okay, the service should be there and be stopped, we'll change the startup type and get it running
try {        
    Set-Service $svcCur -StartupType Automatic
    Start-Service $svcCur
    $svcCTRSvc = Get-Service $svcCur
    $curSvcStat = $svcCTRSvc.Status
    While ($curSvcStat -eq "Stopped") {
        Start-Sleep -Seconds 5
        ctr++
        if (ctr -eq 12) {
            Write-Output "Service could not be started after 60 seconds"
            exit 1
        }
    }
} catch {    
    $errMsg = $_.Exception.Message
    Write-Host $errMsg
    exit 1
}