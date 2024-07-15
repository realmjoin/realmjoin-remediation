#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Fix broken Windows Task Scheduler. 
#                      For every key under HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\: Get the GUID out of the ID value, check if the GUID exists under HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\.
#                      If NOT, delete the whole key under HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\.
#
#=============================================================================================================================

try {
    $basePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\"
    $fullPath = Join-Path $basePath "*"
    $childItems = Get-ChildItem -Path $fullPath -EA SilentlyContinue

    # Looping through all childs
    foreach ($childItem in $childItems) {
        # Extract the scheduled tasks GUID from the ID
        $taskId = (Get-ItemProperty -Path $childItem.PSPath -Name "ID" -EA SilentlyContinue).ID 
        if ($taskId) {
            $taskGuid = $taskId.TrimStart("\")
        }
    
        # Verify if task GUID exists under HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\
        $taskPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\$taskGuid"  
        ## If the GUID can't be found under HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\, remove the whole subkey
        if (!(Test-Path $taskPath)) {
            Write-Output "Deleting subkey $($childItem.Name)"
            Remove-Item -Path $childItem.PSPath -Recurse

            # If present, also delete any leftover files with the identical name under directory C:\Windows\System32\Tasks
            $taskName = $childItem.PSChildName
            $taskFile = Join-Path "C:\Windows\System32\Tasks" $taskName
            if (Test-Path $taskFile) {
                Write-Output "Removing file $taskFile"
                Remove-Item -Path $taskFile -Force
            }
        }
    }
    exit 0
} catch {
    # error occured
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}