#=============================================================================================================================
#
# Script Name:     Detect-CredentialGuard.ps1
# Description:     Detect if CredentialGuard is enabled on the Machine
#                 
#=============================================================================================================================

# Define Variables
$RegDeviceGuard = @()
$RegLSA = @()

# Detect Script

try
{

$RegDeviceGuard=Get-ItemProperty -Path HKLM:\System\CurrentControlSet\Control\DeviceGuard
$RegLSA=Get-ItemProperty -Path HKLM:\System\CurrentControlSet\Control\LSA

if (($RegDeviceGuard.EnableVirtualizationBasedSecurity -ne 1) -or ($RegDeviceGuard.RequirePlatformSecurityFeatures -ne 3) -or ($RegLSA.LsaCfgFlags -ne 1)) {
    #CredentialGuard not enabled, start remediation
    #CredentialGuard not enabled, start remediation
    Write-Host "Credential Guard not enabled"
	exit 1
} else {
        #CredentialGuard enabled, do nothing
        Write-Host "Credential Guard enabled"        
        exit 0
}
}

catch{
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}