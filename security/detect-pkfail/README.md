# Check PKfail vulnerability

PKfail is the result of device vendors using as Platform Key a default test key provided by AMI. Since these keys were generated for testing purposes and thus likely supplied as part of AMI UEFI solution, they should be assumed untrusted and compromised.

This script will check if the devices are affected by this vulnerability.
