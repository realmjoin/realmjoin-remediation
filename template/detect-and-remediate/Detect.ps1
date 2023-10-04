#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detect problem...
# Changelog:           2023-01-01: Bug fixing.
# References:          ...
# Notes:               ...
#
#=============================================================================================================================

# define Variables
$check = $true

if ($check) {
    # problem detected
    Write-Host "Problem detected!"
    exit 1
} else {
    # no problem detected
    Write-Host "No problem detected!"
    exit 0
}