# Detect if BranchCache needs to be resetted or cleared

Checks if BranchCache is working, if not `Reset-BC -Force` is triggered.  
Otherwise checks if `MaxCacheSizeAsNumberOfBytes` is above 85%. If yes, `Clear-BCCache -Force` is triggered.