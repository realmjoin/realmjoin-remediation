#=============================================================================================================================
#
# Script Name:     Detect-ResetBranchCacheRequired.ps1
# Description:     Detect if Branch Cache needs to be cleared
#
#=============================================================================================================================

Import-Module (Get-ItemPropertyValue -Path "Registry::HKLM\SOFTWARE\RealmJoin\Variables" -Name RealmjoinCraftSupportModulePath)

# get current state
$state = Get-BCDataCache
$state.CurrentSizeOnDiskAsNumberOfBytes
$state.MaxCacheSizeAsNumberOfBytes

if ($state.CurrentSizeOnDiskAsNumberOfBytes -gt ($state.MaxCacheSizeAsNumberOfBytes * .85)) {
    # problem detected
    Write-Host "CurrentSizeOnDiskAsNumberOfBytes: $($state.CurrentSizeOnDiskAsNumberOfBytes), MaxCacheSizeAsNumberOfBytes: $($state.MaxCacheSizeAsNumberOfBytes)"
    exit 1
} else {
    # no problem detected
    Write-Host "CurrentSizeOnDiskAsNumberOfBytes: $($state.CurrentSizeOnDiskAsNumberOfBytes), MaxCacheSizeAsNumberOfBytes: $($state.MaxCacheSizeAsNumberOfBytes)"
    exit 0
}