# WinBox

A lightweight Windows automation toolkit built primarily with PowerShell and native Windows capabilities.

## Design Philosophy

- Native first
- Lightweight
- No unnecessary background services
- Scriptable
- Reversible
- Modular

## Current Tools

### AutoTheme

Changes the Windows and app default color modes using local sunrise and sunset times. It runs as short PowerShell tasks and does not keep a process running in the background.

- Sunrise and sunset are calculated offline.
- Beijing coordinates and China Standard Time are the defaults.
- Users can override the location and time zone in `src/AutoTheme/Config.local.psd1`.
- Scheduled tasks synchronize the theme at sunrise and sunset, at sign-in, and after a supported resume event.
- Tasks run as the current user and do not require administrator rights.

## Quick Start

Run the scripts from the repository root in PowerShell:

```powershell
Copy-Item .\src\AutoTheme\Config.local.example.psd1 .\src\AutoTheme\Config.local.psd1
notepad .\src\AutoTheme\Config.local.psd1
.\src\AutoTheme\Install.ps1
```

The local configuration file is optional. Without it, AutoTheme uses Beijing by default. Set the latitude, longitude, and Windows time zone ID together when using a different location.

Uninstall scheduled tasks:

```powershell
.\src\AutoTheme\Uninstall.ps1
```

Manual operation:

```powershell
.\src\AutoTheme\AutoTheme.ps1 -Mode Light
.\src\AutoTheme\AutoTheme.ps1 -Mode Dark
.\src\AutoTheme\AutoTheme.ps1 -Mode Sync
```

## Repository Structure

- `src/AutoTheme/`: theme switching, solar calculation, configuration, installer, and uninstaller.
- `src/Common/`: shared Task Scheduler helpers.
- `docs/`: design and usage documentation.
- `tests/`: lightweight PowerShell checks.

## Scheduling and Timing

When Windows is running, the scheduled task targets the calculated sunrise and sunset minute. The acceptance target is to switch within five minutes. The task runs `Sync` at both event times so a delayed or missed trigger still selects the correct current mode. Sign-in and the Windows `Power-Troubleshooter` resume event also run `Sync`. Windows must be awake and signed in to change the current user's desktop; tasks do not wake the computer.

Resume event availability can vary by hardware and Windows sleep mode. If a resume event is not emitted, sign-in synchronization still corrects the theme at the next sign-in.

## Limitations

- Coordinates and time zone must describe the same region.
- Polar day/night dates, invalid event offsets, and unsupported time zones produce a clear error.
- Apps that override the Windows default color mode may not follow the system setting.
- Existing apps may need to refresh or restart to reflect a color mode change.

## Roadmap

Potential future tools include network diagnostics, SSH/SCP helpers, system utilities, and development environment setup. They are not part of the first release.
