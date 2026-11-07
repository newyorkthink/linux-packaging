# File Roller 模板差异

构建脚本由 [GTK Ubuntu 仓库模板](../../templates/appimage/linuxdeploy-gtk-apt.sh) 生成。`DEPLOY_GTK_VERSION` 改为 4。下面是模板之外的处理。

| 位置 | 处理及原因 | 代码或依据 |
| --- | --- | --- |
| 核心打包 | Ubuntu 24.04 的 file-roller 链接 `libgtk-4-1` 和 `libadwaita-1-0`。模板写死 `DEPLOY_GTK_VERSION=3`，生成后改为 4。GTK 插件查询 `gtk4.pc`，所以安装 `libgtk-4-dev`。 | `export DEPLOY_GTK_VERSION=4` |
| 准备桌面资源和运行库 | 按标准生成包内 `zh_CN.UTF-8`。glibc 在 `LOCPATH` 下查找的目录名是 `zh_CN.utf8`，不能写成 `zh_CN.UTF-8`。另解包 `gnome-themes-extra-data`。不改 ELF 里的 locale 路径。 | `prepare_locale.sh` |
| AppRun | 中文环境使用标准三行：`LOCPATH`、`LANG=zh_CN.UTF-8`、`LANGUAGE=zh_CN:zh`。深色主题用 `GTK_THEME=Adwaita-dark`。 | 与 Joplin、Remmina 的中文写法相同 |
| 整理产物 | GTK4 要在 `immodules/giomodule.cache` 登记 `libim-fcitx5.so: gtk-im-module`。客户端库文件名是 `libFcitx5GClient.so.*`。 | 实机警告 `GTK_IM_MODULE=fcitx` |
