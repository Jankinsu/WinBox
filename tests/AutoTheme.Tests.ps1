$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\src\AutoTheme\Solar.ps1')

function Assert-Equal {
    param($Expected, $Actual, [string] $Message)
    if ($Expected -ne $Actual) { throw "$Message Expected '$Expected', got '$Actual'." }
}

$solar = Get-SunriseSunset -Date ([datetime]'2026-10-15') -Latitude 39.9042 -Longitude 116.4074 -TimeZoneId 'China Standard Time'
Assert-Equal ([datetime]'2026-10-15') $solar.Date 'Solar date'
if ($solar.Sunrise -ge $solar.Sunset) { throw 'Sunrise should precede sunset.' }
$expectedSunrise = [datetime]'2026-10-15 06:23'
$expectedSunset = [datetime]'2026-10-15 17:37'
if ([math]::Abs(($solar.Sunrise - $expectedSunrise).TotalMinutes) -gt 2) { throw "Beijing sunrise is outside the two-minute tolerance: $($solar.Sunrise.ToString('HH:mm'))." }
if ([math]::Abs(($solar.Sunset - $expectedSunset).TotalMinutes) -gt 2) { throw "Beijing sunset is outside the two-minute tolerance: $($solar.Sunset.ToString('HH:mm'))." }

$light = Get-ExpectedTheme -Now ([datetime]'2026-10-15 12:00') -Sunrise ([datetime]'2026-10-15 06:00') -Sunset ([datetime]'2026-10-15 18:00')
$darkBeforeSunrise = Get-ExpectedTheme -Now ([datetime]'2026-10-15 05:59') -Sunrise ([datetime]'2026-10-15 06:00') -Sunset ([datetime]'2026-10-15 18:00')
$darkAtSunset = Get-ExpectedTheme -Now ([datetime]'2026-10-15 18:00') -Sunrise ([datetime]'2026-10-15 06:00') -Sunset ([datetime]'2026-10-15 18:00')
Assert-Equal 'Light' $light 'Daytime theme'
Assert-Equal 'Dark' $darkBeforeSunrise 'Before sunrise theme'
Assert-Equal 'Dark' $darkAtSunset 'At sunset theme'

$polarFailed = $false
try { $null = Get-SunriseSunset -Date ([datetime]'2026-06-21') -Latitude 90 -Longitude 0 -TimeZoneId 'UTC' }
catch { $polarFailed = $true }
if (-not $polarFailed) { throw 'Polar day should return a clear error.' }

'AutoTheme checks passed.'
