function Get-SunriseSunset {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [datetime] $Date,
        [Parameter(Mandatory)]
        [ValidateRange(-90, 90)]
        [double] $Latitude,
        [Parameter(Mandatory)]
        [ValidateRange(-180, 180)]
        [double] $Longitude,
        [Parameter()]
        [string] $TimeZoneId = [TimeZoneInfo]::Local.Id
    )

    try {
        $timeZone = [TimeZoneInfo]::FindSystemTimeZoneById($TimeZoneId)
    }
    catch {
        throw "Unknown Windows time zone '$TimeZoneId'. Use a Windows time zone ID (for example, 'China Standard Time')."
    }

    $localDate = $Date.Date
    $localNoon = [datetime]::SpecifyKind($localDate.AddHours(12), [DateTimeKind]::Unspecified)
    $utcAnchor = [TimeZoneInfo]::ConvertTimeToUtc($localNoon, $timeZone)
    $daysInYear = 365.0
    if ([datetime]::IsLeapYear($localDate.Year)) { $daysInYear = 366.0 }
    $gamma = 2.0 * [math]::PI / $daysInYear * ($utcAnchor.DayOfYear - 1 + (($utcAnchor.Hour + ($utcAnchor.Minute / 60.0)) - 12.0) / 24.0)

    $equationOfTime = 229.18 * (
        0.000075 +
        0.001868 * [math]::Cos($gamma) -
        0.032077 * [math]::Sin($gamma) -
        0.014615 * [math]::Cos(2.0 * $gamma) -
        0.040849 * [math]::Sin(2.0 * $gamma)
    )
    $declination = (
        0.006918 -
        0.399912 * [math]::Cos($gamma) +
        0.070257 * [math]::Sin($gamma) -
        0.006758 * [math]::Cos(2.0 * $gamma) +
        0.000907 * [math]::Sin(2.0 * $gamma) -
        0.002697 * [math]::Cos(3.0 * $gamma) +
        0.001480 * [math]::Sin(3.0 * $gamma)
    )

    $latitudeRadians = $Latitude * [math]::PI / 180.0
    $zenithRadians = 90.833 * [math]::PI / 180.0
    $denominator = [math]::Cos($latitudeRadians) * [math]::Cos($declination)
    if ([math]::Abs($denominator) -lt 1e-12) {
        throw "Sunrise or sunset is not defined for latitude $Latitude on $($localDate.ToString('yyyy-MM-dd'))."
    }

    $cosHourAngle = ([math]::Cos($zenithRadians) / $denominator) - ([math]::Tan($latitudeRadians) * [math]::Tan($declination))
    if ($cosHourAngle -lt -1.0 -or $cosHourAngle -gt 1.0) {
        throw "The sun does not rise and set on $($localDate.ToString('yyyy-MM-dd')) at latitude $Latitude (polar day or night)."
    }

    $hourAngleDegrees = [math]::Acos($cosHourAngle) * 180.0 / [math]::PI
    $sunriseUtcMinutes = 720.0 - (4.0 * ($Longitude + $hourAngleDegrees)) - $equationOfTime
    $sunsetUtcMinutes = 720.0 - (4.0 * ($Longitude - $hourAngleDegrees)) - $equationOfTime

    $utcMidnight = [datetime]::SpecifyKind($localDate, [DateTimeKind]::Utc)
    $sunriseUtc = $utcMidnight.AddMinutes($sunriseUtcMinutes)
    $sunsetUtc = $utcMidnight.AddMinutes($sunsetUtcMinutes)
    $sunriseLocal = [TimeZoneInfo]::ConvertTimeFromUtc($sunriseUtc, $timeZone)
    $sunsetLocal = [TimeZoneInfo]::ConvertTimeFromUtc($sunsetUtc, $timeZone)

    if ($sunriseLocal.Date -ne $localDate -or $sunsetLocal.Date -ne $localDate) {
        throw "The configured time zone '$TimeZoneId' does not place both solar events on $($localDate.ToString('yyyy-MM-dd')). Check that the coordinates and time zone describe the same region."
    }

    [pscustomobject]@{
        Date = $localDate
        Sunrise = $sunriseLocal
        Sunset = $sunsetLocal
    }
}

function Get-AutoThemeConfig {
    [CmdletBinding()]
    param(
        [string] $ConfigPath = (Join-Path $PSScriptRoot 'Config.psd1'),
        [string] $LocalConfigPath = (Join-Path $PSScriptRoot 'Config.local.psd1')
    )

    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        throw "Configuration file not found: $ConfigPath"
    }
    $config = Import-PowerShellDataFile -LiteralPath $ConfigPath

    if (Test-Path -LiteralPath $LocalConfigPath -PathType Leaf) {
        $localConfig = Import-PowerShellDataFile -LiteralPath $LocalConfigPath
        foreach ($key in $localConfig.Keys) {
            $config[$key] = $localConfig[$key]
        }
    }

    foreach ($key in @('Latitude', 'Longitude', 'TimeZoneId', 'SunriseOffsetMinutes', 'SunsetOffsetMinutes')) {
        if (-not $config.ContainsKey($key)) {
            throw "Missing configuration value '$key'."
        }
    }
    if ($config.Latitude -isnot [ValueType] -or [double]$config.Latitude -lt -90 -or [double]$config.Latitude -gt 90) {
        throw 'Latitude must be a number from -90 through 90.'
    }
    if ($config.Longitude -isnot [ValueType] -or [double]$config.Longitude -lt -180 -or [double]$config.Longitude -gt 180) {
        throw 'Longitude must be a number from -180 through 180.'
    }
    foreach ($key in @('SunriseOffsetMinutes', 'SunsetOffsetMinutes')) {
        if ($config[$key] -isnot [ValueType] -or [double]$config[$key] -lt -180 -or [double]$config[$key] -gt 180) {
            throw "$key must be a number from -180 through 180."
        }
    }
    if ($config.TimeZoneId -isnot [string] -or [string]::IsNullOrWhiteSpace($config.TimeZoneId)) {
        throw 'TimeZoneId must be a Windows time zone ID.'
    }

    # Validate the time zone and the effective event order for today.
    $timeZone = [TimeZoneInfo]::FindSystemTimeZoneById([string]$config.TimeZoneId)
    $configuredToday = ([TimeZoneInfo]::ConvertTimeFromUtc([datetime]::UtcNow, $timeZone)).Date
    $events = Get-SunriseSunset -Date $configuredToday -Latitude ([double]$config.Latitude) -Longitude ([double]$config.Longitude) -TimeZoneId ([string]$config.TimeZoneId)
    $effectiveSunrise = $events.Sunrise.AddMinutes([double]$config.SunriseOffsetMinutes)
    $effectiveSunset = $events.Sunset.AddMinutes([double]$config.SunsetOffsetMinutes)
    if ($effectiveSunrise.Date -ne $events.Date -or $effectiveSunset.Date -ne $events.Date -or $effectiveSunrise -ge $effectiveSunset) {
        throw 'Offsets must leave sunrise and sunset in the same local day, with sunrise earlier than sunset.'
    }

    return $config
}

function Get-ExpectedTheme {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][datetime] $Now,
        [Parameter(Mandatory)][datetime] $Sunrise,
        [Parameter(Mandatory)][datetime] $Sunset
    )
    if ($Now -ge $Sunrise -and $Now -lt $Sunset) { return 'Light' }
    return 'Dark'
}

function Get-ConfiguredLocalNow {
    param([Parameter(Mandatory)][string] $TimeZoneId)
    $timeZone = [TimeZoneInfo]::FindSystemTimeZoneById($TimeZoneId)
    [TimeZoneInfo]::ConvertTimeFromUtc([datetime]::UtcNow, $timeZone)
}

if ($MyInvocation.InvocationName -ne '.') {
    $chinaTimeZone = [TimeZoneInfo]::FindSystemTimeZoneById('China Standard Time')
    $chinaToday = ([TimeZoneInfo]::ConvertTimeFromUtc([datetime]::UtcNow, $chinaTimeZone)).Date
    $result = Get-SunriseSunset -Date $chinaToday -Latitude 39.9042 -Longitude 116.4074 -TimeZoneId 'China Standard Time'
    'Date: {0:yyyy-MM-dd}' -f $result.Date
    'Sunrise: {0:HH:mm}' -f $result.Sunrise
    'Sunset: {0:HH:mm}' -f $result.Sunset
}
