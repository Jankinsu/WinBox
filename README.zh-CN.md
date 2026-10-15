# WinBox

[English](README.md) | **简体中文**

一个主要基于 PowerShell 和 Windows 原生功能构建的轻量级 Windows 自动化工具集。

## 设计理念

- 优先使用 Windows 原生能力
- 保持轻量
- 不运行不必要的后台服务
- 支持脚本化操作
- 操作可撤销
- 模块化设计

## 当前工具

### AutoTheme

根据本地日出和日落时间切换 Windows 及应用的默认颜色模式。它通过短时运行的 PowerShell 任务完成操作，不会在后台常驻进程。

- 日出和日落时间在本地离线计算。
- 默认使用北京坐标和中国标准时间。
- 用户可以在 `src/AutoTheme/Config.local.psd1` 中自定义位置和时区。
- 计划任务会在日出、日落、用户登录以及受支持的系统恢复事件后同步主题。
- 任务以当前用户身份运行，无需管理员权限。

## 快速开始

在 PowerShell 中从仓库根目录运行：

```powershell
Copy-Item .\src\AutoTheme\Config.local.example.psd1 .\src\AutoTheme\Config.local.psd1
notepad .\src\AutoTheme\Config.local.psd1
.\src\AutoTheme\Install.ps1
```

本地配置文件是可选的。未创建该文件时，AutoTheme 默认使用北京位置。若要使用其他位置，请同时设置纬度、经度和 Windows 时区 ID。

卸载计划任务：

```powershell
.\src\AutoTheme\Uninstall.ps1
```

手动切换：

```powershell
.\src\AutoTheme\AutoTheme.ps1 -Mode Light
.\src\AutoTheme\AutoTheme.ps1 -Mode Dark
.\src\AutoTheme\AutoTheme.ps1 -Mode Sync
```

## 仓库结构

- `src/AutoTheme/`：主题切换、日出日落计算、配置、安装和卸载脚本。
- `src/Common/`：计划任务通用辅助函数。
- `docs/`：设计和使用文档。
- `tests/`：轻量级 PowerShell 检查。

## 计划任务与切换时间

Windows 运行时，计划任务会在计算出的日出或日落时间对应的分钟触发，目标是在五分钟内完成切换。日出和日落触发的任务都会运行 `Sync`，即使触发延迟或错过，也会根据当前时间选择正确模式。用户登录以及 Windows `Power-Troubleshooter` 恢复事件也会运行 `Sync`。要更改当前用户的桌面主题，Windows 必须处于唤醒状态且用户已登录；计划任务不会唤醒电脑。

恢复事件是否可用取决于硬件和 Windows 睡眠模式。如果系统没有发出恢复事件，用户下次登录时仍会通过登录同步纠正主题。

## 限制

- 坐标和时区必须对应同一地区。
- 极昼或极夜日期、无效的事件时间偏移以及不支持的时区会产生明确错误。
- 覆盖 Windows 默认颜色模式的应用可能不会遵循系统设置。
- 已经运行的应用可能需要刷新或重启后才会显示新的颜色模式。

## 后续规划

未来可能加入网络诊断、SSH/SCP 辅助工具、系统工具和开发环境配置。这些内容不属于首个版本。
