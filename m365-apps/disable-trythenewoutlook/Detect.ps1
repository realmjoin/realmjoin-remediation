#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detect if Outlook is installed and value of registry key
#
#=============================================================================================================================

# define Variables
$RegPath = "HKCU:\Software\Microsoft\Office\16.0\Outlook\Options\General"
$RegName = "HideNewOutlookToggle"
$RegValue = 1 # 1 = Hide | 0 = Show

#Function to check if Outlook is installed
function CheckOutlook {
    $Outlook = Get-ItemProperty HKLM:\SOFTWARE\Classes\Outlook.Application -ErrorAction SilentlyContinue
    if ($null -eq $Outlook) {
        Write-Host "Outlook is not installed! No action needed."
        exit 0
    } else {
        Write-Host "Outlook is installed!"
    }    
}

#Call the function
CheckOutlook

#Check if the registry key exists and if the value is set to $value
$RegValueCheck = (Get-ItemProperty -Path $RegPath -Name $RegName -ErrorAction Ignore).$RegName
if ($RegValueCheck -eq $RegValue) {
    Write-Host "Toggle is hidden. No action needed."
    exit 0
} else {
    Write-Host "Toggle is not hidden."
    exit 1
}