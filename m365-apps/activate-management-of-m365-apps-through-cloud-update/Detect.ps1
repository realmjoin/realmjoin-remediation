#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detect if device is onboarded and locked to M365 Apps Cloud Update. If onboarded but not locked, remediation starts and sets a registry key to lock it.
# Changelog:           2025-02-10: Initial version
#
#=============================================================================================================================

try {
    # Variable declaration
    $cloudUpdatePath = "HKLM:\SOFTWARE\Policies\Microsoft\cloud\office\16.0\Common\officeupdate"
    $cloudUpdateKeyName = "ignoregpo"
    $cloudUpdateKeyType = "DWORD" # needed for remediation
    $cloudUpdateValueShould = "1"
    

    # Functions
    Function Test-RegistryPath {
        param (
            [parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]$Path
        )
        
        try {
            Test-Path $Path -ErrorAction Stop | Out-Null
            return $true
        } catch {
            return $false
        }
    }

    Function Test-RegistryKey {
        param (
            [parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]$Path,
            [parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]$Key
        )
        
        try {
            Get-ItemProperty -Path $Path -ErrorAction Stop | Select-Object -ExpandProperty $Key -ErrorAction Stop | Out-Null
            return $true
        } catch {
            return $false
        }
    }

    Function Test-RegistryValue {
        param (
            [parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]$Path,
            [parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]$Key
        )
        
        try {
            $Value = Get-ItemPropertyValue -Path $Path -Name $Key -ErrorAction Stop
            return $Value
        } catch {
            return $false
        }
    }

    # Main
    $cloudUpdateKeyExists = Test-RegistryKey -Path $cloudUpdatePath -Key $cloudUpdateKeyName
    if (-not $cloudUpdateKeyExists) {
        # Not onboarded to Cloud Update - all good
        Write-Host "Machine not ONBOARDED to Cloud Update - OK."
        exit 0   
    } else {
        # Onboarded to Cloud Update - checking reg key value
        $cloudUpdateValueIs = Test-RegistryValue -Path $cloudUpdatePath -Key $cloudUpdateKeyName
        if ($cloudUpdateValueIs -eq $cloudUpdateValueShould) {
            Write-Host "Machine onboarded and LOCKED to Cloud Update - OK."
            exit 0   
        } else {
            Write-Host "Machine is onboarded but not LOCKED to Cloud Update - Remediate."
            exit 1
        }
    }
}
catch {
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}