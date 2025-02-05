# Trigger TPM Health Attestation Certificate retrieval
Trigger TPM Health Attestation Certificate retrieval via running scheduled task Tpm-HASCertRetr.
This allows proofing the health state of a device. Might solve non-compliance concerning BitLocker, Secure Boot and Code integrity.

## Possible issues in Event log
A possible issue that can be fixed via this PAR might be visible via Event log > System > filter for source "TPM-WMI": `The Device Health Certificate provisioning could not connect to has.spserv.microsoft.com.`

## Caution!
Designed for **on-demand execution on single devices**.