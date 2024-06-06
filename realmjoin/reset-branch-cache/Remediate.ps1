#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Reset Branch Cache
#
#=============================================================================================================================


# get current state, catch BranchCache needs reset
$needsReset = $false
try {
    $state = Get-BCDataCache -EA Stop
} catch {
    $needsReset = $true
}


try {
    if ($needsReset) {
        # reset cache
        Reset-BC -Force
    } else {
        # clear cache
        Clear-BCCache -Force
        Write-Host "CurrentSizeOnDiskAsNumberOfBytes: $($state.CurrentSizeOnDiskAsNumberOfBytes), MaxCacheSizeAsNumberOfBytes: $($state.MaxCacheSizeAsNumberOfBytes)"
    }
    exit 0
} catch {
    # error occured
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}