[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Light', 'Dark', 'Sync', 'Refresh')]
    [string] $Mode
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Solar.ps1')

function Get-CurrentTheme {
    $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    if (-not (Test-Path -LiteralPath $path)) { throw "Theme registry key not found: $path" }
    $values = Get-ItemProperty -LiteralPath $path
    if ($null -eq $values.AppsUseLightTheme -or $null -eq $values.SystemUsesLightTheme) {
        throw 'Theme registry values AppsUseLightTheme and SystemUsesLightTheme are required.'
    }
    if ([int]$values.AppsUseLightTheme -notin @(0, 1) -or [int]$values.SystemUsesLightTheme -notin @(0, 1)) {
        throw 'Theme registry values must be 0 (Dark) or 1 (Light).'
    }
    if ([int]$values.AppsUseLightTheme -ne [int]$values.SystemUsesLightTheme) { return 'Mixed' }
    if ([int]$values.AppsUseLightTheme -eq 1) { return 'Light' }
    return 'Dark'
}

function Set-Theme {
    param([Parameter(Mandatory)][ValidateSet('Light', 'Dark')][string] $Target)
    $current = Get-CurrentTheme
    if ($current -eq $Target) {
        "Theme is already set to $Target."
        return
    }

    $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    $value = if ($Target -eq 'Light') { 1 } else { 0 }
    foreach ($name in @('AppsUseLightTheme', 'SystemUsesLightTheme')) {
        New-ItemProperty -LiteralPath $path -Name $name -Value $value -PropertyType DWord -Force | Out-Null
    }

    if (-not ('WinBox.ThemeNative' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace WinBox {
    public static class ThemeNative {
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
    }
}
'@
    }
    $result = [UIntPtr]::Zero
    [void][WinBox.ThemeNative]::SendMessageTimeout([IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, 'ImmersiveColorSet', 0x0002, 5000, [ref]$result)
    "Current theme: $current"
    "Target theme: $Target"
    'Theme switched successfully.'
}

try {
    if ($Mode -in @('Light', 'Dark')) {
        Set-Theme -Target $Mode
        exit 0
    }

    $config = Get-AutoThemeConfig
    if ($Mode -eq 'Refresh') {
        . (Join-Path $PSScriptRoot '..\Common\TaskScheduler.ps1')
        Update-AutoThemeSolarTasks -Config $config
    }

    $now = Get-ConfiguredLocalNow -TimeZoneId ([string]$config.TimeZoneId)
    $events = Get-SunriseSunset -Date $now -Latitude ([double]$config.Latitude) -Longitude ([double]$config.Longitude) -TimeZoneId ([string]$config.TimeZoneId)
    $sunrise = $events.Sunrise.AddMinutes([double]$config.SunriseOffsetMinutes)
    $sunset = $events.Sunset.AddMinutes([double]$config.SunsetOffsetMinutes)
    if ($sunrise.Date -ne $events.Date -or $sunset.Date -ne $events.Date -or $sunrise -ge $sunset) {
        throw 'Configured offsets produce invalid event times for this date.'
    }
    "Sunrise: {0:HH:mm}" -f $sunrise
    "Sunset: {0:HH:mm}" -f $sunset
    "Current: {0:HH:mm}" -f $now
    $target = Get-ExpectedTheme -Now $now -Sunrise $sunrise -Sunset $sunset
    "Expected theme: $target"
    Set-Theme -Target $target
    exit 0
}
catch {
    $message = $_.Exception.Message
    Write-Error $message
    try {
        $logDirectory = Join-Path $env:LOCALAPPDATA 'WinBox\Logs'
        New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
        Add-Content -LiteralPath (Join-Path $logDirectory 'AutoTheme.log') -Value ('{0:u} {1}' -f (Get-Date), $message)
    }
    catch { }
    exit 1
}
