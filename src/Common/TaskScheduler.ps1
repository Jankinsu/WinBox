function Get-WinBoxTaskNames {
    @(
        'WinBox-AutoTheme-Refresh',
        'WinBox-AutoTheme-Light',
        'WinBox-AutoTheme-Dark',
        'WinBox-AutoTheme-Sync',
        'WinBox-AutoTheme-ResumeSync'
    )
}

function Get-AutoThemePowerShellPath {
    $pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    if ($pwsh) { return $pwsh.Source }
    $powershell = Get-Command powershell.exe -ErrorAction SilentlyContinue
    if ($powershell) { return $powershell.Source }
    throw 'Neither pwsh.exe nor powershell.exe was found.'
}

function New-AutoThemeAction {
    param([string[]] $ScriptArguments)
    $scriptPath = Join-Path $PSScriptRoot '..\AutoTheme\AutoTheme.ps1'
    $engine = Get-AutoThemePowerShellPath
    $quotedScript = '"{0}"' -f [System.IO.Path]::GetFullPath($scriptPath)
    $argumentText = ($ScriptArguments | ForEach-Object { '"{0}"' -f $_ }) -join ' '
    New-ScheduledTaskAction -Execute $engine -Argument ("-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File $quotedScript $argumentText")
}

function Register-AutoThemeTask {
    param(
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)] $Action,
        [Parameter(Mandatory)] $Trigger,
        [switch] $StartWhenAvailable
    )
    $principal = New-ScheduledTaskPrincipal -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
    $settingsArgs = @{
        AllowStartIfOnBatteries = $true
        DontStopIfGoingOnBatteries = $true
        MultipleInstances = 'IgnoreNew'
        ExecutionTimeLimit = (New-TimeSpan -Minutes 5)
    }
    if ($StartWhenAvailable) { $settingsArgs.StartWhenAvailable = $true }
    $settings = New-ScheduledTaskSettingsSet @settingsArgs
    Register-ScheduledTask -TaskName $Name -Action $Action -Trigger $Trigger -Principal $principal -Settings $settings -Force | Out-Null
    "[OK] $Name"
}

function Register-AutoThemeResumeTask {
    $userName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $engine = Get-AutoThemePowerShellPath
    $scriptPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\AutoTheme\AutoTheme.ps1'))
    $escapedUser = [System.Security.SecurityElement]::Escape($userName)
    $escapedEngine = [System.Security.SecurityElement]::Escape($engine)
    $escapedScript = [System.Security.SecurityElement]::Escape($scriptPath)
    $xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><Description>Synchronize the current theme after Windows resumes from sleep.</Description></RegistrationInfo>
  <Triggers><EventTrigger><Enabled>true</Enabled><Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[Provider[@Name='Microsoft-Windows-Power-Troubleshooter'] and EventID=1]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription></EventTrigger></Triggers>
  <Principals><Principal id="Author"><UserId>$escapedUser</UserId><LogonType>InteractiveToken</LogonType><RunLevel>LeastPrivilege</RunLevel></Principal></Principals>
  <Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries><StopIfGoingOnBatteries>false</StopIfGoingOnBatteries><ExecutionTimeLimit>PT5M</ExecutionTimeLimit><Enabled>true</Enabled></Settings>
  <Actions Context="Author"><Exec><Command>$escapedEngine</Command><Arguments>-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File &quot;$escapedScript&quot; -Mode Sync</Arguments></Exec></Actions>
</Task>
"@
    Register-ScheduledTask -TaskName 'WinBox-AutoTheme-ResumeSync' -Xml $xml -Force | Out-Null
    '[OK] WinBox-AutoTheme-ResumeSync'
}

function Update-AutoThemeSolarTasks {
    param([Parameter(Mandatory)][hashtable] $Config)
    $configuredNow = Get-ConfiguredLocalNow -TimeZoneId ([string]$Config.TimeZoneId)
    $events = Get-SunriseSunset -Date $configuredNow -Latitude ([double]$Config.Latitude) -Longitude ([double]$Config.Longitude) -TimeZoneId ([string]$Config.TimeZoneId)
    $sunrise = $events.Sunrise.AddMinutes([double]$Config.SunriseOffsetMinutes)
    $sunset = $events.Sunset.AddMinutes([double]$Config.SunsetOffsetMinutes)
    if ($sunrise.Date -ne $events.Date -or $sunset.Date -ne $events.Date -or $sunrise -ge $sunset) {
        throw 'Configured offsets produce invalid event times for this date.'
    }
    $timeZone = [TimeZoneInfo]::FindSystemTimeZoneById([string]$Config.TimeZoneId)
    $machineSunrise = [TimeZoneInfo]::ConvertTimeFromUtc([TimeZoneInfo]::ConvertTimeToUtc([datetime]::SpecifyKind($sunrise, [DateTimeKind]::Unspecified), $timeZone), [TimeZoneInfo]::Local)
    $machineSunset = [TimeZoneInfo]::ConvertTimeFromUtc([TimeZoneInfo]::ConvertTimeToUtc([datetime]::SpecifyKind($sunset, [DateTimeKind]::Unspecified), $timeZone), [TimeZoneInfo]::Local)
    Register-AutoThemeTask -Name 'WinBox-AutoTheme-Light' -Action (New-AutoThemeAction -ScriptArguments @('-Mode', 'Sync')) -Trigger (New-ScheduledTaskTrigger -Daily -At $machineSunrise) -StartWhenAvailable
    Register-AutoThemeTask -Name 'WinBox-AutoTheme-Dark' -Action (New-AutoThemeAction -ScriptArguments @('-Mode', 'Sync')) -Trigger (New-ScheduledTaskTrigger -Daily -At $machineSunset) -StartWhenAvailable
}

function Remove-AutoThemeTasks {
    foreach ($taskName in Get-WinBoxTaskNames) {
        if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        }
        "[OK] $taskName"
    }
}
