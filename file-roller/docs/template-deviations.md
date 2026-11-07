# File Roller 模板差异

构建脚本由 [GTK Ubuntu 仓库模板](../../templates/appimage/linuxdeploy-gtk-apt.sh) 生成。`DEPLOY_GTK_VERSION` 改为 4。下面是模板之外的处理。

| 位置 | 处理及原因 | 代码或依据 |
| --- | --- | --- |
| 核心打包 | Ubuntu 24.04 的 file-roller 链接 `libgtk-4-1` 和 `libadwaita-1-0`。模板写死 `DEPLOY_GTK_VERSION=3`，生成后改为 4。GTK 插件查询 `gtk4.pc`，所以安装 `libgtk-4-dev`。 | `export DEPLOY_GTK_VERSION=4` |
| 准备桌面资源和运行库 | 包内生成 `zh_CN.UTF-8`，并复制 Ubuntu 简体中文语言包。另解包 `gnome-themes-extra-data`，供深色 Adwaita 使用。 | `prepare_locale.sh`、`locale-langpack/zh_CN` |
| AppRun | 固定 `GTK_THEME=Adwaita:dark`，覆盖 GTK hook 的浅色主题。设置 `LANG=zh_CN.UTF-8`，并先切到包内根目录。 | `export GTK_THEME=Adwaita:dark` |
| 整理产物 | 把 ELF 里的 `/usr/share/locale` 改成相对路径。复制 `libfcitx5gclient.so*`，并确认包内有 `libim-fcitx5.so`。实机启动时 `GTK_IM_MODULE=fcitx` 找不到模块。 | [relocate_locale_paths.py](../patches/relocate_locale_paths.py) |
