#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Remediate Autologon
#
#=============================================================================================================================

try {
    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -Value 1
    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultUserName" -Value ".\skype"
    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultDomainName" -Value $null
    
    $registryWinlogon = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Write-Host "Successfully set DefaultUserName: $($registryWinlogon.DefaultUserName), AutoAdminLogon: $($registryWinlogon.AutoAdminLogon), DefaultDomainName: $($registryWinlogon.DefaultDomainName)"
    exit 0
} catch{
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}
