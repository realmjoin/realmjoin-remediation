# Detect if Windows TaskScheduler is broken and needs to be fixed

Checks if the Windows Task Scheduler, is broken due to orphaned subkeys in the registry.
Detection is done by a simple `Get-ScheduledTask`. If that command throws an error, the tasks cheduler is broken.
The remediation then searches for orphaned subkeys int he registry and deletes them to fix the task scheduler.
