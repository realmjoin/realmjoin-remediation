#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Trigger defender updates
# Changelog:           2023-12-02: Initial version.
#
#=============================================================================================================================

try {
    # trigger updates
    Update-MpSignature -UpdateSource MMPC -AsJob -ErrorAction SilentlyContinue | Out-Null
    Write-Host "Executed Update-MpSignature."

    # update status in registry
    $registryPathStatus = "HKLM:\SOFTWARE\RealmJoin\Custom\PAR"         # path
    $registryNameStatus = "TriggeredDefenderUpdatesInOOBE"              # name
    $registryValueStatus = 1                                                          # value
    $registryTypeStatus = [Microsoft.Win32.RegistryValueKind]::DWord                  # type: String, ExpandString, Binary, DWord, MultiString, Qword, Unknown

    if(!(Test-Path $registryPathStatus)) {
        New-Item -Path $registryPathStatus -Force | Out-Null
        Set-ItemProperty -Path $registryPathStatus -Name $registryNameStatus -Value $registryValueStatus -Type $registryTypeStatus -Force | Out-Null
    } else {
        Set-ItemProperty -Path $registryPathStatus -Name $registryNameStatus -Value $registryValueStatus -Type $registryTypeStatus -Force | Out-Null
    }

    exit 0
} catch {
    # error occured
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}