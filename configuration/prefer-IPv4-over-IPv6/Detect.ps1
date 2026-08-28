#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detect if the IPv4 over IPv6 prefix policy is configured.
# Changelog:           2026-08-28: Inital version
# References:          https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/configure-ipv6-in-windows
# Notes:               The value type is checked as well, the TCP/IP stack ignores the value if it is not a REG_DWORD.
#
#=============================================================================================================================

try {

    ##Variable declaration
    $path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\"
    $key = "DisabledComponents"
    $value = 32
    $type = "DWord"

    ##Check reg path
    if (!(Test-Path $path)) {
        #MATCH. Remediate. Path is not existent.
        exit 1
    }

    ##Get current value and type
    $regKey = Get-Item -Path "$path"
    $actualValue = $regKey.GetValue("$key")
    if ($null -eq $actualValue) {
        #MATCH. Remediate. Key is not existent.
        exit 1
    }
    $actualType = $regKey.GetValueKind("$key")
    if (($actualValue -ne $value) -or ($actualType -ne $type)) {
        #MATCH. Remediate. Key is not set to target value or has the wrong type.
        exit 1
    }

    #NO MATCH. Do not remediate. Key is already set to target value.
    exit 0

}
catch {
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}
