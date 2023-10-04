#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detect if Autologon is configured correctly
#
#=============================================================================================================================

try {

    # check if device is AAD joined
    $registryJoinInfo = Get-Item "HKLM:/SYSTEM/CurrentControlSet/Control/CloudDomainJoin/JoinInfo"
    if ($null -eq $registryJoinInfo) {
        # Device not AAD joined. Nothing to do.
        Write-Host "Device not AAD joined. Nothing to do."       
        exit 0
    }

    # check Winlogon settings
    $registryWinlogon = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

    if (($registryWinlogon.AutoAdminLogon -ne 1) -or ($registryWinlogon.DefaultUserName -ne ".\skype") -or ($registryWinlogon.DefaultDomainName -ne "")) {
        # Autologon not configured correctly
        Write-Host "Autologon not configured correctly, DefaultUserName: $($registryWinlogon.DefaultUserName), AutoAdminLogon: $($registryWinlogon.AutoAdminLogon), DefaultDomainName: $($registryWinlogon.DefaultDomainName)"
        exit 1
    } else {
        # Autologon configured correctly
        Write-Host "Autologon configured correctly."       
        exit 0
    }
} catch {
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}