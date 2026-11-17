# KDE Suite 固定配置依据

本页只记录本次 Filelight 菜单兼容处理新增的固定内容；既有稳定配置和修复历史仍以 [README](../README.md) 为准。

## Filelight 专用桌面控件样式与入口

### 故障原始记录

本项原始证据为用户提供的图形界面截图，没有随附终端报错、日志或命令输出，不能补造文本日志。截图中三项菜单的文字为：

```text
配置                  Ctrl+Shift+,
打开使用手册
关于 Filelight
```

上面的文本仅转录菜单内容，空格不能还原原图的像素布局；原图中第一行动作文字与快捷键重叠。本页不发布用户截图、主机信息或附件路径。已确认的故障范围是这处菜单布局，不是缺少中文字符或整个字体配置失效。

### 具体内容、原因与作用

| 固定内容 | 依据与用途 |
| --- | --- |
| `QT_QUICK_CONTROLS_STYLE=org.kde.desktop` | [Filelight 上游默认选择](https://github.com/KDE/filelight/blob/176cce0b6ac61127a2d41b0fe26b8f7675d694e4/src/main.cpp#L61)。公共 Hook 指定 Breeze，因此在 Filelight 专用入口恢复桌面样式；仅影响这个进程，不修改用户字体或配色配置。 |
| `AppDir/bin/filelight` | 保留现有 AppRun 与 `apps.ini` 的同名命令入口，内容改为专用包装。 |
| `AppDir/bin/kde-suite-filelight` | 原始 sharun 启动器留在 `bin`，沿用已验证 Haruna 的目录布局。 |
| `AppDir/shared/bin/kde-suite-filelight -> filelight` | 为改名后的 sharun 入口保留匹配的真实程序别名，原始 Filelight ELF 内容与位置不变。 |

完整代码位于 [部署入口](../deploy_suite_apps.sh)。这组值来自已核实的程序名称、上游样式与现有 AppDir 结构，不是固定应用版本。Filelight 本次未完成实机验证，不能把 Haruna 的既有验收扩大为 Filelight 已通过。
