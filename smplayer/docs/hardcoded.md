# SMPlayer 固定配置

| 项目 | 取值 | 依据与用途 |
| --- | --- | --- |
| 主包和系统入口 | `smplayer`，`/usr/bin/smplayer`，`/usr/bin/simple_web_server` | [Arch 软件包文件清单](https://archlinux.org/packages/extra/x86_64/smplayer/files/)提供主程序、网页服务程序、图标、桌面入口和翻译。软件版本取本次安装结果。 |
| 桌面信息 | `STARTUPWMCLASS=smplayer`，`/usr/share/icons/hicolor/scalable/apps/smplayer.svg`，`/usr/share/applications/smplayer.desktop` | 使用 SMPlayer 的窗口类和软件包自带资源。 |
| Qt5 插件 | `QT_DIR=qt`，`/usr/lib/qt/plugins/platforminputcontexts/libibusplatforminputcontextplugin.so`，`/usr/lib/qt/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so` | Arch Qt5 插件位于 `/usr/lib/qt/plugins`，IBus 与 Fcitx5 分别由 `qt5-base` 和 `fcitx5-qt` 提供。 |
| Qt5 深色主题 | `adwaita-qt5`，`QT_STYLE_OVERRIDE=Adwaita-Dark` | 使用 [Adwaita Qt5 软件包](https://github.com/archlinux/aur/blob/96fd23f159c119a5c83fd2ed27672822dc38c583/.SRCINFO)提供的 Qt5 样式。 |
| yt-dlp 与 Python | `yt-dlp/yt-dlp`，资产名 `yt-dlp`，`/usr/bin/yt-dlp`，`DEPLOY_PYTHON=1` | [官方发布文件说明](https://github.com/yt-dlp/yt-dlp/blob/2026.10.26/README.md#release-files)将该文件列为依赖 Python 的 zipimport 可执行版。构建时动态选取正式 Release。 |
| 数值 locale | `LC_ALL=`，`LC_NUMERIC=C` | 清空全局覆盖并固定数值解析，保留包内简体中文消息语言。 |
| 发布文件 | `dist/smplayer.AppImage`，`dist/version.txt` | 与现有构建清单、Release 资产名和版本清单接口一致。 |
