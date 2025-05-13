# Trigger Microsoft Store App Updates

Currently, ["winget upgrade" does not update Microsoft Store apps](https://github.com/microsoft/winget-cli/issues/2854). This PAR invokes method "UpdateScanMethod" of class [MDM_EnterpriseModernAppManagement_AppManagement01](https://learn.microsoft.com/en-us/windows/win32/dmwmibridgeprov/mdm-enterprisemodernappmanagement-appmanagement01) to trigger search and installation of outstanding Microsoft Store app updates. Afterwards, it checks if "LastScanError" is other than 0. If so, it outputs the error.

Designed for distribution a regular basis (e.g.: daily).

Removes scheduled task added by package "RealmJoin Core Settings" if found.