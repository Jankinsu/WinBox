$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\src\AutoTheme\Solar.ps1')
. (Join-Path $PSScriptRoot '..\src\Common\TaskScheduler.ps1')

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

$resumeXml = [xml](New-AutoThemeResumeTaskXml -UserName 'CONTOSO\Test User' -EnginePath 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -LauncherHostPath 'C:\Windows\System32\wscript.exe' -LauncherPath 'C:\WinBox\RunHidden.vbs' -ScriptPath 'C:\WinBox\AutoTheme.ps1')
$namespace = [System.Xml.XmlNamespaceManager]::new($resumeXml.NameTable)
$namespace.AddNamespace('task', 'http://schemas.microsoft.com/windows/2004/02/mit/task')
Assert-Equal 'CONTOSO\Test User' $resumeXml.SelectSingleNode('//task:Principal/task:UserId', $namespace).InnerText 'Resume task user'
$eventSubscription = [System.Net.WebUtility]::HtmlDecode($resumeXml.SelectSingleNode('//task:EventTrigger/task:Subscription', $namespace).InnerText)
if ($eventSubscription -notmatch "Power-Troubleshooter" -or $eventSubscription -notmatch 'EventID=1') { throw 'Resume task should subscribe to the Windows resume event.' }
Assert-Equal 'C:\Windows\System32\wscript.exe' $resumeXml.SelectSingleNode('//task:Actions/task:Exec/task:Command', $namespace).InnerText 'Resume task launcher'
Assert-Equal '//B //NoLogo "C:\WinBox\RunHidden.vbs" "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" "C:\WinBox\AutoTheme.ps1" "-Mode" "Sync"' $resumeXml.SelectSingleNode('//task:Actions/task:Exec/task:Arguments', $namespace).InnerText 'Resume task action'

$syncArguments = New-AutoThemeHiddenLauncherArguments -EnginePath 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -ScriptPath 'C:\WinBox\AutoTheme.ps1' -ScriptArguments @('-Mode', 'Sync') -LauncherPath 'C:\WinBox\RunHidden.vbs'
Assert-Equal '//B //NoLogo "C:\WinBox\RunHidden.vbs" "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" "C:\WinBox\AutoTheme.ps1" "-Mode" "Sync"' $syncArguments 'Sync task launcher arguments'

$hiddenLauncher = Get-Content -Raw (Join-Path $PSScriptRoot '..\src\Common\RunHidden.vbs')
if ($hiddenLauncher -notmatch 'WScript\.Quit shell\.Run\(command, 0, True\)') { throw 'Hidden launcher should wait for PowerShell and pass its result back to Task Scheduler.' }
if ($hiddenLauncher -notmatch '-WindowStyle Hidden') { throw 'PowerShell should retain its hidden window setting.' }

'AutoTheme checks passed.'
