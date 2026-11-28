# SimpleScreenRecorder 模板差异说明

## 标准底稿与来源核实

- **标准模板**：[qt-installed.sh](../../Templates/quick-sharun/qt-installed.sh)
- **构建脚本**：[build_simplescreenrecorder.sh](../build_simplescreenrecorder.sh)
- **上游核实**：
  - 在 [上游打包参考索引](../../Docs/upstream-packaging-index.md#L96) 中该项为空；检索 `pkgforge-dev` 组织下的 `simplescreenrecorder` 与 `ssr` 均无对应官方打包仓库（第三方 `ivan-hc/SimpleScreenRecorder-appimage` 不属于 `pkgforge-dev`），故不创建 `pkgforge-differences.md`。
  - Arch Linux 官方仓库已不再提供 `simplescreenrecorder`；[MaartenBaert/ssr](https://github.com/MaartenBaert/ssr) Releases 与 [官方网站](https://www.maartenbaert.be/simplescreenrecorder/) 均不提供预编译二进制安装包，AUR 也无 `-bin` 或 `simplescreenrecorder-qt5` 包。
  - 当前 AUR [`simplescreenrecorder`](https://aur.archlinux.org/packages/simplescreenrecorder)（`0.4.4.79.ge73e-4`，固定上游提交 `e73e07664121ac30836872bca76194c6570e04c8`）及 [`simplescreenrecorder-git`](https://aur.archlinux.org/packages/simplescreenrecorder-git) 已使用 `-DWITH_QT6=TRUE -DWITH_QT5=FALSE`、依赖 `qt6-base` 与 `qt6-tools` 构建。按 [AGENTS.md](../../AGENTS.md) 上游框架升级后整体迁移要求，本次整体迁移至 Qt6 并沿用系统入口标准。

## 依赖覆盖核对

对照 [install_packages.sh](../../Common/arch/install_packages.sh#L427-L440) 的 `--base` 清单与 [qt-installed.sh](../../Templates/quick-sharun/qt-installed.sh#L13) 内置 Qt6 依赖，原脚本 52 项软件包核对如下：

- **`--base` 已覆盖（12 项）**：`gcc`、`base-devel`、`wget`、`binutils`、`patchelf`、`coreutils`、`appstream-glib`、`desktop-file-utils`、`util-linux`、`zsync`、`libxkbcommon`、`xclip`。
- **模板固定安装（4 项，[build_simplescreenrecorder.sh](../build_simplescreenrecorder.sh#L13)）**：`fcitx5-qt`、`qt6ct`、`kvantum`、`lxqt-qtplugin`（保留原 `fcitx5-qt`、`kvantum`、`lxqt-qtplugin`，由 `qt6ct` 替代旧版 `qt5ct`）。
- **显式保留的非 Qt5 依赖（30 项，[build_simplescreenrecorder.sh](../build_simplescreenrecorder.sh#L13)）**：`glycin`、`libheif`、`xorg-server`、`xorg-server-common`、`xorg-server-xvfb`、`ffmpeg`、`alsa-lib`、`jack2`、`libpulse`、`libx11`、`libxext`、`libxfixes`、`libxi`、`libxinerama`、`glu`、`gtk-update-icon-cache`、`libglvnd`、`mesa`、`egl-wayland`、`libxcb`、`xcb-util`、`xcb-util-keysyms`、`libxss`、`extra-cmake-modules`、`xcb-util-renderutil`、`xcb-util-wm`、`xcb-util-image`、`xcb-util-cursor`、`libxkbcommon-x11`、`wl-clipboard`。
- **已迁移移除的 Qt5 旧包（5 项）**：`qt5-base`、`qt5-x11extras`、`adwaita-qt5`、`qt5-svg`、`qt5-tools`（连同由 `qt6ct` 替代的 `qt5ct` 共 6 项 Qt5 包；AUR `simplescreenrecorder` 已自行声明运行时依赖 `qt6-base` 与构建依赖 `qt6-tools`）。

## 当前启用的模板差异

| 差异项 | 所在位置 | 原因与影响 |
| --- | --- | --- |
| `export STARTUPWMCLASS="simplescreenrecorder"` | [build_simplescreenrecorder.sh](../build_simplescreenrecorder.sh#L21-L22) | 保留原脚本窗口类设置，使运行窗口与 `be.maartenbaert.simplescreenrecorder.desktop` 中的 `StartupWMClass` 对应。 |
| `export DEPLOY_OPENGL=1` | [build_simplescreenrecorder.sh](../build_simplescreenrecorder.sh#L31-L32) | 保留原脚本 OpenGL 运行库部署配置，对应 AUR `simplescreenrecorder` 的 `libglvnd` 依赖与 OpenGL 录制场景。 |

## 未改动部分与核对边界

脚本初始化、公共基础包、工作区准备、`ARCH`/`ICON`/`DESKTOP`/`OUTPATH`/`OUTNAME`/`DEPLOY_QT=1`、公共版本读取、`quick-sharun /usr/bin/simplescreenrecorder`、包内 `zh_CN.utf8` locale 生成、`quick-sharun --make-appimage` 与公共版本保存均与 [qt-installed.sh](../../Templates/quick-sharun/qt-installed.sh) 一致；说明见 [SimpleScreenRecorder README](../README.md)。

本次按本地工作区直接最终版例外完成静态结构、依赖覆盖、链接及 Git 文件模式核对，未在本机执行实际容器打包或实机运行测试，也不监控 GitHub Actions。
