[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\Common\TaskScheduler.ps1')
'Removing AutoTheme scheduled tasks...'
Remove-AutoThemeTasks
'AutoTheme removed successfully.'
