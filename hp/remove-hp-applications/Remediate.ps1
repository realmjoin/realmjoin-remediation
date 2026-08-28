#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Uninstall unwanted HP applications.
# Changelog:           2025-04-16: Release.
#                      2025-04-17: Fix.
#                      2025-04-22: Improved detection method.
#                      2025-01-27: Fixed output, added HP One Agent and uninstall via Registry.
# References:          https://enterprisesecurity.hp.com/s/article/How-to-uninstall-HP-Wolf-Pro-Security
#                      https://gist.github.com/mark05e/a79221b4245962a477a49eb281d97388
# Notes:               Uninstall order for HP Wolf Security:
#                       - HP Wolf Security
#                       - HP Wolf Security - Console
#                       - HP Security Update Service
#
#=============================================================================================================================

# define Variables
$programNamesToUninstall = @("HP Wolf Security", "HP Wolf Security - Console", "HP Security Update Service", "HP Client Security Manager", "HP Sure Click", "HP Sure Click Security Browser", "HP Sure Sense", "HP Sure Sense Installer", "HP Sure Run Module", "HP JumpStart", "HP Wolf Security Application Support for Sure Sense", "HP Wolf Security Application Support for Windows", "HP Wolf Security Application Support for Chrome*", "HP One Agent")
$programNamesToUninstallReg = @("HP One Agent")

$uninstalledList = ""

# uninstallations
try {

    # search in Win32_Product
    $allProgramsWmiObject = Get-CimInstance -ClassName Win32_Product

    foreach ($programName in $programNamesToUninstall) {
        
        Write-Host "Searching for: " $programName 
        $programsFound = $allProgramsWmiObject | Where-Object { $_.Name -like $programName }

        foreach ($programFound in $programsFound) {
            $programIDFound = $programFound.IdentifyingNumber.toString()
            $programNameFound = $programFound.Name.toString()
            Write-Host "Found: $($programNameFound) (ID: $($programIDFound))"
            Write-Host "Starting uninstall."
            Start-Process msiexec.exe -Wait -ArgumentList "/x $programIDFound /qn /norestart"
            Write-Host "Uninstall done."
            if ($uninstalledList -ne "") {
                $uninstalledList += ", "
            }
            $uninstalledList += "$($programNameFound)"
        }

    }

    # search in registry
    $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    $registryEntries = Get-ChildItem -Path $registryPath

    foreach ($entry in $registryEntries) {

        $props = Get-ItemProperty -Path $entry.PSPath
        foreach ($programNamToUninstallReg in $programNamesToUninstallReg) {
            if ($props.DisplayName -like "*$programNamToUninstallReg*") {
                if ($props.QuietUninstallString) {
                    Write-Host "Found in registry: $($props.DisplayName)"
                    Write-Host "Starting uninstall."
                    Write-Host "Executing QuietUninstallString: $($props.QuietUninstallString)"
                    Start-Process -FilePath "cmd.exe" -ArgumentList "/c $($props.QuietUninstallString)" -Wait
                    Write-Host "Uninstall done."
                    if ($uninstalledList -ne "") {
                        $uninstalledList += ", "
                    }
                    $uninstalledList += "$($props.DisplayName)"
                }
            }
        }
    }

}
catch {
    # error occured
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}

Write-Host "Uninstalled: $($uninstalledList)"
exit 0