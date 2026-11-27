# Picom 模板差异说明

## 标准底稿与来源核实

- **标准模板**：[arch-native.sh](../../Templates/quick-sharun/arch-native.sh)
- **构建脚本**：[build_picom.sh](../build_picom.sh)
- **上游核实**：在 `pkgforge-dev` 组织按 `picom` 与 `compton` 检索均无官方打包仓库；Arch Linux 官方 `extra` 仓库提供原生二进制包 `picom`（AUR 仅 `picom-git` 源码包，上游 `yshui/picom` 发布源码归档），适用 Arch 官方仓库原生程序系统入口路线。

## 依赖覆盖核对

对照 [install_packages.sh](../../common/arch/install_packages.sh#L357-L370) 的 `--base` 清单，原脚本依赖完整覆盖如下：

- **`--base` 已覆盖（13 项）**：`gcc`、`base-devel`、`wget`、`git`、`binutils`、`patchelf`、`coreutils`、`appstream-glib`、`desktop-file-utils`、`util-linux`、`zsync`、`hicolor-icon-theme`、`dbus`。
- **在 [build_picom.sh](../build_picom.sh#L13) 显式保留（23 项）**：`xorg-server`、`xorg-server-common`、`bash`、`glibc`、`gcc-libs`、`libconfig`、`libepoxy`、`libev`、`libglvnd`、`pcre2`、`pixman`、`libx11`、`libxext`、`libxcb`、`libxrender`、`libxrandr`、`libxinerama`、`libxdamage`、`libxfixes`、`xcb-util-image`、`xcb-util-renderutil`、`xorg-xprop`、`xorg-xwininfo`。

## 当前启用的模板差异

| 差异项 | 所在位置 | 原因与影响 |
| --- | --- | --- |
| `export DEPLOY_OPENGL=1` | [build_picom.sh](../build_picom.sh#L29-L30) | Arch `picom` 依赖 `libglvnd` 与 `libepoxy`，使用 `xrender`/`glx` 后端时需要部署 OpenGL/EGL 运行库；沿用 [Picom README](../README.md) 既定基线。开启后会按 quick-sharun 机制打包 OpenGL 运行依赖。 |

## 未继续保留的旧版导出变量

- **`APPNAME="picom"`**：已核对上游 `yshui/picom` 的 `picom.desktop` 已有 `Name=picom`，且 `uruntime2appimage.sh` 未设置 `APPNAME` 时自动读取 `Name=` 字段，同时本脚本已固定 `OUTNAME="picom.AppImage"`，省略与保留等价。
- **`STARTUPWMCLASS="picom"`**：上游 `picom.desktop` 声明了 `NoDisplay=true`、`StartupNotify=false` 与 `Exec=picom`（无窗口后台合成器）；已核对 `quick-sharun.sh` 未设置 `STARTUPWMCLASS` 时仅输出提示警告并自动写入相同的 `StartupWMClass=picom`，不改变最终 desktop 内容。

## 实机验证

实机验证通过记录见 [Picom README](../README.md#实机验证)。
