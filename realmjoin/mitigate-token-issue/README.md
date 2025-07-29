# Detect if RealmJoin lost authentication and is not working properly due to token issues

Checks if RealmJoin token file (`token2.dat` or `msal_cache.dat`) last modified date is more than 48 hours older than last PRT update time of machine. If yes token file is deleted.