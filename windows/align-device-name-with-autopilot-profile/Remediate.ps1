#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Rename hostname based on device name template
# Changelog:           2025-11-12: Inital version
#
#=============================================================================================================================

# define Variables
$hostname = $env:COMPUTERNAME
$serial = (Get-WmiObject -Class Win32_BIOS -ErrorAction SilentlyContinue).SerialNumber
$nameTemplateRegPath = "HKLM:\SOFTWARE\Microsoft\Provisioning\Diagnostics\AutoPilot\"
$nameTemplateRegName = "CloudAssignedDeviceName"
$templateVariable = "%SERIAL%"
$maxHostnameLength = 15

try {

    # get Autopilot device name template
    $nameTemplate = (Get-ItemPropertyValue -Path $nameTemplateRegPath -Name $nameTemplateRegName -ErrorAction SilentlyContinue)

    # insert SN for templateVariable
    $desiredName = $nameTemplate.Replace($templateVariable, $serial)
    # shorten SN if too long
    if ($desiredName.Length -gt $maxHostnameLength)  {
        $namePrefix = $nameTemplate.Replace($templateVariable, "")
        $maxSerialLength = $maxHostnameLength - $namePrefix.Length
        $trimmedSerial = $serial.Substring($serial.Length - $maxSerialLength)
        $desiredName = $nameTemplate.Replace($templateVariable, $trimmedSerial)
    }

    # apply hostname
    Rename-Computer -NewName $desiredName -Force
    Write-Host "Renamed. From: $($hostname), To: $($desiredName)"
    exit 0

} catch {
    # error occured
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}