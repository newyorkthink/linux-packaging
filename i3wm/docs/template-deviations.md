# i3wm 模板差异说明

## 标准底稿与来源核实

- **标准模板**：[arch-native.sh](../../Templates/quick-sharun/arch-native.sh)
- **构建脚本**：[build_i3wm.sh](../build_i3wm.sh)
- **上游核实**：在 `pkgforge-dev` 组织检索 `i3` 返回空，无官方打包仓库；Arch Linux 官方 `extra` 仓库提供原生二进制包 `i3-wm`（上游 `i3/i3` 发布源码归档），适用 Arch 官方仓库原生程序系统入口路线。

## 依赖覆盖核对

对照 [install_packages.sh](../../Common/arch/install_packages.sh#L357-L370) 的 `--base` 清单，原脚本依赖完整覆盖如下：

- **`--base` 已覆盖（12 项）**：`gcc`、`base-devel`、`wget`、`binutils`、`patchelf`、`coreutils`、`appstream-glib`、`desktop-file-utils`、`util-linux`、`zsync`、`perl`、`dbus`。
- **在 [build_i3wm.sh](../build_i3wm.sh#L13) 显式保留（14 项）**：`xorg-server`、`xorg-server-common`、`xorg-server-xvfb`、`i3status`、`dmenu`、`xss-lock`、`perl-anyevent-i3`、`perl-json-xs`、`xorg-xrandr`、`xorg-xset`、`xorg-xprop`、`xorg-xmodmap`、`xorg-xsetroot`、`xorg-xmessage`。

## 当前启用的模板差异

| 差异项 | 所在位置 | 原因与影响 |
| --- | --- | --- |
| `export STARTUPWMCLASS="i3"` | [build_i3wm.sh](../build_i3wm.sh#L21-L22) | 保留原脚本窗口类设置，使窗口与 desktop 中的 `StartupWMClass` 对应。 |
| `export PATH_MAPPING` | [build_i3wm.sh](../build_i3wm.sh#L31-L35) | 将 `/etc/i3` 与 `/etc/i3status.conf` 映射到 `${SHARUN_DIR}/etc/...`，确保读取 AppImage 内置默认配置。 |
| 复制默认配置文件至 `AppDir/etc` | [build_i3wm.sh](../build_i3wm.sh#L43-L46) | 打包 `/etc/i3` 目录与 `/etc/i3status.conf`，配合 `PATH_MAPPING` 提供完整默认配置。 |

## 打包边界（延续既定基线）

- 不打包 `/usr/bin/perl`（单独打包会缺少核心模块，`i3-dmenu-desktop`、`i3-save-tree` 等继续使用宿主 Perl）。
- 不打包 `i3lock` 与 `slock`（与主 AppImage 的认证及权限模型冲突），仅保留 `xss-lock` 调用宿主锁屏程序。

## 实机验证

实机验证通过记录见 [i3wm README](../README.md#实机验证)。
