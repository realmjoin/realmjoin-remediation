# Enable Certificate Padding Check
Configure WinVerifyTrust function to perform strict Windows Authenticode signature verification for PE files.

Addresses CVE-2013-3900: [WinVerifyTrust Signature Validation Vulnerability](https://msrc.microsoft.com/update-guide/en-US/vulnerability/CVE-2013-3900)

Sets the following registry keys:

- path: HKEY_LOCAL_MACHINE\Software\Microsoft\Cryptography\Wintrust\Config 
  - name: EnableCertPaddingCheck
  - value: 1
- path: HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Cryptography\Wintrust\Config
  - name: EnableCertPaddingCheck
  - value: 1

## Background
Attackers could modify an existing signed executable file and add malicious code without invalidating the signature.
This additional check is an opt-in feature supported on Windows 10 and Windows 11. When enabled, Windows Authenticode signature verification will no longer allow extraneous information in the WIN_CERTIFICATE structure and recognize non-compliant binaries as signed. This may impact some installers (shows a warning window). All in all, impact should be low. 

(see: [WinVerifyTrust Signature Validation Vulnerability](https://msrc.microsoft.com/update-guide/en-US/vulnerability/CVE-2013-3900))
  
Microsoft also says: "As a best practice, we encourage customers to apply all the latest security updates for better protection. In addition, Defender for Endpoint and Microsoft Defender antivirus can detect and block the domains and files involved with this threat."

(see: [10-year-old Windows bug with 'opt-in' fix exploited in 3CX attack](https://www.bleepingcomputer.com/news/microsoft/10-year-old-windows-bug-with-opt-in-fix-exploited-in-3cx-attack/))