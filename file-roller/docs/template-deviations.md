# File Roller 模板差异

构建脚本由 [GTK Ubuntu 仓库模板](../../templates/appimage/linuxdeploy-gtk-apt.sh) 生成。`DEPLOY_GTK_VERSION` 改为 4。下面是模板之外的处理。

| 位置 | 处理及原因 | 代码或依据 |
| --- | --- | --- |
| 核心打包 | Ubuntu 24.04 的 file-roller 链接 `libgtk-4-1` 和 `libadwaita-1-0`。模板写死 `DEPLOY_GTK_VERSION=3`，生成后改为 4。GTK 插件查询 `gtk4.pc`，所以安装 `libgtk-4-dev`。 | `export DEPLOY_GTK_VERSION=4` |
| 准备桌面资源和运行库 | 复制 Ubuntu 简体中文语言包到 `usr/share/locale/zh_CN`。不生成、不设置 `LOCPATH`。 | 与 dconf-editor 相同 |
| AppRun | `LANG=zh_CN.UTF-8`、`LANGUAGE=zh_CN:zh`。启动前切到包内根目录。进程参数使用 `LC_ALL=zh_CN.UTF-8`，避免 rofi 带入的 `LC_ALL` 盖掉 `LANG`。不设置 `LOCPATH`。深色主题用 `GTK_THEME=Adwaita-dark`。 | 与 dconf-editor 的 `exec env LC_ALL=zh_CN.UTF-8` 相同 |
| 整理产物 | 把 ELF 里的 `/usr/share/locale` 改成相对路径 `usr/share/locale`。GTK4 fcitx 模块写入 `giomodule.cache`。 | [relocate_locale_paths.py](../patches/relocate_locale_paths.py)，与 dconf-editor 相同 |
| 整理产物 | GTK4 要在 `immodules/giomodule.cache` 登记 `libim-fcitx5.so: gtk-im-module`。客户端库文件名是 `libFcitx5GClient.so.*`。 | 实机警告 `GTK_IM_MODULE=fcitx` |
