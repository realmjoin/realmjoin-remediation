#=============================================================================================================================
#
# Script Name:         Detect.ps1
# Description:         Detect devices affected by the November 2026 hotpatch issue (KB5132043, error 0xC0000099)
# Changelog:           2026-11-27: Initial.
# References:          https://www.bleepingcomputer.com/news/microsoft/microsoft-confirms-app-installation-launch-issues-after-hotpatch/
#                      https://support.microsoft.com/help/5132061
# Notes:               Detect only. Reports the last logged-on user (UPN) so affected users can be assigned a fix.
#                      A device is reported as affected (exit 1) only if ALL of the following apply:
#                        1. Windows 11 build 261xx/262xx/263xx (24H2, 25H2, 26H2)
#                        2. UBR below $minHealthyUbr (build of the standard November update KB5132061)
#                        3. KB5132043 is installed
#                        4. Event 153 (provider Hotpatch-Loader) with 0xC0000099 within the last $lookbackDays days
#                           (also matched as decimal -1073741671 / 3221225625)
#                      Adjust $minHealthyUbr when the fix is delivered with a later build.
#
#=============================================================================================================================

# define Variables
$minHealthyUbr = 9974
$lookbackDays  = 30

# last logged-on user (UPN), fallback: LastLoggedOnUser
$user = 'unknown'
try {
    $logonUi = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI' -ErrorAction Stop
    $sid = $logonUi.LastLoggedOnUserSID
    $user = $logonUi.LastLoggedOnUser
    if ($sid) {
        $cache = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\IdentityStore\Cache\$sid\IdentityCache\$sid" -ErrorAction SilentlyContinue
        if ($cache -and $cache.UserName) { $user = $cache.UserName }
    }
} catch { }

# criterion 1: build
$build = (Get-CimInstance Win32_OperatingSystem).BuildNumber
$ubr   = [int](Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'UBR')
$supported = ($build -like '261*') -or ($build -like '262*') -or ($build -like '263*')
if (-not $supported) {
    Write-Host "Not applicable | Build=$build.$ubr | User=$user"
    exit 0
}

# criterion 2: UBR
if ($ubr -ge $minHealthyUbr) {
    Write-Host "Not affected (UBR >= $minHealthyUbr) | Build=$build.$ubr | User=$user"
    exit 0
}

# criterion 3: KB5132043 installed
$kb = $null
try { $kb = Get-HotFix -Id 'KB5132043' -ErrorAction Stop } catch { }
if (-not $kb) {
    Write-Host "Not affected (KB5132043 not installed) | Build=$build.$ubr | User=$user"
    exit 0
}

# criterion 4: event 153 with 0xC0000099 (the provider is not registered, so it is filtered in the pipeline)
$evt = Get-WinEvent -FilterHashtable @{ LogName = 'Application'; Id = 153; StartTime = (Get-Date).AddDays(-$lookbackDays) } -ErrorAction SilentlyContinue |
    Where-Object {
        $_.ProviderName -eq 'Hotpatch-Loader' -and
        (($_.Properties | ForEach-Object { $_.Value }) -join ' ') -match '(?i)0xc0000099|(?<!\d)-1073741671(?!\d)|(?<!\d)3221225625(?!\d)'
    } | Select-Object -First 1

if ($evt) {
    # problem detected
    Write-Host "AFFECTED | User=$user | Build=$build.$ubr | KB5132043=yes | Event153=$($evt.TimeCreated.ToString('yyyy-MM-dd HH:mm'))"
    exit 1
}

# no problem detected
Write-Host "Not affected (no event 153 within $lookbackDays days) | Build=$build.$ubr | User=$user"
exit 0
