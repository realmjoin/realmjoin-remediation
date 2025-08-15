#=================================================
# Script Name:         Remediate.ps1
# Description:         Chocolatey temp folder clean-up
# Changelog:           2025-08-08: Initial version.
# References:          ...
# Notes:               ...
#=================================================

# Define Variables
$Path = "C:\Windows\Temp\chocolatey"
$olderThan = 7  # days

try {
    # current size
    $sizeBefore = (Get-ChildItem -Path $Path -Recurse | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    $sizeMBBefore = "{0:N2} MB" -f ($sizeBefore / 1MB)

    $CurrentDate = Get-Date
    $dirs = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue | Get-ChildItem -Directory -ErrorAction SilentlyContinue
    foreach ($dir in $dirs) {
        $Age = $CurrentDate - $dir.CreationTime
        Write-Host "Check: $($dir.FullName) (age: $($Age.Days) days)"
        if ($Age.Days -gt $olderThan) {
            Write-Host "Deleting: $($dir.FullName)"
            Remove-Item -Path $dir.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    # re-check size and calculate cleaned amount
    $sizeAfter = (Get-ChildItem -Path $Path -Recurse | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    $sizeMBAfter = "{0:N2} MB" -f ($sizeAfter / 1MB)
    $sizeCleaned = $sizeBefore - $sizeAfter
    $sizeMBCleaned = "{0:N2} MB" -f ($sizeCleaned / 1MB)

    Write-Host "Cleaned: $($sizeMBCleaned) (before: $($sizeMBBefore), after: $($sizeMBAfter))"
    exit 0   
}
catch {
    # replace new-line with space
    $errMsg = $_.Exception.Message.replace("`n"," ")
    Write-Error $errMsg
    exit 1
}