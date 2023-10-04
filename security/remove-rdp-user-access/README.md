# Remove RDP User access

Will detect if the current user of a client is member of the Remote Desktop users group and output the username in the format "AzureAD\FirstnameLastname".
The remediation script removes the user from this group. It uses the SID of the group (in contrast to the groupname) and does not need to be localized.