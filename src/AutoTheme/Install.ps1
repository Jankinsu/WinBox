[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Solar.ps1')
. (Join-Path $PSScriptRoot '..\Common\TaskScheduler.ps1')

try {
    $config = Get-AutoThemeConfig
    $configuredNow = Get-ConfiguredLocalNow -TimeZoneId ([string]$config.TimeZoneId)
    $events = Get-SunriseSunset -Date $configuredNow -Latitude ([double]$config.Latitude) -Longitude ([double]$config.Longitude) -TimeZoneId ([string]$config.TimeZoneId)
    $sunrise = $events.Sunrise.AddMinutes([double]$config.SunriseOffsetMinutes)
    $sunset = $events.Sunset.AddMinutes([double]$config.SunsetOffsetMinutes)

    'WinBox - AutoTheme Installer'
    "Latitude: $($config.Latitude)"
    "Longitude: $($config.Longitude)"
    "Time zone: $($config.TimeZoneId)"
    'Sunrise: {0:HH:mm}' -f $sunrise
    'Sunset: {0:HH:mm}' -f $sunset
    'Creating or updating tasks...'

    $refreshAction = New-AutoThemeAction -ScriptArguments @('-Mode', 'Refresh')
    Register-AutoThemeTask -Name 'WinBox-AutoTheme-Refresh' -Action $refreshAction -Trigger (New-ScheduledTaskTrigger -Daily -At '00:05') -StartWhenAvailable
    Update-AutoThemeSolarTasks -Config $config
    Register-AutoThemeTask -Name 'WinBox-AutoTheme-Sync' -Action (New-AutoThemeAction -ScriptArguments @('-Mode', 'Sync')) -Trigger (New-ScheduledTaskTrigger -AtLogOn -User ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name))
    Register-AutoThemeResumeTask

    'Synchronizing current theme...'
    & (Join-Path $PSScriptRoot 'AutoTheme.ps1') -Mode Sync
    'Installation completed.'
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
