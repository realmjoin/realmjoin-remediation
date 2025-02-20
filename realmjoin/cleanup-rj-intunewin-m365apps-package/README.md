# Cleanup RealmJoin IntuneWin M365 Apps for Enterprise Package

If you want to switch from the RealmJoin Intune package for M365 Apps for Enterprise to a RealmJoin choco deployment (via RealmJoin agent), you can simply unassign the Intune package and reassign the Realmjoin-based package. The M365 Apps package will be executed by RealmJoin but should succeed without actually reinstalling Office.

However, for a full cleanup, the RjImeHost user part should be deleted.

This Remediation deletes the RjImeHost user part of the RealmJoin IntuneWin M365 Apps for Enterprise Package.
