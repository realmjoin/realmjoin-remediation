#=============================================================================================================================
#
# Script Name:     Remediate-ResetBranchCacheRequired.ps1
# Description:     Reset Branch Cache
#
#=============================================================================================================================

Import-Module (Get-ItemPropertyValue -Path "Registry::HKLM\SOFTWARE\RealmJoin\Variables" -Name RealmjoinCraftSupportModulePath)

# get current state
$state = Get-BCDataCache
$state.CurrentSizeOnDiskAsNumberOfBytes
$state.MaxCacheSizeAsNumberOfBytes

try {

    # clear cache
    Clear-BCCache -Force
    Write-Host "CurrentSizeOnDiskAsNumberOfBytes: $($state.CurrentSizeOnDiskAsNumberOfBytes), MaxCacheSizeAsNumberOfBytes: $($state.MaxCacheSizeAsNumberOfBytes)"
    exit 0

} catch {

    # error occured
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1

}