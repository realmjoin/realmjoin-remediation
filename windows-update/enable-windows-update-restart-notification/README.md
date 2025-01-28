# Enable Windows Update restart notification

With the latest Windows Update versions, restart notification behaviour for endusers is changed:
- users can set a preference for notifications about pending restarts for updates under Settings > Windows Update > Advanced options > Notify me when a restart is required to finish updating.
- this setting is end-user controlled and **not controlled or configurable by IT administrators (so, no Intune policy available)** (see [End user settings for notifications](https://learn.microsoft.com/en-us/windows/deployment/update/waas-wufb-csp-mdm#user-settings-for-notifications))

This PAR activates the feature "Notify me when a restart is required to finish updating" via registry key.