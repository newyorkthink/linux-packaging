# Ventoy 固定配置

## 默认简体中文

- 2026-11-03 的实测中，执行 `sudo ventoy` 后，Ventoy 1.1.18 的 GTK 界面显示 `Option`、`Language` 和 `Status - READY`。
- 构建时通过公共入口将 `zh_CN.UTF-8` 生成到 `AppDir/usr/lib/locale/zh_CN.UTF-8`。AppRun 把包内 locale 目录放在 `LOCPATH` 首位，并设置 `LANG=zh_CN.UTF-8`。
- 宿主机未生成中文 locale 时，AppRun 可读取包内数据。GTK 和 Qt 在没有保存语言选择时，根据 `LANG` 的 `zh_CN` 前缀选用自带的简体中文翻译。已有语言选择优先。
- 语言选择逻辑见 [Ventoy 1.1.18 GTK 源码](https://github.com/ventoy/Ventoy/blob/6116894ab8abdf3ef8d43411a6732d34ee19214e/LinuxGUI/Ventoy2Disk/GTK/ventoy_gtk.c#L848)和 [Qt 源码](https://github.com/ventoy/Ventoy/blob/6116894ab8abdf3ef8d43411a6732d34ee19214e/LinuxGUI/Ventoy2Disk/QT/ventoy2diskwindow.cpp#L245)。
