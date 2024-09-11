#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detect if feature is enabled
#
#=============================================================================================================================

# define Variables
$path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
$name = "HiberbootEnabled"

$currentValue = Get-ItemPropertyValue -Path $path -Name $name -ErrorAction SilentlyContinue

if($null -ne $currentValue) {
	Write-Host "Registry keys found."
	if($currentValue -eq 0) {
		# no remediation needed
		Write-Host "Registry keys found and values correct."	
		exit 0
	} else {
		# remediation required
		Write-Host "Registry keys found and but value/s not correct."
		exit 1
	}
} else {
	# remediation required
	Write-Host "Registry key/s not found."
	exit 1
}