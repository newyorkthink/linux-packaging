# QEMU 模板差异说明

## 标准底稿与来源核实

- **标准模板**：[arch-native.sh](../../Templates/quick-sharun/arch-native.sh)
- **构建脚本**：[build_qemu.sh](../build_qemu.sh)
- **上游参考**：[pkgforge-dev/QEMU-AppImage](https://github.com/pkgforge-dev/QEMU-AppImage/tree/9be8c9d4817443aae3301dfb22ba8de735013e2b)（完整取舍见 [pkgforge-differences.md](./pkgforge-differences.md)）。
- **程序来源**：Arch Linux 官方 `extra` 仓库提供预编译包 `qemu-desktop`、`qemu-tools`、`qemu-ui-gtk` 与 `virt-viewer`，适用 Arch 官方仓库原生程序系统入口路线。

## 依赖覆盖核对

对照 [install_packages.sh](../../Common/arch/install_packages.sh#L427-L440) 的 `--base` 清单与原有构建脚本：

- **`--base` 已覆盖（23 项）**：旧脚本中的 `base-devel`、`git`、`wget`、`curl`、`jq`、`binutils`、`patchelf`、`file`、`coreutils`、`findutils`、`grep`、`sed`、`gawk`、`tar`、`gzip`、`xz`、`unzip`、`rsync`、`util-linux`、`appstream-glib`、`desktop-file-utils`、`zsync`、`ca-certificates` 均已包含在 `--base` 中。
- **在 [build_qemu.sh](../build_qemu.sh#L13) 显式保留（4 项）**：`"qemu-desktop"`、`qemu-tools`、`qemu-ui-gtk`、`virt-viewer`（完整保留原运行与显示依赖）。

## 当前启用的模板差异

| 差异项 | 所在位置 | 来源与用途说明 |
| --- | --- | --- |
| 仓库提供的图标与桌面入口 | [build_qemu.sh](../build_qemu.sh#L21-L24) | Arch 包未提供统一顶层入口与固定图标路径，继续使用仓库内 [qemu.svg](../qemu.svg) 与 [qemu.desktop](../qemu.desktop)。 |
| `export STRACE_MODE=0` | [build_qemu.sh](../build_qemu.sh#L29-L30) | 本程序专属处理：保留原脚本构建期设置，在无真实图形与虚拟机设备环境下跳过收集阶段启动跟踪。 |
| 多入口、动态模块与数据目录收集 | [build_qemu.sh](../build_qemu.sh#L36) | 按模板单行传入 `/usr/bin/qemu-*`、`/usr/lib/qemu/*.so`、`/usr/bin/remote-viewer`、`/usr/share/qemu`，覆盖全部 QEMU 子命令、GTK 显示后端与 SPICE 客户端。 |
| 补回 `virt-viewer.mo` 与 `LANGUAGE=zh_CN` | [build_qemu.sh](../build_qemu.sh#L38-L41) | 本程序专属处理：由于 `remote-viewer` 与翻译域 `virt-viewer` 名称不一致，quick-sharun 裁剪翻译后补回 `/usr/share/locale/zh_CN/LC_MESSAGES/virt-viewer.mo`，并在 `AppDir/.env` 设置简体中文界面偏好。 |

## 未启用的上游处理

详见 [pkgforge-differences.md](./pkgforge-differences.md)：当前保持已实机验证的 `qemu-desktop` 最小桌面方案，未启用 `qemu-full`/`edk2-*`/`swtpm`/`virtiofsd`/`zenity-rs-bin`、`DEPLOY_OPENGL`/`DEPLOY_VULKAN`/`DEPLOY_PIPEWIRE`、`get-debloated-pkgs`、`self-updater.hook`、`symlinks.hook`、`UPINFO` 与 `--test`。

## 实机验证

实机验证通过记录见 [QEMU README](../README.md#实机验证)。
