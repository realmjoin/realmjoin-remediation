#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Output SafeGuardID, SafeGuardReason, osVersion, model, manufacturer
#
#=============================================================================================================================

# read Safe Guard Hold ID from registry
function Get-SafeGuardHoldID {
    $TargetVersionUpgradeExperienceIndicators = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\TargetVersionUpgradeExperienceIndicators"
    foreach ($TargetVersionUpgradeExperienceIndicator in $TargetVersionUpgradeExperienceIndicators){
        $GatedBlockId = $TargetVersionUpgradeExperienceIndicator.GetValue("GatedBlockId")
        
        if ($GatedBlockId){
            if ($GatedBlockId -ne "None"){
                $SafeGuardID  = $GatedBlockId
            }             
        }

    }

    if (!($SafeGuardID)){
        $SafeGuardID = "NONE"
    }
    
    return $SafeGuardID
}


# read Safe Guard Hold reason from registry
function Get-SafeGuardHoldReason {
    $TargetVersionUpgradeExperienceIndicators = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\TargetVersionUpgradeExperienceIndicators"
    foreach ($TargetVersionUpgradeExperienceIndicator in $TargetVersionUpgradeExperienceIndicators){
        $GatedBlockReason = $TargetVersionUpgradeExperienceIndicator.GetValue("GatedBlockReason")
        
        if ($GatedBlockReason){
            if ($GatedBlockReason -ne "None"){
                $SafeGuardReason  = $GatedBlockReason
            }             
        }

    }

    if (!($SafeGuardReason)){
        $SafeGuardReason = "NONE"
    }
    
    return $SafeGuardReason
}

# read client details
$computerInfo = Get-ComputerInfo
$model = $computerInfo.CsModel
$manufacturer = $computerInfo.CsManufacturer
$osVersion = $computerInfo.OsVersion

$SafeGuardID = Get-SafeGuardHoldID
$SafeGuardReason = Get-SafeGuardHoldReason

$output = "$SafeGuardID, $SafeGuardReason, $osVersion, $model, $manufacturer"
Write-Host $output

if ($SafeGuardID -match "NONE"){ 
    # no Safe Guard Hold
    exit 0
} else {
    # Safe Guard Hold found
    exit 1
}