# Manage Remote Desktop Users group

Manages the local **Remote Desktop Users** group (SID: *S-1-5-32-555*) on Entra-joined Windows devices to contain Entra accounts that have been active within the last 8 weeks. Inactive Entra accounts are removed; missing active accounts are added.

Membership is compared, updated, and verified by SID. The scripts use each profile's canonical Entra SID from the Windows ProfileList and don't depend on profile folder names, UPN translation, or cached account-name resolution. Local and Active Directory members of the group are left unchanged.

For allowing RDP access, additional Intune configuration is required like:

- Allow users to connect remotely by using Remote Desktop Services
- Require user authentication for remote connections by using Network Level Authentication
- Firewall Rule Policy that allows RDP inbound traffic

**Caution:** Enabling inbound RDP increases the attack surface. This should only be used when the associated risks are fully understood and explicitly accepted.
