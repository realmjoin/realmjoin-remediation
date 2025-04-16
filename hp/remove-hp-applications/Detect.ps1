#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detect if unwanted HP applications are installed.
# Changelog:           2025-04-16: Release.
# References:          ...
# Notes:               ...
#
#=============================================================================================================================

# define Variables
$programNamesToUninstall = @("HP Wolf Security", "HP Wolf Security - Console", "HP Security Update Service", "HP Client Security Manager", "HP Sure Click", "HP Sure Click Security Browser", "HP Sure Sense", "HP Sure Sense Installer", "HP Sure Run", "HP JumpStart", "HP Wolf Security Application Support for Sure Sense", "HP Wolf Security Application Support for Windows", "HP Wolf Security Application Support for Chrome")
$uninstallRequired = $false
$uninstallList = ""
$allProgramsWmiObject = Get-WmiObject -Class Win32_Product

# check if program exists
foreach ($programName in $programNamesToUninstall){
    
    Write-Host "Searching for: " $programName 
    $programsFound = $allProgramsWmiObject | Where-Object { $_.Name -eq $programName }
    if(!$programsFound) {
        $programsFound = $allProgramsWmiObject | Where-Object { $_.Name -match $programName }
    }

    foreach ($programFound in $programsFound) {
        if ($programNamesToUninstall.IndexOf($programName) -ne 0) {
            $uninstallList += ", "
        }
        $programIDFound = $programFound.IdentifyingNumber.toString()
        $programNameFound = $programFound.Name.toString()
        Write-Host "Found: $($programNameFound) (ID: $($programIDFound))"
        $uninstallRequired = $true
        $uninstallList += "$($programNameFound)"
    }
}

if($uninstallRequired) {
    Write-Host "Uninstall required: " $uninstallList
    exit 1
} else {
    # no problem detected
    Write-Host "No program found."
    exit 0
}