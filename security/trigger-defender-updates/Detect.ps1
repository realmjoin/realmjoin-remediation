#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detect if signature updates need to be triggered
# Changelog:           2023-12-02: Initial version.
# Notes:               Checks if DefenderSignaturesOutOfDate is true or updates have never been triggered
#                      during inital deployment
#
#=============================================================================================================================

# define Variables
$defenderComputerStatus = Get-MpComputerStatus 
$defenderSignaturesOutOfDate = $defenderComputerStatus.DefenderSignaturesOutOfDate
$defenderAntivirusSignatureVersion = $defenderComputerStatus.AntivirusSignatureVersion
$triggeredDefenderUpdatesInOOBE = $false

$registryPathStatus = "HKLM:\SOFTWARE\RealmJoin\Custom\PAR"         # path
$registryNameStatus = "TriggeredDefenderUpdatesInOOBE"              # name

if(Test-Path $registryPathStatus) {
    if(((Get-ItemProperty -Path $registryPathStatus).$registryNameStatus -eq "1") -and ($null -ne (Get-ItemProperty -Path $registryPathStatus).$registryNameStatus)){
        $triggeredDefenderUpdatesInOOBE = $true
    }
}

if (($defenderSignaturesOutOfDate -eq $true) -or ($triggeredDefenderUpdatesInOOBE -eq $false)) {
    # problem detected
    Write-Host "Signatures need update. Version: $($defenderAntivirusSignatureVersion)"
    exit 1
} else {
    # no problem detected
    Write-Host "Signatures OK. Version: $($defenderAntivirusSignatureVersion)"
    exit 0
}