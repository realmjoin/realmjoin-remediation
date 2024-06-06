#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detect if Branch Cache needs to be cleared
#
#=============================================================================================================================


# get current state, catch BranchCache needs reset
try {
    $state = Get-BCDataCache -EA Stop
} catch {
    # problem detected
    Write-Host "BranchCache broken, needs Reset"
    exit 1
}

# BrancCache works, check if Clear needed
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