#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detect if feature is enabled
#
#=============================================================================================================================

# define Variables
$path = "HKCU:\Software\Microsoft\Office\Outlook\Settings\Data"
$usr = whoami /upn
$value = $usr + "_EnableSuggestedReplies"

function Test-RegistryKeyValue {
	if ( -not (Test-Path -Path $path -PathType Container) ) {
		return $false
	}
	$properties = Get-ItemProperty -Path $path 
	if ( -not $properties ) {
		return $false
	}
	$member = Get-Member -InputObject $properties -Name $value
	if ( $member ) {
		return $true
	} else {
		return $false
	}
}

if (Test-RegistryKeyValue) {
	$curString = Get-ItemPropertyValue -Path $path -Name $value
	if ($curString -match '"value":"false"') {
		Write-Host "Feature disabled. No action."
        exit 0
	}
	else {
		Write-Host "Feature enabled."
        exit 1
	}
} else {
    Write-Host "Registry value not found. No action."
	exit 0
}