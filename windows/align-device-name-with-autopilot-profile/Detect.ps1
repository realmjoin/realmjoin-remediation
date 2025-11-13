#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detect if current hostname matches device name template
# Changelog:           2025-11-13: Inital version
#
#=============================================================================================================================

# define Variables
$hostname = $env:COMPUTERNAME
$originalSerial = (Get-WmiObject -Class Win32_BIOS -ErrorAction SilentlyContinue).SerialNumber
if ([string]::IsNullOrWhiteSpace($originalSerial)) {
    Write-Host "No serial number found. Name: $($hostname)"
    exit 1
}
$nameTemplateRegPath = "HKLM:\SOFTWARE\Microsoft\Provisioning\Diagnostics\AutoPilot\"
$nameTemplateRegName = "CloudAssignedDeviceName"
$templateVariable = "%SERIAL%"
$maxHostnameLength = 15

# get Autopilot device name template
$nameTemplate = (Get-ItemPropertyValue -Path $nameTemplateRegPath -Name $nameTemplateRegName -ErrorAction SilentlyContinue)

if($null -ne $nameTemplate) {
	# search for existence of variable in template
	if($nameTemplate -match $templateVariable) {

		# check if SN contains hyphens and remove them
		$serial = $originalSerial -replace "-",""
		# insert SN for templateVariable
		$desiredName = $nameTemplate.Replace($templateVariable, $serial)
		# check if SN too long
		if ($desiredName.Length -gt $maxHostnameLength)  {
			$namePrefix = $nameTemplate.Replace($templateVariable, "")
			$maxSerialLength = $maxHostnameLength - $namePrefix.Length
			$trimmedSerial = $serial.Substring($serial.Length - $maxSerialLength)
			$desiredName = $nameTemplate.Replace($templateVariable, $trimmedSerial)
		}

		# compare with current hostname
		if($desiredName -eq $hostname) {
			Write-Host "Compliant. Name: $($hostname), SN: $($originalSerial)"
    		exit 0
		} else {
			Write-Host "Not compliant. Name: $($hostname), Desired: $($desiredName), SN: $($originalSerial)"
    		exit 1
		}
	} else {
		Write-Host "Unsupported device name template. Name: $($hostname)"
    	exit 1
	}
} else {
    Write-Host "Device name template not found. Name: $($hostname)"
    exit 1
}