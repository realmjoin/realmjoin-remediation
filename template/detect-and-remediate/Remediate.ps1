#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Remediate problem...
# Changelog:           2023-01-01: Bug fixing.
# References:          ...
# Notes:               ...
#
#=============================================================================================================================

try {
    # do some crazy stuff
    Write-Host "Problem fixed!"
    exit 0
} catch {
    # error occured
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}