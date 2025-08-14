#=================================================
# Script Name:         Detect.ps1
# Description:         Chocolatey temp folder check
# Changelog:           2025-08-08: Initial version.
# References:          ...
# Notes:               ...
#=================================================

# Define Variables
$Path = "C:\Windows\Temp\chocolatey"

try {
    if (Test-Path $Path){
        $size = (Get-ChildItem -Path $Path -Recurse | Measure-Object -Property Length -Sum).Sum
        $sizeMB = "{0:N2} MB" -f ($size / 1MB)
        Write-Host "Folder size: $($sizeMB)"
        exit 1
    }
    else{
        Write-Host "Path not found. Nothing to do."      
        exit 0
    }  
}
catch {
    # replace new-line with space
    $errMsg = $_.Exception.Message.replace("`n"," ")
    Write-Error $errMsg
    exit 1
}