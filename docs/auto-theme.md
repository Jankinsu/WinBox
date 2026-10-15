# AutoTheme

## Design

AutoTheme writes the current user's `AppsUseLightTheme` and `SystemUsesLightTheme` values under `HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize`. It broadcasts a settings-change message after a change. Windows apps that use the system preference can follow it; apps with their own theme setting may not.

The default location is Beijing (latitude 39.9042, longitude 116.4074) in China Standard Time. Copy `Config.local.example.psd1` to `Config.local.psd1` to override coordinates, Windows time zone ID, and sunrise/sunset offsets. The local file is ignored by Git.

The calculation uses the [NOAA fractional-year solar equations](https://gml.noaa.gov/grad/solcalc/solareqns.PDF) and the standard 90.833 degree apparent sunrise/sunset zenith. It converts event instants into the configured Windows time zone, including daylight-saving rules. Polar day/night dates are reported as unsupported because no sunrise/sunset event exists.

## Scheduled Tasks

The installer registers tasks for daily schedule refresh, sunrise, sunset, sign-in, and the Windows `Microsoft-Windows-Power-Troubleshooter` resume event. Sunrise and sunset tasks both run `Sync`, so delayed starts evaluate the current time instead of forcing a stale Light or Dark value. Tasks run under the current user's interactive token with limited privileges. They do not wake a sleeping computer.

The runtime target is to switch within five minutes while Windows is awake. A resume event should synchronize promptly when Windows emits it. Windows sleep modes and hardware differ, so resume-event behavior must be verified on the target device.

## Commands

```powershell
.\src\AutoTheme\AutoTheme.ps1 -Mode Light
.\src\AutoTheme\AutoTheme.ps1 -Mode Dark
.\src\AutoTheme\AutoTheme.ps1 -Mode Sync
.\src\AutoTheme\Install.ps1
.\src\AutoTheme\Uninstall.ps1
```

## Troubleshooting

- Run `AutoTheme.ps1 -Mode Sync` to inspect calculated times and correct the current mode.
- Check `%LOCALAPPDATA%\WinBox\Logs\AutoTheme.log` for errors from scheduled execution.
- Verify the configured coordinates and time zone are for the same region.
- Inspect the `WinBox-AutoTheme-*` tasks in Task Scheduler. They are registered for the current user and do not require elevation.
