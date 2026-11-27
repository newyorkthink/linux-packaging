# Rofi 模板差异说明

## 标准底稿与来源核实

- **标准模板**：[arch-native.sh](../../templates/quick-sharun/arch-native.sh)
- **构建脚本**：[build_rofi.sh](../build_rofi.sh)
- **上游参考**：[pkgforge-dev/rofi-AppImage](https://github.com/pkgforge-dev/rofi-AppImage)（固定提交 `84953049a6ef24a02b722e4072c6dbc3e8d4fca9`，完整取舍见 [pkgforge-differences.md](./pkgforge-differences.md)）。
- **程序来源**：Arch Linux 官方 `extra` 仓库提供原生二进制包 `rofi`（主线已合并 Wayland 与 XCB 支持），AUR 仅 `rofi-git` 源码包，上游 `davatorium/rofi` 发布源码归档；适用 Arch 官方仓库原生程序系统入口路线。

## 依赖覆盖核对

对照 [install_packages.sh](../../common/arch/install_packages.sh#L357-L370) 的 `--base` 清单，原脚本依赖完整覆盖如下：

- **`--base` 已覆盖（15 项）**：`gcc`、`base-devel`、`wget`、`binutils`、`patchelf`、`coreutils`、`appstream-glib`、`desktop-file-utils`、`util-linux`、`zsync`、`gdk-pixbuf2`、`glib2`、`hicolor-icon-theme`、`libxkbcommon`、`pango`。
- **在 [build_rofi.sh](../build_rofi.sh#L13) 显式保留（17 项）**：`xorg-server`、`xorg-server-common`、`rofi-emoji`、`bash`、`cairo`、`glibc`、`libxcb`、`libxkbcommon-x11`、`startup-notification`、`wayland`、`xcb-imdkit`、`xcb-util`、`xcb-util-cursor`、`xcb-util-keysyms`、`xcb-util-wm`、`libva`、`libvdpau`。

## 当前启用的模板差异

| 差异项 | 所在位置 | 来源与用途说明 |
| --- | --- | --- |
| `export STARTUPWMCLASS="rofi"` | [build_rofi.sh](../build_rofi.sh#L21-L22) | 本程序专属处理：保留原脚本窗口类设置，使窗口与 desktop 中的 `StartupWMClass` 对应。 |
| `export DEPLOY_OPENGL=1` | [build_rofi.sh](../build_rofi.sh#L31-L32) | 本程序专属处理：保留 [Rofi README](../README.md) 既定基线，打包时部署 OpenGL 运行依赖。 |
| 复制 `rofi-datadir.src.hook` 至 `AppDir/bin/rofi-datadir.src.hook` | [build_rofi.sh](../build_rofi.sh#L40-L42) · [rofi-datadir.src.hook](../rofi-datadir.src.hook) | 复用 `pkgforge-dev/rofi-AppImage@84953049a6ef24a02b722e4072c6dbc3e8d4fca9` 的 `AppDir/bin/rofi-datadir.src.hook`（官方未说明原因）；补充 `XDG_DATA_DIRS` 并在首次运行时复制包内内置主题到用户数据目录，详见 [pkgforge-differences.md](./pkgforge-differences.md)。 |

## 未启用的上游处理

以下 `pkgforge-dev/rofi-AppImage` 项当前**未启用**，依据、原文与影响见 [pkgforge-differences.md](./pkgforge-differences.md)：

- `export URUNTIME_PRELOAD=1`（未启用）
- `get-dependencies.sh` 源码 `meson` 编译与 `get-debloated-pkgs`（未启用）
- `ADD_HOOKS="self-updater.hook"`、`UPINFO`、`quick-sharun --test`（未启用）

## 实机验证

实机验证通过记录见 [Rofi README](../README.md#实机验证)。
