# Monitor Last Login Provider

Check last login method via registry:
- path: `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI`
- key: `LastLoggedOnProvider`


The following methods will be reported as valid:
- Facial Recognition: {8AF662BF-65A0-4D0A-A540-A338A999D36F}
- Fingerprint: {BEC09223-B018-416D-A0AC-523971B639F5}
- PIN: {D6886603-9D2F-4EB2-B667-1971041FA96B}
- Iris: {C885AA15-1764-4293-B82A-0586ADD46B35}
- FIDO: {F8A1793B-7873-4046-B2A7-1F318747F427}


The following and other/unknows methods will be reported as invalid:
- Password: {60b78e88-ead8-445c-9cfd-0b87f74ea6cd}
- Smartcard Credential Provider: {8FD7E19C-3BF7-489B-A72C-846AB3678C96}
- Smartcard PIN Provider: {94596c7e-3744-41ce-893e-bbf09122f76a}