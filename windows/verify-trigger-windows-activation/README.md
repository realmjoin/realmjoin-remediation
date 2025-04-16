# Verify and trigger Windows activation

Checks if Windows is activated. If not:
- checks if Windows key is present in BIOS
    - remediation tries to activate via key from BIOS
- no key present
    - cleans-up possible existing MAK key (e.g.: ISOs from the Volume Licensing Service Center (VLSC) can contain a type of key known as a Generic Volume License Key (GVLK), these GVLKs are essentially dummy keys that prompt the system to seek out a Key Management Service (KMS) server for activation). For this case, please provide an activation key via Intune policy or enter manually on the device.