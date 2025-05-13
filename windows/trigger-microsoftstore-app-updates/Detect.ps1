#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Invoke method "UpdateScanMethod" of class "MDM_EnterpriseModernAppManagement_AppManagement01"
#
#=============================================================================================================================

try {
	# clean-up old scheduled task
	$taskName = "GKTriggerWindowsStoreAppUpdates"
	if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue){
		Unregister-ScheduledTask -TaskName $TaskName -Confirm $false
	}

	# trigger updates
    Get-CimInstance -Namespace "root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" | Invoke-CimMethod -MethodName "UpdateScanMethod" | Out-Null
	
	# check result and possible error
	Start-Sleep -Seconds 3
	$lastScanError = (Get-CimInstance -Namespace "root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01").LastScanError

	if($lastScanError -ne 0) {
		Write-Host "Triggered updates: $(Get-Date -Format "yyyy-MM-dd HH:mm (K)"), LastScanError: $($lastScanError)"
		exit 1
	} else {
		Write-Host "Triggered updates: $(Get-Date -Format "yyyy-MM-dd HH:mm (K)")"
		exit 0
	}
} catch {
    # error occured
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}