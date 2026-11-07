# File Roller 模板差异

构建脚本由 [GTK Ubuntu 仓库模板](../../templates/appimage/linuxdeploy-gtk-apt.sh) 生成。除下表这一处外，注释、分区、命令顺序、缩进和空行与生成结果一致。

| 位置 | 处理及原因 | 代码或依据 |
| --- | --- | --- |
| 核心打包 | Ubuntu 24.04 的 file-roller 44.1 链接 `libgtk-4-1` 和 `libadwaita-1-0`，不是 GTK 3。模板写死 `DEPLOY_GTK_VERSION=3`，生成后改为 4。 | `export DEPLOY_GTK_VERSION=4` |

附带的旧 AppImage 是 Ubuntu 22.04 的 file-roller 3.42.0（GTK 3 / libhandy），没有作为本次底稿。`GTK_THEME`、`NO_AT_BRIDGE`、过宽的库搜索路径、整套图标字体和输入法模块都没有写进脚本。
