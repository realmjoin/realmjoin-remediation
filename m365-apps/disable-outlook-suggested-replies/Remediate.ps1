#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Disable feature
#
#=============================================================================================================================

# define Variables
$path = "HKCU:\Software\Microsoft\Office\Outlook\Settings\Data"
$usr = whoami /upn
$value = $usr + "_EnableSuggestedReplies"

try {
    $curString = Get-ItemPropertyValue -Path $path -Name $value
    $string = $curString.replace('"value":"true"','"value":"false"')
    Set-ItemProperty -Path $path -Name $value -Value $string
} catch {
    # error occured
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}