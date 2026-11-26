# Deskflow 模板差异说明

## 标准底稿与来源核实

- **标准模板**：[qt-installed.sh](../../templates/quick-sharun/qt-installed.sh)
- **构建脚本**：[build_deskflow.sh](../build_deskflow.sh)
- **上游核实**：在 `pkgforge-dev` 组织检索 `deskflow` 返回空，无官方打包仓库；Arch Linux 官方 `extra` 仓库提供原生 Qt6 二进制包 `deskflow`（上游 GitHub Releases 另提供 Debian `.deb` 与 Fedora `.rpm`，本仓库按 Arch 官方仓库原生程序路线采用系统入口模板）。

## 依赖覆盖核对

对照 [install_packages.sh](../../common/arch/install_packages.sh#L357-L370) 的 `--base` 清单与 [qt-installed.sh](../../templates/quick-sharun/qt-installed.sh#L13) 内置 Qt6 依赖，原脚本依赖完整覆盖如下：

- **`--base` 已覆盖（15 项）**：`gcc`、`base-devel`、`wget`、`binutils`、`patchelf`、`coreutils`、`appstream-glib`、`desktop-file-utils`、`util-linux`、`zsync`、`glib2`、`hicolor-icon-theme`、`libxkbcommon`、`openssl`、`xdotool`。
- **模板固定安装（4 项）**：`fcitx5-qt`、`qt6ct`、`kvantum`、`lxqt-qtplugin`（覆盖原脚本的 3 个 Qt6 主题插件并补齐 `fcitx5-qt` 输入模块）。
- **在 [build_deskflow.sh](../build_deskflow.sh#L13) 显式保留（25 项）**：`glycin`、`libheif`、`xorg-server`、`xorg-server-common`、`xorg-server-xvfb`、`glibc`、`libei`、`gcc-libs`、`libglvnd`、`libice`、`libportal`、`libsm`、`libx11`、`libxext`、`libxi`、`libxinerama`、`libxkbcommon-x11`、`libxkbfile`、`libxrandr`、`libxtst`、`qt6-base`、`qt6-declarative`、`qt6-svg`、`libvdpau`、`libva`。

## 当前启用的模板差异

| 差异项 | 所在位置 | 原因与影响 |
| --- | --- | --- |
| `export STARTUPWMCLASS="deskflow"` | [build_deskflow.sh](../build_deskflow.sh#L21-L22) | 保留原脚本窗口类设置，使窗口与 desktop 中的 `StartupWMClass` 对应。 |
| 复制上游翻译目录并建立软链接 | [build_deskflow.sh](../build_deskflow.sh#L50-L56) | Deskflow 从主程序同级 `translations` 与 `../share/deskflow/translations` 加载全部 `.qm` 翻译文件；仅收集 ELF 不会带入该目录，故沿用 2026-10-12 既定修复，复制 `/usr/share/deskflow/translations` 并链接到 `AppDir/bin/translations`（及存在时的 `AppDir/shared/bin/translations`）。 |
