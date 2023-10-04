#=============================================================================================================================
#
# Script Name:     Remediate.ps1
# Description:     Set Credential Guard registry items.
#                 
#=============================================================================================================================
try {
    Write-Host "Set registry keys."
    Set-ItemProperty HKLM:\System\CurrentControlSet\Control\DeviceGuard -Name EnableVirtualizationBasedSecurity -Value 1
    Set-ItemProperty HKLM:\System\CurrentControlSet\Control\DeviceGuard -Name RequirePlatformSecurityFeatures -Value 3
    Set-ItemProperty HKLM:\System\CurrentControlSet\Control\LSA -Name LsaCfgFlags -Value 1
    Write-Host "Successfully set registry keys."
    exit 0  
}
catch {
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}