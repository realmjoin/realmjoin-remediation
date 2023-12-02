# Trigger updates for Defender via Update-MpSignature

Triggers Defender updates using Update-MpSignature when status of "DefenderSignaturesOutOfDate" is true or updates have never been executed (during deployment/OOBE).

Execution status of inital trigger (OOBE) is stored in registry:
- path: `HKLM:\SOFTWARE\RealmJoin\Custom\PAR`
- name: `TriggeredDefenderUpdatesInOOBE`
- value: `1`

... with execution time:

- path: `HKLM:\SOFTWARE\RealmJoin\Custom\PAR`
- name: `TriggeredDefenderUpdatesInOOBETime`

Last execution time outside inital deployment is stored in:

- path: `HKLM:\SOFTWARE\RealmJoin\Custom\PAR`
- name: `TriggeredDefenderUpdatesTime`