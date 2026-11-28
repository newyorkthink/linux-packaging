# KeePassXC 模板差异说明

## 标准底稿与来源核实

- **标准模板**：[qt-installed.sh](../../Templates/quick-sharun/qt-installed.sh)
- **构建脚本**：[build_keepassxc.sh](../build_keepassxc.sh)
- **上游参考**：[pkgforge-dev/KeePassXC-AppImage-Enhanced](https://github.com/pkgforge-dev/KeePassXC-AppImage-Enhanced/tree/b269e163fc3e47d3ccac95349c70f4642296b3ad)（完整取舍见 [pkgforge-differences.md](./pkgforge-differences.md)）。
- **程序来源**：Arch Linux 官方 `extra` 仓库直接提供 Qt6 原生包 `keepassxc`（含 `keepassxc`、`keepassxc-cli`、`keepassxc-proxy`），无需额外下载或源码编译。

## 依赖覆盖核对

对照 [install_packages.sh](../../Common/arch/install_packages.sh#L427-L440) 的 `--base` 清单与原有构建脚本：

- **`--base` 已覆盖（13 项）**：`appstream-glib`、`base-devel`、`binutils`、`coreutils`、`desktop-file-utils`、`gcc`、`libxkbcommon`、`patchelf`、`util-linux`、`wget`、`xclip`、`xdotool`、`zsync`。
- **模板固定依赖已覆盖或新增（4 项）**：`fcitx5-qt`、`lxqt-qtplugin` 为原脚本已有，模板另固定加入 `qt6ct` 与 `kvantum`。
- **主应用及保留依赖（`keepassxc` 另保留 34 项原有依赖并补入 `pcsclite`，含模板固定插件共 39 项附加参数）**：保留 `glycin`、`libheif`、`xorg-server`、`xorg-server-common`、`xorg-server-xvfb`、`libxcb`、`xcb-util`、`xcb-util-keysyms`、`libxss`、`xcb-util-renderutil`、`xcb-util-wm`、`xcb-util-image`、`xcb-util-cursor`、`libxkbcommon-x11`、`mesa`、`libglvnd`、`qt6-base`、`qt6-svg`、`libxtst`、`libvdpau`、`libva`、`libx11`、`libxext`、`libxfixes`、`libxi`、`libxinerama`、`adwaita-qt6`、`libsm`、`libice`、`libxrandr`、`libxrender`、`libxcursor`、`libxcomposite`、`libxdamage`，并按上游取舍补入 `pcsclite`；旧脚本重复出现的 `libxcb` 与 `xcb-util` 已去重，未遗漏任何既有运行依赖。

## 当前启用的模板差异

| 差异项 | 所在位置 | 来源与用途说明 |
| --- | --- | --- |
| 保留既有多入口与 X11 库并补入 `/usr/lib/libpcsclite_real.so*` | [build_keepassxc.sh](../build_keepassxc.sh#L36) | 在收集主程序 `keepassxc`、`keepassxc-cli`、`keepassxc-proxy` 的同时，保留原脚本已验证的 `xclip*`、`xdotool`、`libXtst.so.6`、`libxcb-xtest.so.0`，并按 `pkgforge-dev` 上游补入 PC/SC 智能卡真实共享库 `/usr/lib/libpcsclite_real.so*`。 |
| `keepassxc-proxy` 双层转发包装 | [build_keepassxc.sh](../build_keepassxc.sh#L48-L68) | 本程序专属处理：先改名保留 `AppDir/bin/keepassxc-proxy.real`（sharun 硬链接）与 `AppDir/shared/bin/keepassxc-proxy.real`（原始 ELF），在两个原位置写入仅执行 `exec` 的转发脚本并授权执行，确保浏览器从 Qt6 登记的 `shared/bin/keepassxc-proxy` 调用时经 sharun 加载包内依赖；详见 [quick-sharun-qt6-paths.md](./quick-sharun-qt6-paths.md)。 |
| `AppDir/shared/share -> ../share` 软链接 | [build_keepassxc.sh](../build_keepassxc.sh#L70-L71) | 本程序专属处理：作为 `2026-10-23` 已实机确认的稳定基线保留，使按 `shared/bin` 路径查找资源的路径可访问顶层 `share` 中的翻译与数据。 |

## 未启用的上游处理

详见 [pkgforge-differences.md](./pkgforge-differences.md)：未启用 `USE_HOST_DRIVERS_EXPERIMENTAL=1`、`get-debloated-pkgs`、`self-updater.hook`、`UPINFO`、`quick-sharun --test`，图标继续使用 Arch `keepassxc.svg`。
