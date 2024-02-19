# Detect WinRE Patch Installation Issue


(https://support.microsoft.com/en-us/topic/kb5034441-windows-recovery-environment-update-for-windows-10-version-21h2-and-22h2-january-9-2024-62c04204-aaa5-4fee-a02a-2fdea17075a8)

Detect if a client will run into the Windows update installation issue.
This can have several reasons. Microsoft recommends to extend the WinRE partition.
But our perceptions are that this will cover not all isssues.
So we had to detect the devices with the ErrorCode "0x8024200B" and work on further remediation.