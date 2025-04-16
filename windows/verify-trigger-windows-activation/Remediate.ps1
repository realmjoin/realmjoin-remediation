#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Activate key in BIOS or uninstall stale key
#
#=============================================================================================================================

try {
    if (($keyBIOS = Get-CimInstance -ClassName SoftwareLicensingService | Select-Object -ExpandProperty OA3xOriginalProductKey)) {
		Write-Host "Activating key present in BIOS."	
        changepk.exe /Productkey $keyBIOS
		exit 0
	} else {
		Write-Host "Uninstall stale key. Please provide new one via Intune policy or enter manually."
        # Remove key and suppress dialog via //b
        slmgr.vbs //b -upk
		exit 0
	}    
} catch {
    # error occured
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}