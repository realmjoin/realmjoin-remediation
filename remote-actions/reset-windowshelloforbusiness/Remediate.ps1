#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Delete WHfB Container
#
#=============================================================================================================================

try {
    
    Write-Host "Running certutil.exe -DeleteHelloContainer"
    Start-Process -FilePath "certutil.exe" -ArgumentList "-DeleteHelloContainer" -Wait
    exit 0

} catch {
    # error occured
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}