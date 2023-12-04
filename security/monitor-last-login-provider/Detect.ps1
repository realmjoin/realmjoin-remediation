#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Read and compare value from LastLoggedOnProvider
#
#=============================================================================================================================

# main
$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI"
$registryKey = "LastLoggedOnProvider"

$lastLoggedOnProvider = (Get-ItemProperty -Path $registryPath).$registryKey

switch ($lastLoggedOnProvider) {                        
    "{8AF662BF-65A0-4D0A-A540-A338A999D36F}" { Write-Output "WHfB - Facial Recognition"; exit 0 }
    "{BEC09223-B018-416D-A0AC-523971B639F5}" { Write-Output "WHfB - Fingerprint"; exit 0 } 
    "{D6886603-9D2F-4EB2-B667-1971041FA96B}" { Write-Output "WHfB - PIN"; exit 0 }
    "{C885AA15-1764-4293-B82A-0586ADD46B35}" { Write-Output "WHfB - Iris"; exit 0 } 
    "{F8A1793B-7873-4046-B2A7-1F318747F427}" { Write-Output "FIDO"; exit 0 }
    "{60B78e88-EAD8-445C-9CFD-0B87f74EA6CD}" { Write-Output "Password"; exit 1 } 
    "{8FD7E19C-3BF7-489B-A72C-846AB3678C96}" { Write-Output "Smartcard Credential Provider"; exit 1 } 
    "{94596c7e-3744-41ce-893e-bbf09122f76a}" { Write-Output "Smartcard PIN Provider"; exit 1 }
    default { Write-Output "Unknown: $($_)"; exit 1  }                        
}