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

    $registryNameStatusOOBE = "TriggeredDefenderUpdatesInOOBE"              # name
    $registryValueStatusOOBE = 1                                            # value
    $registryTypeStatusOOBE = [Microsoft.Win32.RegistryValueKind]::DWord    # type: String, ExpandString, Binary, DWord, MultiString, Qword, Unknown

    $registryNameStatusOOBETime = "TriggeredDefenderUpdatesInOOBETime"              # name
    $registryValueStatusOOBETime = Get-Date -Format "yyyy-MM-dd HH:mm K"            # value
    $registryTypeStatusOOBETime = [Microsoft.Win32.RegistryValueKind]::String       # type: String, ExpandString, Binary, DWord, MultiString, Qword, Unknown

    $registryNameStatusTime = "TriggeredDefenderUpdatesTime"              # name
    $registryValueStatusTime = Get-Date -Format "yyyy-MM-dd HH:mm K"            # value
    $registryTypeStatusTime = [Microsoft.Win32.RegistryValueKind]::String       # type: String, ExpandString, Binary, DWord, MultiString, Qword, Unknown


    if(!(Test-Path $registryPathStatus)) {
        New-Item -Path $registryPathStatus -Force | Out-Null
    }
    if((Get-ItemProperty -Path $registryPathStatus).$registryNameStatusOOBE -ne "1"){
        Set-ItemProperty -Path $registryPathStatus -Name $registryNameStatusOOBE -Value $registryValueStatusOOBE -Type $registryTypeStatusOOBE -Force | Out-Null
        Set-ItemProperty -Path $registryPathStatus -Name $registryNameStatusOOBETime -Value $registryValueStatusOOBETime -Type $registryTypeStatusOOBETime -Force | Out-Null
    } else {
        Set-ItemProperty -Path $registryPathStatus -Name $registryNameStatusTime -Value $registryValueStatusTime -Type $registryTypeStatusTime -Force | Out-Null
    }
    exit 0
} catch {
    # error occured
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}