# Parsec 固定配置

本页记录 `parsec-bin` 来源约定、固定桌面/图标路径及解码运行库清单。

| 配置 | 当前取值 | 依据与用途 |
| --- | --- | --- |
| AUR 下载源文件名 | `--wayback --source-filename 'parsec-bin-{version}.deb'` | AUR `parsec-bin` 的 `.SRCINFO` 使用泛化源文件名（如 `parsec-bin-<pkgver>.deb::...`）且 `pkgver` 含下划线（如 `150_104a`），需显式匹配源文件名模板并保留 Wayback 回退；不传递 `--version-file` 避免下划线版本校验冲突。 [构建脚本](../build_parsec.sh#L13-L21) |
| 主程序与 skel 路径 | `usr/bin/parsecd`、`usr/share/parsec/skel/appdata.json`、`parsecd-*.so`、`PATH_MAPPING='/usr/share/parsec:${SHARUN_DIR}/share/parsec'` | 独立解包主程序及官方动态模块与骨架配置，通过 `PATH_MAPPING` 映射至包内 `share/parsec`。 [构建脚本](../build_parsec.sh#L27-L68) |
| 图标与桌面入口 | `/usr/share/icons/hicolor/256x256/apps/parsecd.png`、`/usr/share/applications/parsecd.desktop`、`STARTUPWMCLASS="parsecd"` | 经实测官方 DEB 确认的固定安装路径与入口字段，替代旧脚本中的 `pacman -Ql` 动态扫描。 [构建脚本](../build_parsec.sh#L44-L48) |
| 解码与通用图形库 | `libavcodec.so.58`、`libavutil.so.56`、`libswresample.so.3`、`libjpeg.so.8`、`libva.so.2`、`libva-drm.so.2`、`libva-x11.so.2` | 满足 Parsec 官方 FFmpeg 4.4 ABI、libjpeg v8 ABI 与通用 VA-API loader；不固定打包 Intel/NVIDIA/VDPAU 厂商 backend。 [构建脚本](../build_parsec.sh#L64) · [回归记录](../README.md#修复与变更记录) |
| 环境与产物 | `zh_CN.UTF-8`（含 `LC_CTYPE`）、`dist/parsec.AppImage`、`dist/version.txt` | 保持中文 locale 支持与标准化版本输出路径。 [构建脚本](../build_parsec.sh#L71-L85) · [应用清单](../../.github/appimage-apps.json) |

流程差异见 [模板差异](./template-deviations.md)，上游取舍见 [上游差异](./pkgforge-differences.md)。
