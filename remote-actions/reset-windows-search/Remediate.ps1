#=============================================================================================================================
#
# Script Name:         Remediate.ps1
# Description:         Reset Windows Search Box
# References:          https://www.microsoft.com/en-us/download/details.aspx?id=100295
#                      https://learn.microsoft.com/en-us/troubleshoot/windows-client/shell-experience/fix-problems-in-windows-search
# Changelog:           2025-04-24: Release.
#
#=============================================================================================================================

# define Functions
function T-R
{
    [CmdletBinding()]
    Param(
        [String] $n
    )

    $o = Get-Item -LiteralPath $n -ErrorAction SilentlyContinue
    return ($o -ne $null)
}

function R-R
{
    [CmdletBinding()]
    Param(
        [String] $l
    )

    $m = T-R $l
    if ($m) {
        Remove-Item -Path $l -Recurse -ErrorAction SilentlyContinue
    }
}

function S-D {
    R-R "HKLM:\SOFTWARE\Microsoft\Cortana\Testability"
    R-R "HKLM:\SOFTWARE\Microsoft\Search\Testability"
}

function K-P {
    [CmdletBinding()]
    Param(
        [String] $g
    )

    $h = Get-Process $g -ErrorAction SilentlyContinue

    $i = $(get-date).AddSeconds(2)
    $k = $(get-date)

    while ((($i - $k) -gt 0) -and $h) {
        $k = $(get-date)

        $h = Get-Process $g -ErrorAction SilentlyContinue
        if ($h) {
            $h.CloseMainWindow() | Out-Null
            Stop-Process -Id $h.Id -Force
        }

        $h = Get-Process $g -ErrorAction SilentlyContinue
    }
}

function D-FF {
    [CmdletBinding()]
    Param(
        [string[]] $e
    )

    foreach ($f in $e) {
        if (Test-Path -Path $f) {
            Remove-Item -Recurse -Force $f -ErrorAction SilentlyContinue
        }
    }
}

function D-W {

    $d = @("$Env:localappdata\Packages\Microsoft.Cortana_8wekyb3d8bbwe\AC\AppCache",
        "$Env:localappdata\Packages\Microsoft.Cortana_8wekyb3d8bbwe\AC\INetCache",
        "$Env:localappdata\Packages\Microsoft.Cortana_8wekyb3d8bbwe\AC\INetCookies",
        "$Env:localappdata\Packages\Microsoft.Cortana_8wekyb3d8bbwe\AC\INetHistory",
        "$Env:localappdata\Packages\Microsoft.Windows.Cortana_cw5n1h2txyewy\AC\AppCache",
        "$Env:localappdata\Packages\Microsoft.Windows.Cortana_cw5n1h2txyewy\AC\INetCache",
        "$Env:localappdata\Packages\Microsoft.Windows.Cortana_cw5n1h2txyewy\AC\INetCookies",
        "$Env:localappdata\Packages\Microsoft.Windows.Cortana_cw5n1h2txyewy\AC\INetHistory",
        "$Env:localappdata\Packages\Microsoft.Search_8wekyb3d8bbwe\AC\AppCache",
        "$Env:localappdata\Packages\Microsoft.Search_8wekyb3d8bbwe\AC\INetCache",
        "$Env:localappdata\Packages\Microsoft.Search_8wekyb3d8bbwe\AC\INetCookies",
        "$Env:localappdata\Packages\Microsoft.Search_8wekyb3d8bbwe\AC\INetHistory",
        "$Env:localappdata\Packages\Microsoft.Windows.Search_cw5n1h2txyewy\AC\AppCache",
        "$Env:localappdata\Packages\Microsoft.Windows.Search_cw5n1h2txyewy\AC\INetCache",
        "$Env:localappdata\Packages\Microsoft.Windows.Search_cw5n1h2txyewy\AC\INetCookies",
        "$Env:localappdata\Packages\Microsoft.Windows.Search_cw5n1h2txyewy\AC\INetHistory")

    D-FF $d
}

function R-L {
    [CmdletBinding()]
    Param(
        [String] $c
    )
 
    K-P $c 2>&1
    D-W # 2>&1
    K-P $c 2>&1

    Start-Sleep -s 5
}

# define Variables
$path = "HKCU:\SOFTWARE\RealmJoin\Custom\PAR\reset-windows-search"
$name = "Executed"
$value = 1
$type = [Microsoft.Win32.RegistryValueKind]::DWord

try {
    
    $a = "searchui"
    $b = "$Env:localappdata\Packages\Microsoft.Windows.Search_cw5n1h2txyewy"
    if (Test-Path -Path $b) {
        $a = "searchapp"
    } 

    Write-Host "Resetting Windows Search Box: $($a)."
    # S-D 2>&1      # Removed to be able to run without admin rights
    R-L $a

    Write-Host "Done resetting Windows Search Box: $($a)."

    # store execution status
    if(!(Test-Path $path)) {
        New-Item -Path $path -Force | Out-Null
        Set-ItemProperty -Path $path -Name $name -Value $value -Type $type -Force | Out-Null
    } else {
        Set-ItemProperty -Path $path -Name $name -Value $value -Type $type -Force | Out-Null
    }

    exit 0

} catch {
    # error occured
    $errMsg = $_.Exception.Message
    Write-Host "Error: $errMsg"
    exit 1
}