# File Roller 模板差异

构建脚本由 [GTK Ubuntu 仓库模板](../../templates/appimage/linuxdeploy-gtk-apt.sh) 生成。`DEPLOY_GTK_VERSION` 改为 4。下面是模板之外的处理。

| 位置 | 处理及原因 | 代码或依据 |
| --- | --- | --- |
| 核心打包 | Ubuntu 24.04 的 file-roller 链接 `libgtk-4-1` 和 `libadwaita-1-0`。模板写死 `DEPLOY_GTK_VERSION=3`，生成后改为 4。GTK 插件查询 `gtk4.pc`，所以安装 `libgtk-4-dev`。 | `export DEPLOY_GTK_VERSION=4` |
| 准备桌面资源和运行库 | 解包 `gnome-themes-extra-data`。不再打包 locale 数据。 | `gnome-themes-extra-data` |
| AppRun | 只设置 `LANG=zh_CN.UTF-8` 和 `LANGUAGE=zh_CN:zh`，不设置 `LOCPATH`。Ubuntu 24.04 打出来的 locale 数据被实机 C 库拒绝，`LOCPATH` 又会挡住系统里可用的 `zh_CN.UTF-8`。深色主题用 `GTK_THEME=Adwaita-dark`。 | 实机警告 `Locale not supported by C library` |
| 整理产物 | GTK4 要在 `immodules/giomodule.cache` 登记 `libim-fcitx5.so: gtk-im-module`。客户端库文件名是 `libFcitx5GClient.so.*`。 | 实机警告 `GTK_IM_MODULE=fcitx` |
