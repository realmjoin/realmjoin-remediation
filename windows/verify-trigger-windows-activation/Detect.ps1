#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detect if Windows is activated
#
#=============================================================================================================================

# define Variables
$status = Get-CimInstance SoftwareLicensingProduct -Filter "Name like 'Windows%'" | Where-Object { $_.PartialProductKey } | Select-Object Description, LicenseStatus

if($status.LicenseStatus -ne 1) {
	if ((Get-CimInstance -ClassName SoftwareLicensingService | Select-Object -ExpandProperty OA3xOriginalProductKey)) {
		Write-Host "Not activated. Key present in BIOS."		
		# remediation needed
		exit 1
	} else {
		Write-Host "Not activated. No key present in BIOS."
		# remediation needed
		exit 1
	}
} else {
	Write-Host "Activated."
	# no remediation needed
	exit 0
}