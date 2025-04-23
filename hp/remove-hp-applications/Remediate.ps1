#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Uninstall unwanted HP applications.
# Changelog:           2025-04-16: Release.
#                      2025-04-17: Fix.
#                      2025-04-22: Improved detection method.
# References:          https://enterprisesecurity.hp.com/s/article/How-to-uninstall-HP-Wolf-Pro-Security
#                      https://gist.github.com/mark05e/a79221b4245962a477a49eb281d97388
# Notes:               Uninstall order for HP Wolf Security:
#                       - HP Wolf Security
#                       - HP Wolf Security - Console
#                       - HP Security Update Service
#
#=============================================================================================================================

# define Variables
$programNamesToUninstall = @("HP Wolf Security", "HP Wolf Security - Console", "HP Security Update Service", "HP Client Security Manager", "HP Sure Click", "HP Sure Click Security Browser", "HP Sure Sense", "HP Sure Sense Installer", "HP Sure Run Module", "HP JumpStart", "HP Wolf Security Application Support for Sure Sense", "HP Wolf Security Application Support for Windows", "HP Wolf Security Application Support for Chrome*")
$allProgramsWmiObject = Get-CimInstance -ClassName Win32_Product
$uninstalledList = ""

# uninstallations
try {
    foreach ($programName in $programNamesToUninstall){
        
        Write-Host "Searching for: " $programName 
        $programsFound = $allProgramsWmiObject | Where-Object { $_.Name -like $programName }

        foreach ($programFound in $programsFound) {
            if ($programNamesToUninstall.IndexOf($programName) -ne 0) {
                $uninstalledList += ", "
            }
            $programIDFound = $programFound.IdentifyingNumber.toString()
            $programNameFound = $programFound.Name.toString()
            Write-Host "Found: $($programNameFound) (ID: $($programIDFound))"
            Write-Host "Starting uninstall."
            Start-Process msiexec.exe -Wait -ArgumentList "/x $programIDFound /qn /norestart"
            Write-Host "Uninstall done."
            $uninstalledList += "$($programNameFound)"
        }

    }
} catch {
    # error occured
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}

Write-Host "Uninstalled: $($uninstalledList)"
exit 0