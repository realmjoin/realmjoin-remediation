#=============================================================================================================================
#
# Script Name:     Remediate-CredentialGuard.ps1
# Description:     Enable CredentialGuard Settings
#                 
#=============================================================================================================================
try
{
$RegDeviceGuard=Get-ItemProperty -Path HKLM:\System\CurrentControlSet\Control\DeviceGuard
$RegLSA=Get-ItemProperty -Path HKLM:\System\CurrentControlSet\Control\LSA
if (($RegDeviceGuard.EnableVirtualizationBasedSecurity -ne 1) -or ($RegDeviceGuard.RequirePlatformSecurityFeatures -ne 3) -or ($RegLSA.LsaCfgFlags -ne 1)) {
write-host "Start remediation for: Enableing CredentialGuard"
Set-ItemProperty HKLM:\System\CurrentControlSet\Control\DeviceGuard -Name EnableVirtualizationBasedSecurity -Value 1
Set-ItemProperty HKLM:\System\CurrentControlSet\Control\DeviceGuard -Name RequirePlatformSecurityFeatures -Value 3
Set-ItemProperty HKLM:\System\CurrentControlSet\Control\LSA -Name LsaCfgFlags -Value 1
} else{
	#CredentialGuard enabled, do not remediate
	write-host "CredentialGuard is enabled, no remediation needed"	
	exit 0
    }  
}
 catch{
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}