#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Validates local administrator accounts against RealmJoin LAPS and Windows LAPS policies. Detects unauthorized admins.
# Changes:             2026-02-03: Initial version
#=============================================================================================================================

$debug = $false

function Debug-Message {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Color = ""
    )
    if ($debug) {
        if ($Color -ieq "Red") {
            Write-Host "DEBUG: $Message" -ForegroundColor Red
        }
        elseif ($Color -ieq "Green") {
            Write-Host "DEBUG: $Message" -ForegroundColor Green
        }
        elseif ($Color -ieq "Yellow") {
            Write-Host "DEBUG: $Message" -ForegroundColor Yellow
        }
        else {
            Write-Host "DEBUG: $Message"
        }
    }
}

function Get-LoggedOnUser {
    $userName = ""
    try {
        $userName = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -expand UserName
        if ([string]::IsNullOrEmpty($userName)) {
            $explorerProcess = @(Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" -ErrorAction SilentlyContinue)
            if ($explorerProcess.Count -ne 0) {
                $owner = Invoke-CimMethod -InputObject $explorerProcess[0] -MethodName GetOwner -ErrorAction SilentlyContinue
                if ($null -ne $owner) {
                    $userName = $owner.User
                }
            }
        }
        $userName = $userName -replace ".*\\", ""
    }
    catch { }
    $userName
}

function Get-LocalAdministratorsGroupMembers {
    # Azure AD / Entra ID SIDs to exclude
    $excludedSids = @(
        'S-1-12-1-2086028676-1107472554-2602830233-1605893542',  # Global Administrators
        'S-1-12-1-3024168140-1188258502-3070978446-3066131865'   # Microsoft Entra Joined Device Local Administrator
    )
    
    $enabledAdmins = @()
    $adminGroupMembers = Get-LocalGroupMember -SID "S-1-5-32-544" -ErrorAction SilentlyContinue | Where-Object { $_.SID -notin $excludedSids }
    
    foreach ($member in $adminGroupMembers) {
        # Remove everything before and including backslash
        $userName = $member.Name -replace '^.*\\', ''
        
        try {
            $localUser = Get-LocalUser -Name $userName -ErrorAction SilentlyContinue
            if ($null -eq $localUser -or $localUser.Enabled) {
                $enabledAdmins += $userName
            }
        }
        catch {
            $enabledAdmins += $userName
        }
    }
    
    $enabledAdmins
}

function Get-LocalUserDownLevelLogonFormat {
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserName
    )
    $adminGroup = Get-LocalGroup -SID "S-1-5-32-544"
    Get-WmiObject Win32_GroupUser | Where-Object { $_.GroupComponent -match "Name=`"$adminGroup`"" } | ForEach-Object {
        $user = [regex]::Match($_.PartComponent, '.*Name="([^"]+)"').Groups[1].Value
        if ($user -eq $UserName) {
            $domainName = [regex]::Match($_.PartComponent, '.*Domain="([^"]+)"').Groups[1].Value
            "$domainName\$user"
        }
    }
}

function Convert-RjNamePatternToRegex {
    param (
        [Parameter(Mandatory = $true)]
        [string]$NamePattern
    )
    
    $regexPattern = $NamePattern
    $regexPattern = $regexPattern -replace '\{HEX:([0-9]+)\}', '<!HEX$1!>'
    $regexPattern = $regexPattern -replace '\{DEC:([0-9]+)\}', '<!DEC$1!>'
    $regexPattern = $regexPattern -replace '\{COUNT:([0-9]+)\}', '<!COUNT$1!>'
    $regexPattern = $regexPattern -replace '\{GUID\}', '<!GUID!>'
    $regexPattern = [regex]::Escape($regexPattern)
    $regexPattern = $regexPattern -replace '<!HEX([0-9]+)!>', '[0-9A-Fa-f]{$1}'
    $regexPattern = $regexPattern -replace '<!DEC([0-9]+)!>', '[0-9]{$1}'
    $regexPattern = $regexPattern -replace '<!COUNT([0-9]+)!>', '[0-9]{$1}'
    $regexPattern = $regexPattern -replace '<!GUID!>', '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
    "^$regexPattern`$"
}

function Get-RjLapsAccountDefinitions {
    param (
        [Parameter(Mandatory = $true)]
        [object]$LocalAdminManagement
    )
    
    $accountDefs = @()
    
    if ($null -eq $LocalAdminManagement -or $LocalAdminManagement.Inactive -eq $true) {
        return $accountDefs
    }
    
    if ($null -ne $LocalAdminManagement.EmergencyAccount) {
        $accountDefs += @{
            Type = "EmergencyAccount"
            NamePattern = $LocalAdminManagement.EmergencyAccount.NamePattern
            DisplayName = $LocalAdminManagement.EmergencyAccount.DisplayName
            RegexPattern = Convert-RjNamePatternToRegex -NamePattern $LocalAdminManagement.EmergencyAccount.NamePattern
        }
    }
    
    if ($null -ne $LocalAdminManagement.PrivilegedAccount) {
        $accountDefs += @{
            Type = "PrivilegedAccount"
            NamePattern = $LocalAdminManagement.PrivilegedAccount.NamePattern
            DisplayName = $LocalAdminManagement.PrivilegedAccount.DisplayName
            RegexPattern = Convert-RjNamePatternToRegex -NamePattern $LocalAdminManagement.PrivilegedAccount.NamePattern
        }
    }
    
    if ($null -ne $LocalAdminManagement.SupportAccount) {
        $accountDefs += @{
            Type = "SupportAccount"
            NamePattern = $LocalAdminManagement.SupportAccount.NamePattern
            DisplayName = $LocalAdminManagement.SupportAccount.DisplayName
            RegexPattern = Convert-RjNamePatternToRegex -NamePattern $LocalAdminManagement.SupportAccount.NamePattern
        }
    }
    
    $accountDefs
}

function Test-RjLapsAccountManipulation {
    param (
        [Parameter(Mandatory = $true)]
        [array]$AdminGroupMembers,
        [Parameter(Mandatory = $true)]
        [array]$AccountDefinitions
    )
    
    $manipulatedAccounts = @()
    $legitimateAccounts = @()
    
    foreach ($accountDef in $AccountDefinitions) {
        $matchingAccounts = @()
        
        foreach ($admin in $AdminGroupMembers) {
            if ($admin -match $accountDef.RegexPattern) {
                $localUser = Get-LocalUser -Name $admin -ErrorAction SilentlyContinue
                if ($null -ne $localUser) {
                    $userFullName = $localUser.FullName
                    $userDescription = $localUser.Description
                    $expectedFullName = "$($accountDef.DisplayName) $admin"
                    
                    if ($userFullName -eq $expectedFullName -and $userDescription -match 'Auto-generated by RealmJoin') {
                        $matchingAccounts += $admin
                    }
                }
            }
        }
        
        if ($matchingAccounts.Count -gt 1) {
            $sortedAccounts = $matchingAccounts | ForEach-Object {
                $localUser = Get-LocalUser -Name $_ -ErrorAction SilentlyContinue
                [PSCustomObject]@{
                    Name = $_
                    Description = $localUser.Description
                    PasswordLastSet = $localUser.PasswordLastSet
                }
            } | Sort-Object PasswordLastSet
            
            $legitimateAccounts += $sortedAccounts[0].Name
            
            for ($i = 1; $i -lt $sortedAccounts.Count; $i++) {
                $manipulatedAccounts += $sortedAccounts[$i].Name
            }
        }
        elseif ($matchingAccounts.Count -eq 1) {
            $legitimateAccounts += $matchingAccounts[0]
        }
    }
    
    $legitimateAccounts = $legitimateAccounts | Select-Object -Unique
    $manipulatedAccounts = $manipulatedAccounts | Select-Object -Unique
    
    @{
        ManipulatedAccounts = $manipulatedAccounts
        LegitimateAccounts = $legitimateAccounts
    }
}

function Get-RjAdminPolicy {

    # ExitCode 42: Failed to get current logged on user
    # ExitCode 43: Failed to register/create scheduled task
    # ExitCode 44: Created task could not be evaluated for its result
    # ExitCode 45: RealmJoin not installed (set by caller, not this function)

    $userScriptPath = $(Join-Path -Path "$env:SystemRoot\tracing" -ChildPath "ReadingRJPolicy.ps1")
    $pathResultFile = $(Join-Path -Path "$env:SystemRoot\tracing" -ChildPath "6368badda82f3279e4db3c.tmp")

    $userScript = @"
try {
    [System.Reflection.Assembly]::LoadWithPartialName("System.Security") | Out-Null
    
    if (`$PSVersionTable.PSVersion.Major -ge 6) {
        `$content = Get-Content -Path "`$env:LocalAppData\RealmJoin\config.pjson" -AsByteStream -ErrorAction Stop
    } else {
        `$content = Get-Content -Path "`$env:LocalAppData\RealmJoin\config.pjson" -Encoding Byte -ErrorAction Stop
    }
    
    `$unprotectedBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(`$content, `$null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    `$unprotectedString = [System.Text.Encoding]::UTF8.GetString(`$unprotectedBytes)
    `$configObject = `$unprotectedString | ConvertFrom-Json

    `$configObject | ConvertTo-Json -Depth 10 | Out-File -FilePath `"$pathResultFile`" -Force
} catch {
    @{ Error = `$_.Exception.Message; ScriptPath = `$env:LocalAppData; PSVersion = `$PSVersionTable.PSVersion.ToString() } | ConvertTo-Json | Out-File -FilePath `"$pathResultFile`" -Force
}
"@
    $userScript | Out-File -FilePath $userScriptPath -Force -Encoding ascii

    $taskName = "ReadingRJPolicy"
    $action = New-ScheduledTaskAction -Execute "conhost.exe" -Argument "--headless powershell -ex bypass -noprofile -file $userScriptPath"
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $userId = Get-LoggedOnUser
    if ([string]::IsNullOrEmpty($userId)) {
        $taskExitCode = 42
    }
    else {
        $principalCreated = $false
        $principalFormats = @("AzureAD\$userId", "$env:COMPUTERNAME\$userId", "$userId")
        
        foreach ($principalFormat in $principalFormats) {
            try {
                $principal = New-ScheduledTaskPrincipal -UserId $principalFormat -ErrorAction Stop
                $principalCreated = $true
                break
            }
            catch { }
        }
        
        if (-not $principalCreated) {
            $taskExitCode = 42
        }
        else {
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries
            $task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings
            Register-ScheduledTask $taskName -InputObject $task -Force -ErrorVariable err -ErrorAction SilentlyContinue
            if (-not [string]::IsNullOrEmpty($err)) {
                $taskExitCode = 43
            }
            else {
            try {
                $maxAttempts = 2
                $timeoutInSeconds = 60
                $taskExitCode = $null
                
                for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
                    if ($attempt -gt 1) {
                        # Second attempt: cleanup and wait before retry
                        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
                        Start-Sleep -Seconds 60
                        
                        # Re-register task for second attempt
                        Register-ScheduledTask $taskName -InputObject $task -Force -ErrorVariable err -ErrorAction SilentlyContinue
                        if (-not [string]::IsNullOrEmpty($err)) {
                            $taskExitCode = 43
                            break
                        }
                    }
                    
                    Start-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 1

                    $runningTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
                    if ($null -eq $runningTask) {
                        $taskExitCode = 43
                        break
                    }
                    
                    $startTime = Get-Date
                    $timedOut = $false
            
                    while ((Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue).State -ne 'Ready') {
                        if ((Get-Date) -ge ($startTime.AddSeconds($timeoutInSeconds))) {
                            $timedOut = $true
                            break
                        }
                        Start-Sleep -Seconds 1
                    }
            
                    if (-not $timedOut) {
                        $taskResult = Get-ScheduledTask -TaskName $taskName | Get-ScheduledTaskInfo
                        if ($null -ne $taskResult.LastTaskResult) {
                            $taskExitCode = $taskResult.LastTaskResult
                            break
                        }
                    }
                    
                }
            }
            catch { }
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
            Remove-Item -Path $userScriptPath -Force -ErrorAction SilentlyContinue
            }
        }
    }

    if ($null -eq $taskExitCode) {
        $taskExitCode = 44
    }

    $returnValue = @{
        'ExitCode'       = $taskExitCode
        'PathResultFile' = $pathResultFile
    }

    $returnValue
}

# Check built-in Administrator account status and Windows LAPS management
try {
    $localAdmin = Get-LocalUser | Where-Object { $_.SID -like 'S-1-5-21-*-500' } 
    $localAdminEnabled = $localAdmin.Enabled
    
    # Check if Windows LAPS is managing the built-in administrator
    # AutomaticAccountManagementEnabled: 0 = Disabled, 1 = Enabled
    # AutomaticAccountManagementTarget values:
    # 0 = Manage built-in Administrator account (default)
    # 1 = Manage a custom local admin account
    # 2 = Manage both built-in and custom account
    $windowsLapsBuiltInAdminManaged = $false
    $windowsLapsCustomAccountName = $null
    $windowsLapsEnabled = $false
    $lapsRegPath = "HKLM:\Software\Microsoft\Policies\LAPS"
    
    if (Test-Path $lapsRegPath) {
        try {
            $lapsEnabled = Get-ItemProperty -Path $lapsRegPath -Name "AutomaticAccountManagementEnabled" -ErrorAction SilentlyContinue
            if ($null -ne $lapsEnabled -and $lapsEnabled.AutomaticAccountManagementEnabled -eq 1) {
                $windowsLapsEnabled = $true
                
                $lapsTarget = Get-ItemProperty -Path $lapsRegPath -Name "AutomaticAccountManagementTarget" -ErrorAction SilentlyContinue
                
                $targetValue = 0
                if ($null -ne $lapsTarget) {
                    $targetValue = $lapsTarget.AutomaticAccountManagementTarget
                }
                
                if ($targetValue -eq 0 -or $targetValue -eq 2) {
                    $windowsLapsBuiltInAdminManaged = $true
                }
                
                if ($targetValue -eq 1 -or $targetValue -eq 2) {
                    $customAccountName = Get-ItemProperty -Path $lapsRegPath -Name "AdministratorAccountName" -ErrorAction SilentlyContinue
                    if ($null -ne $customAccountName -and -not [string]::IsNullOrEmpty($customAccountName.AdministratorAccountName)) {
                        $windowsLapsCustomAccountName = $customAccountName.AdministratorAccountName
                    }
                    else {
                        $nameOrPrefix = Get-ItemProperty -Path $lapsRegPath -Name "AutomaticAccountManagementNameOrPrefix" -ErrorAction SilentlyContinue
                        $randomizeName = Get-ItemProperty -Path $lapsRegPath -Name "AutomaticAccountManagementRandomizeName" -ErrorAction SilentlyContinue
                        
                        if ($null -ne $nameOrPrefix -and -not [string]::IsNullOrEmpty($nameOrPrefix.AutomaticAccountManagementNameOrPrefix)) {
                            $nameOrPrefixValue = $nameOrPrefix.AutomaticAccountManagementNameOrPrefix
                            $isRandomized = ($null -ne $randomizeName -and $randomizeName.AutomaticAccountManagementRandomizeName -eq 1)
                            
                            if ($isRandomized) {
                                $windowsLapsCustomAccountName = "^$([regex]::Escape($nameOrPrefixValue)).*"
                            }
                            else {
                                $windowsLapsCustomAccountName = $nameOrPrefixValue
                            }
                        }
                        else {
                            $isRandomized = ($null -ne $randomizeName -and $randomizeName.AutomaticAccountManagementRandomizeName -eq 1)
                            if ($isRandomized) {
                                $windowsLapsCustomAccountName = "^WLapsAdmin.*"
                            }
                            else {
                                $windowsLapsCustomAccountName = "WLapsAdmin"
                            }
                        }
                    }
                }
            }
        }
        catch { }
    }
}
catch {
    Debug-Message "Failed to get built-in Administrator account, Error: $($_.Exception.Message)" -Color "Red"
}

# check if current logged on user is member of Administrators group
$adminGroupMembers = Get-LocalAdministratorsGroupMembers
$loggedOnAccount = Get-LoggedOnUser
$loggedOnAccountIsAdmin = $false

if ([string]::IsNullOrEmpty($loggedOnAccount)) {
    Write-Host "No user logged on - skipping evaluation (will retry on next cycle)"
    if (-not $debug) {
        Exit 0
    }
}

if ($adminGroupMembers -contains $loggedOnAccount) {
    Debug-Message "Logged on user '$loggedOnAccount' is member of Administrators group"
    $loggedOnAccountIsAdmin = $true
}

# Initialize allowed administrators list
$allowedAdminUsersDefinition = @()

# Built-in Administrator is only allowed if:
# 1. It's disabled (not a threat) OR
# 2. It's managed by Windows LAPS (AutomaticAccountManagementTarget = 0 or 2)
if (-not $localAdminEnabled -or $windowsLapsBuiltInAdminManaged) {
    $allowedAdminUsersDefinition += $localAdmin.Name
    if ($windowsLapsBuiltInAdminManaged) {
        Debug-Message "Built-in Administrator '$($localAdmin.Name)' is managed by Windows LAPS - adding to allowed list" -Color "Green"
    }
    elseif (-not $localAdminEnabled) {
        Debug-Message "Built-in Administrator '$($localAdmin.Name)' is disabled - adding to allowed list as non-threat" -Color "Green"
    }
}
else {
    Debug-Message "Built-in Administrator '$($localAdmin.Name)' is ENABLED but NOT managed by Windows LAPS - marking for removal" -Color "Red"
}

# If Windows LAPS manages a custom account (AutomaticAccountManagementTarget = 1 or 2), add it to allowed list
if ($null -ne $windowsLapsCustomAccountName) {
    $allowedAdminUsersDefinition += $windowsLapsCustomAccountName
    Debug-Message "Added Windows LAPS custom account '$windowsLapsCustomAccountName' to allowed list" -Color "Green"
}

$rjPolicyReadError = $true
$rjPolicyReadResult = "undefined"
$rjLapsConfigured = $false
$manipulationDetected = $false
$manipulatedAccountsList = @()
$realmJoinInstalled = $false

# Check if RealmJoin is installed before attempting policy read
$realmJoinPath = "$env:ProgramFiles\RealmJoin\RealmJoin.exe"
$realmJoinInstalled = $false

if (Test-Path -Path $realmJoinPath) {
    $realmJoinInstalled = $true
    Debug-Message "RealmJoin is installed at: $realmJoinPath" -Color "Green"
    $resultRjAdminPolicy = Get-RjAdminPolicy
}
else {
    Debug-Message "RealmJoin is NOT installed - skipping RJ policy check" -Color "Yellow"
    
    # Set result to indicate RJ is not installed (Exit Code 45)
    $resultRjAdminPolicy = @{
        'ExitCode'       = 45  # Exit code: RealmJoin not installed
        'PathResultFile' = ""
    }
}

# Read RealmJoin policy from result file (only if RealmJoin is installed)
if ($realmJoinInstalled -and $resultRjAdminPolicy.ExitCode -ne 45) {
    $pathResultFile = $(Join-Path -Path "$env:SystemRoot\tracing" -ChildPath "6368badda82f3279e4db3c.tmp")
    if (Test-Path -Path $pathResultFile) { 
        $resultRjAdminPolicyContent = Get-Content -Path $pathResultFile -Raw
        if (-not [string]::IsNullOrEmpty($resultRjAdminPolicyContent)) {
        try {
            $rjPolicyReadError = $false
            $configObject = $resultRjAdminPolicyContent | ConvertFrom-Json
            
            if ($null -eq $configObject.Error) {
                $rjPolicyReadResult = $configObject.Policies.SetCurrentUserAdministrator
                Debug-Message "SetCurrentUserAdministrator=$rjPolicyReadResult" -Color "Yellow"
            
                if ($null -ne $configObject.LocalAdminManagement) {
                    $rjLapsConfigured = $true
                    Debug-Message "LocalAdminManagement (LAPS) policy found in config" -Color "Green"
                    
                    $lapsAccountDefs = Get-RjLapsAccountDefinitions -LocalAdminManagement $configObject.LocalAdminManagement
                    
                    if ($lapsAccountDefs.Count -gt 0) {
                        $manipulationResult = Test-RjLapsAccountManipulation -AdminGroupMembers $adminGroupMembers -AccountDefinitions $lapsAccountDefs
                        
                        if ($manipulationResult.ManipulatedAccounts.Count -gt 0) {
                            $manipulationDetected = $true
                            $manipulatedAccountsList = $manipulationResult.ManipulatedAccounts
                            Debug-Message "SECURITY ALERT: $($manipulatedAccountsList.Count) manipulated accounts detected!" -Color "Red"
                        }
                        
                        $allowedAdminUsersDefinition += $manipulationResult.LegitimateAccounts
                    }
                }
                else {
                    Debug-Message "LocalAdminManagement (LAPS) policy not found in config" -Color "Yellow"
                }
                
                if ($rjPolicyReadResult -ieq "true") {
                    if ($loggedOnAccountIsAdmin) {
                        $allowedAdminUsersDefinition += $loggedOnAccount
                    }
                }
            }
        }
        catch { }
    }
    Remove-Item -Path $pathResultFile -Force -ErrorAction SilentlyContinue
    }
}
else {
    if (-not $realmJoinInstalled) {
        Debug-Message "Skipping RealmJoin policy read - RealmJoin not installed" -Color "Yellow"
    }
}

$allowedAdminUsersEvaluation = @()

foreach ($admin in $adminGroupMembers) {
    $matchedInThisIteration = $false
    
    foreach ($allowedAdmin in $allowedAdminUsersDefinition) {
        if ($allowedAdmin -contains "`|") {
            $allowedAdminName, $allowedAdminDescription = $allowedAdmin.Split("`|")
        }
        else {
            $allowedAdminName = $allowedAdmin
        }
        
        $isMatch = $false
        if ($allowedAdminName -like '^*') {
            $isMatch = $admin -match $allowedAdminName
        }
        else {
            $isMatch = $admin -eq $allowedAdminName
        }
        
        if ($isMatch) {
            if ($allowedAdmin -contains "`|") {
                $localAdminUserDescription = $(Get-LocalUser -Name $admin).Description
                if ($localAdminUserDescription -match $allowedAdminDescription) {
                    $allowedAdminUsersEvaluation += $admin
                    $matchedInThisIteration = $true
                }
            }
            else {
                $allowedAdminUsersEvaluation += $admin
                $matchedInThisIteration = $true
                break
            }
        }
    }
    
    if (-not $matchedInThisIteration) {
    }
}

$allowedAdminUsersEvaluation = $allowedAdminUsersEvaluation | Select-Object -Unique
$deniedAdminUsersEvaluation = $adminGroupMembers | Where-Object { $_ -notin $allowedAdminUsersEvaluation }

$outputParts = @()
$outputParts += "BuiltInAdminEnabled=$localAdminEnabled"
$outputParts += "WindowsLapsBuiltInManaged=$windowsLapsBuiltInAdminManaged"
$outputParts += "WindowsLapsCustomAccount=$windowsLapsCustomAccountName"
$outputParts += "RJInstalled=$realmJoinInstalled"
$outputParts += "RJPolicyTaskExitCode=$($resultRjAdminPolicy.ExitCode)"
$outputParts += "RJPolicyReadError=$rjPolicyReadError"
$outputParts += "RJPolicyResult=$rjPolicyReadResult"
$outputParts += "RJLapsConfigured=$rjLapsConfigured"
$outputParts += "ManipulationDetected=$manipulationDetected"

if ($manipulatedAccountsList.Count -gt 0) {
    $outputParts += "ManipulatedAccounts=[$($manipulatedAccountsList -join ', ')]"
}
else {
    $outputParts += "ManipulatedAccounts=[None]"
}

$outputParts += "AllAdmins=[$($adminGroupMembers -join ', ')]"
$outputParts += "AllowedAdmins=[$($allowedAdminUsersEvaluation -join ', ')]"

if ($deniedAdminUsersEvaluation.length -ne 0) {
    $outputParts += "UnauthorizedAdmins=[$($deniedAdminUsersEvaluation -join ', ')]"
}
else {
    $outputParts += "UnauthorizedAdmins=[None]"
}

Write-Host ($outputParts -join ' | ')
if (-not $debug) {
    $hasUnauthorizedAdmins = -not [string]::IsNullOrEmpty($deniedAdminUsersEvaluation)
    $builtInAdminIssue = $localAdminEnabled -and -not $windowsLapsBuiltInAdminManaged
    
    # Exit codes that are acceptable (no remediation needed)
    # 0 = Success (Policy read successfully)
    # 42 = No user logged on (can't read policy, retry later)
    # 43 = Failed to create scheduled task (can't read policy, retry later)
    # 44 = Task couldn't be evaluated (can't read policy, retry later)
    # 45 = RealmJoin not installed (expected if RJ is not used)
    $acceptableExitCodes = @(0, 42, 43, 44, 45)
    
    # Safe conversion to avoid OverflowException with large Win32 error codes
    $exitCodeIsAcceptable = $false
    $exitCodeConversionFailed = $false
    try {
        # trim whitespace
        $exitCodeString = "$($resultRjAdminPolicy.ExitCode)".Trim()
        $exitCodeValue = [int]$exitCodeString
        $exitCodeIsAcceptable = $exitCodeValue -in $acceptableExitCodes
    }
    catch {
        # Conversion failed - unexpected error code (e.g., Win32 error like 2147943467 or invalid format)
        Debug-Message "DEBUG: Failed to convert exit code '$($resultRjAdminPolicy.ExitCode)' - Error: $_"  -Color "Yellow"
        $exitCodeConversionFailed = $true
    }
    
    if ($exitCodeConversionFailed) {
        Write-Host "ERROR: Unexpected RJ Policy Task Exit Code ($($resultRjAdminPolicy.ExitCode)) - cannot evaluate compliance"
        Exit 0
    }
    
    if (-not $hasUnauthorizedAdmins -and -not $manipulationDetected -and -not $builtInAdminIssue -and $exitCodeIsAcceptable) {
        Exit 0
    }
    else {
        Exit 1
    }
}