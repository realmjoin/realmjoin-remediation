#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Set registry keys to hide toggle
#
#=============================================================================================================================

# define Variables
$RegPath = "HKCU:\Software\Microsoft\Office\16.0\Outlook\Options\General"
$RegName = "HideNewOutlookToggle"
$RegValue = 1 # 1 = Hide | 0 = Show

try {
    
    if (!(Test-Path $RegPath)) {
        New-Item -Path $RegPath -Force
        Set-ItemProperty -Path $RegPath -Name $RegName -Type DWord -Value $RegValue -Force
        Write-Host "$RegName is set to $RegValue"
    } else {
        Set-ItemProperty -Path $RegPath -Name $RegName -Type DWord -Value $RegValue -Force
        Write-Host "$RegName is set to $RegValue"
    }

    exit 0

} catch {
    # error occured
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}