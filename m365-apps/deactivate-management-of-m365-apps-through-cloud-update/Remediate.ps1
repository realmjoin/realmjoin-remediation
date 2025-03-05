#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Detect if device is onboarded and locked to M365 Apps Cloud Update. If onboarded/locked, remediation starts and sets a registry key to offboard it.
# Changelog:           2025-03-05: Fixes for some scenarios
#                      2025-02-14: Improved handling to also support "choose your own" channel scenarios
#                      2025-02-10: Initial version
#
#=============================================================================================================================

try {
    # Variable declaration
    ## General
    $cloudUpdatePath = "HKLM:\SOFTWARE\Policies\Microsoft\cloud\office\16.0\Common\officeupdate"
    $cloudUpdatePathExists = $null

    ## IgnoreGPO
    $keyNameIgnoreGPO = "ignoregpo"
    $keyTypeIgnoreGPO= "DWORD" # needed for remediation
    $keyExistsIgnoreGPO = $null
    $desiredValueIgnoreGPO = "0"
    $actualValueIgnoreGPO = $null
    $valueIsWrongIgnoreGPO = $null

    ## UpdateBranch
    $keyNameUpdateBranch = "updatebranch"
    $keyExistsUpdateBranch = $null

    ## UpdatePath
    $keyNameUpdatePath = "updatepath"
    $keyExistsUpdatePath = $null    

    # Functions
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
    $cloudUpdatePathExists = Test-Path -Path $cloudUpdatePath
    if (-not $cloudUpdatePathExists) {
        # Not onboarded to Cloud Update - all good
        Write-Host "Machine not ONBOARDED to Cloud Update - OK."
    } else {
        # Onboarded to Cloud Update - checking reg keys
        Write-Host "Fixing reg keys to make sure Cloud Update keys are ingored ..."
        ## IgnoreGPO
        $actualValueIgnoreGPO = Test-RegistryValue -Path $cloudUpdatePath -Key $keyNameIgnoreGPO
        if ($desiredValueIgnoreGPO -ne $actualValueIgnoreGPO ) {
            $valueIsWrongIgnoreGPO = $true
        } else {
            $valueIsWrongIgnoreGPO = $false
        }
        if ($valueIsWrongIgnoreGPO) {
            Write-Host "Setting Key $keyNameIgnoreGPO to $desiredValueIgnoreGPO"
            Set-ItemProperty -Path $cloudUpdatePath -Name $keyNameIgnoreGPO -Value $desiredValueIgnoreGPO -Type $keyTypeIgnoreGPO -Force
        }

        ## UpdateBranch
        $keyExistsUpdateBranch = Test-RegistryKey -Path $cloudUpdatePath -Key $keyNameUpdateBranch
        if ($keyExistsUpdateBranch) {
            Write-Host "Removing Key $keyNameUpdateBranch"
            Remove-ItemProperty -Path $cloudUpdatePath -Name $keyNameUpdateBranch -Force
        }

        ## UpdatePath
        $keyExistsUpdatePath = Test-RegistryKey -Path $cloudUpdatePath -Key $keyNameUpdatePath
        if ($keyExistsUpdatePath) {
            Write-Host "Removing Key $keyNameUpdatePath"
            Remove-ItemProperty -Path $cloudUpdatePath -Name $keyNameUpdatePath -Force
        }
    }

    # Success if no errors occurs
    exit 0
}
catch {
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}