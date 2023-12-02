# Trigger updates for Defender via Update-MpSignature

Triggers Defender updates using Update-MpSignature when status of "DefenderSignaturesOutOfDate" is true or updates have never been executed (during deployment/OOBE).

Execution status of inital trigger is stored in registry:
- path: `HKLM:\SOFTWARE\RealmJoin\Custom\PAR`
- name: `TriggeredDefenderUpdatesInOOBE`
- value: `1`