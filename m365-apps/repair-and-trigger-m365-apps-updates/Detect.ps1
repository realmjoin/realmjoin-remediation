#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detect if Office is installed, if "Click to Run Service" is running and trigger update
# Changelog:           2023-11-14: Initial version
#                      2025-01-17: Added reset of UpdateDetectionLastRunTime
#                      2025-01-24: Added check for updates ready to apply
#
#=============================================================================================================================

# define Variables
$curSvcStat, $svcCTRSvc, $errMsg = "", "", ""
$OfficeC2RClientPath = Join-Path $env:ProgramFiles "\Common Files\microsoft shared\ClickToRun\"
$OfficeC2RClientProcess = Join-Path $OfficeC2RClientPath "OfficeC2RClient.exe"
$OfficeC2RClientArgs = "/update user forceappshutdown=false displaylevel=false"
$OfficeC2RClientArgsReadyToApply = "/update user forceappshutdown=false displaylevel=true promptupdateuser=true"

$pathUpdateDetectionLastRunTime = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Updates\"
$nameUpdateDetectionLastRunTime = "UpdateDetectionLastRunTime"

#If there are updates already downloaded and ready to apply the new Office Verison
$pathReadyToApply = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Updates\"
$pathReadyToApplyName = "UpdatesReadyToApply"

# functions
Function Test-RegistryKey {
    param (
        [parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]$Path,
        [parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]$Value
    )
    
    try {
      Get-ItemProperty -Path $Path -ErrorAction Stop | Select-Object -ExpandProperty $Value -ErrorAction Stop | Out-Null
      return $true
    } catch {
      return $false
    }
  
}

Function Test-RegistryValue {
    param (
        [parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]$Path,
        [parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]$Value
    )
    
    try {
      $Value = Get-ItemPropertyValue -Path $Path -Name $Value -ErrorAction Stop
      return $Value
    } catch {
      return $false
    }
  
}
 

if (-not (Test-Path -Path 'HKLM:\Software\Microsoft\Office\16.0')) {
    Write-Host "Office 16.0 (or greater) not present on this machine"
    exit 0   
} 

try {        
    $svcCTRSvc = Get-Service "ClickToRunSvc"
    $curSvcStat = $svcCTRSvc.Status
} catch {    
    $errMsg = $_.Exception.Message
    Write-Host $errMsg
    exit 1
}

if ($curSvcStat -eq "Running") {
    Write-Host $curSvcStat
    if (Test-Path $OfficeC2RClientProcess) {
        # reset UpdateDetectionLastRunTime to let service search for updates directly
        if(Test-RegistryKey $pathUpdateDetectionLastRunTime $nameUpdateDetectionLastRunTime) {
            Remove-ItemProperty -Path $pathUpdateDetectionLastRunTime -Name $nameUpdateDetectionLastRunTime -Force | Out-Null
        }
        # check if there are updates ready to apply
        if((Test-RegistryValue $pathReadyToApply $pathReadyToApplyName) -gt "0") {
            Write-Host "Updates ready to apply"
            # start OfficeC2RClientProcess
            Set-Location -Path $OfficeC2RClientPath
            Start-Process $OfficeC2RClientProcess $OfficeC2RClientArgsReadyToApply
            exit 0
        }

        # start OfficeC2RClientProcess
        Set-Location -Path $OfficeC2RClientPath
        Start-Process $OfficeC2RClientProcess $OfficeC2RClientArgs
        exit 0
    }
    else {
        Write-Error "OfficeC2RClient.exe not found!"
        exit 1
    }                 
}
else {
    if ($curSvcStat -eq "Stopped") {
        Write-Host $curSvcStat
        exit 1     
    }
    else {
        Write-Host "Error: " + $errMsg
        exit 1
    }
}