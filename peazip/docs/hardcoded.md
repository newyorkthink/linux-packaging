# PeaZip 固定配置

| 配置 | 用途与依据 |
| --- | --- |
| x86_64 Qt6 DEB 与 `peazip.AppImage` | 官方资产名由所选正式 Release 的版本动态展开。发布资产名与现有工作流一致。 |
| `Adwaita-Dark`、`xcb`、缩放 `1`、字体 DPI `96` | 沿用实机已使用的显示、主题和字体设置，随包提供对应 Qt6 样式与平台插件。 |
| Qt6Pas UTF-8 兼容层和两条预加载环境变量 | 修复已确认的可逆乱码。原 GCC 命令与主进程预加载链见[稳定基线](../README.md#已实机确认的稳定基线禁止改动)。 |
| `QMAKE=qmake6`、`NO_STRIP=1` | Qt 插件查询 Qt6 工具，沿用原有部署设置。 |
| `NO_AT_BRIDGE=1` | 保留旧 AppRun 的辅助功能兼容设置。 |
