# FreeRDP 模板差异说明

## 标准底稿与来源核实

- **标准模板**：[arch-native.sh](../../templates/quick-sharun/arch-native.sh)
- **构建脚本**：[build_freerdp.sh](../build_freerdp.sh)
- **上游核实**：在 `pkgforge-dev` 组织检索 `freerdp` 返回空，无官方打包仓库；Arch Linux 官方 `extra` 仓库提供预编译原生包 `freerdp`（AUR 仅源码包 `freerdp-git` 与旧版 `freerdp2`，上游 `FreeRDP/FreeRDP` 发布源码归档），适用 Arch 官方仓库原生程序系统入口路线。

## 依赖覆盖核对

对照 [install_packages.sh](../../common/arch/install_packages.sh#L357-L370) 的 `--base` 清单，原脚本依赖完整覆盖如下：

- **`--base` 已覆盖（14 项）**：`gcc`、`base-devel`、`wget`、`binutils`、`patchelf`、`coreutils`、`appstream-glib`、`desktop-file-utils`、`util-linux`、`zsync`、`xclip`、`libxkbcommon`、`make`、`pkgconf`。
- **在 [build_freerdp.sh](../build_freerdp.sh#L13) 显式保留（34 项）**：`glycin`、`libheif`、`xorg-server`、`xorg-server-common`、`xorg-server-xvfb`、`wl-clipboard`、`fcitx5-qt`、`egl-wayland`、`libxcb`、`xcb-util`、`xcb-util-keysyms`、`libxss`、`extra-cmake-modules`、`xcb-util-renderutil`、`xcb-util-wm`、`xcb-util-image`、`xcb-util-cursor`、`libxkbcommon-x11`、`mesa`、`libglvnd`、`giflib`、`libpng`、`libx11`、`libxft`、`libxrender`、`libxcomposite`、`libxdamage`、`libxfixes`、`libxext`、`libxinerama`、`freetype2`、`libjpeg-turbo`、`libdecor`、`alsa-plugins`。

## 当前启用的模板差异

| 差异项 | 所在位置 | 原因与影响 |
| --- | --- | --- |
| 仓库提供的图标与桌面入口 | [build_freerdp.sh](../build_freerdp.sh#L21-L24) | Arch `freerdp` 软件包未提供 AppImage 所需的统一图标和 `xfreerdp3` 桌面入口，继续使用仓库内 [freerdp.png](../freerdp.png) 与 [freerdp.desktop](../freerdp.desktop)。 |
| `export PATH_MAPPING` | [build_freerdp.sh](../build_freerdp.sh#L29-L30) | 将 `/usr/lib/freerdp/server/proxy/plugins` 映射到 `${SHARUN_DIR}/lib/freerdp/server/proxy/plugins`，确保运行期查找包内 FreeRDP 代理插件。 |
| 收集代理插件 `.so` 与打包前检查 | [build_freerdp.sh](../build_freerdp.sh#L35-L46) | 扫描 `/usr/lib/freerdp/server/proxy/plugins/*.so` 并在缺少插件时中止构建，随后连同 9 个 FreeRDP / WinPR 可执行文件一并交给 `quick-sharun`。 |
| 核对插件与 `path-mapping` 落盘 | [build_freerdp.sh](../build_freerdp.sh#L48-L53) | 沿用 [FreeRDP README](../README.md#修复记录) 2026-09-12 修复后的构建守卫，确认代理插件、`AppDir/lib/sharun-preload/path-mapping.so` 与 `AppDir/.env` 映射规则已正确写入。 |

## 未继续保留的旧版导出变量

- **`STARTUPWMCLASS=xfreerdp3`**：仓库维护的 [freerdp.desktop](../freerdp.desktop#L2) 已经显式声明 `StartupWMClass=xfreerdp3`；已核对 `quick-sharun.sh` 检测到 desktop 文件已含 `StartupWMClass=` 时会直接跳过环境变量，省略与保留等价。

## 实机验证

实机验证通过记录见 [FreeRDP README](../README.md#实机验证)。
