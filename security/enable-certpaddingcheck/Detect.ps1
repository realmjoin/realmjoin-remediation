#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detect if feature is enabled
#
#=============================================================================================================================

# define Variables
$path = "HKLM:\Software\Microsoft\Cryptography\Wintrust\Config"
$name = "EnableCertPaddingCheck"

$path64Bit = "HKLM:\Software\Wow6432Node\Microsoft\Cryptography\Wintrust\Config"
$name64Bit = "EnableCertPaddingCheck"

$currentValue = Get-ItemPropertyValue -Path $path -Name $name -ErrorAction SilentlyContinue
$currentValue64Bit = Get-ItemPropertyValue -Path $path64Bit -Name $name64Bit -ErrorAction SilentlyContinue

if(($null -ne $currentValue) -and ($null -ne $currentValue64Bit)) {
	Write-Host "Registry keys found."
	if(($currentValue -eq 1) -and ($currentValue64Bit -eq 1)) {
		Write-Host "Registry keys found and values correct."	
		#exit 0
	} else {
		Write-Host "Registry keys found and but value/s not correct."
		#exit 1
	}
} else {
	Write-Host "Registry key/s not found."
	#exit 1
}