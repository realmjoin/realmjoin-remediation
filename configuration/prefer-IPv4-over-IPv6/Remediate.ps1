#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Prefer IPv4 over IPv6 in prefix policies.
# Changelog:           2026-08-28: Inital version
# References:          https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/configure-ipv6-in-windows
# Notes:               A reboot is required for the setting to take effect.
#
#=============================================================================================================================

##Fail loud, registry errors are non-terminating by default and would be reported as a successful remediation
$ErrorActionPreference = "Stop"

try {

    ##Variable declaration
    $path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\"
    $key = "DisabledComponents"
    $value = 32
    $type = "DWord"

    ##Check reg path and create path if missing
    if (!(Test-Path $path)) {
        New-Item -Path "$path" -Force | Out-Null
    }

    ##Create key and set value
    Set-ItemProperty -Path "$path" -Name "$key" -Value $value -Type "$type" -Force

    ##Verify the write, the value is only honored as a REG_DWORD
    $regKey = Get-Item -Path "$path"
    if (($regKey.GetValue("$key") -ne $value) -or ($regKey.GetValueKind("$key") -ne $type)) {
        Write-Error "Registry value $key was not applied as $type with value $value."
        exit 1
    }

    #Succes if no errors occured.
    exit 0

}
catch {
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}
