# Detect if RealmJoin lost authentication and is not working properly due to token issues

Checks if RealmJoin token2.dat last modified date is more than 48 hours older than last PRT update time of machine. If yes, RealmJoin.exe is killed and token2.dat is deleted.