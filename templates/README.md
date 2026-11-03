# 打包脚本标准模板

按来源、技术栈和实际入口选择一份完整模板。使用 [统一生成脚本](../scripts/build/generate_build_script.md) 生成应用目录下的构建脚本，只填写规范列出的占位参数。注释、顺序、缩进和空行保持原样。没有适用模板时，先新增并登记一份完整模板，再重写应用脚本。

## linuxdeploy / appimagetool

适用条件和占位参数见 [linuxdeploy 规范](../linuxdeploy_projects.md#唯一标准模板)。

| 模板 | 适用场景 |
| --- | --- |
| [linuxdeploy-gtk-deb.sh](./appimage/linuxdeploy-gtk-deb.sh) | GTK3，GitHub 正式 Release DEB |
| [linuxdeploy-gtk-apt.sh](./appimage/linuxdeploy-gtk-apt.sh) | GTK3，Ubuntu 仓库包 |
| [linuxdeploy-gtk-gstreamer-apt.sh](./appimage/linuxdeploy-gtk-gstreamer-apt.sh) | GTK3 + GStreamer，Ubuntu 仓库包 |
| [linuxdeploy-qt-deb.sh](./appimage/linuxdeploy-qt-deb.sh) | Qt，官网校验清单中的 DEB |
| [linuxdeploy-cli-apt.sh](./appimage/linuxdeploy-cli-apt.sh) | CLI / 无框架插件，Ubuntu 仓库包 |
| [appimagetool-direct.sh](./appimage/appimagetool-direct.sh) | 已有完整 AppDir，直接封装 |

## quick-sharun

适用条件和占位参数见 [quick-sharun 规范](../anylinux_projects.md#唯一标准模板)。模板在 Arch Linux 构建环境使用。

| 模板 | 适用场景 |
| --- | --- |
| [arch-native.sh](./quick-sharun/arch-native.sh) | Arch 官方仓库原生程序，从系统入口收集 |
| [electron-deb.sh](./quick-sharun/electron-deb.sh) | Electron，官方当前 DEB，版本取自包内 package.json |
| [electron-installed.sh](./quick-sharun/electron-installed.sh) | Electron，使用系统已安装的完整程序目录 |
| [tauri-gtk-deb.sh](./quick-sharun/tauri-gtk-deb.sh) | Tauri / GTK3，GitHub 正式 Release 的 DEB |
| [qt-deb.sh](./quick-sharun/qt-deb.sh) | Qt，AUR 指向的预编译官方 DEB |
| [qt-installed.sh](./quick-sharun/qt-installed.sh) | Qt 6，Arch 官方仓库程序，从系统入口收集 |
