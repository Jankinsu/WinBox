# Architecture

WinBox groups small Windows automation tools by function. Each script can run manually, and scheduled work is delegated to Windows Task Scheduler. Scripts are short-lived; there is no resident service or tray application.

AutoTheme separates four concerns:

- `Solar.ps1` calculates local sunrise and sunset and loads validated configuration.
- `AutoTheme.ps1` decides the desired mode and updates the current user's Windows color mode.
- `TaskScheduler.ps1` creates, refreshes, and removes AutoTheme tasks.
- `Install.ps1` and `Uninstall.ps1` manage the task lifecycle.

Scheduled tasks use the current user's interactive token and least privilege because the theme values are under `HKCU`. Task actions use absolute script paths so their behavior does not depend on the working directory.
