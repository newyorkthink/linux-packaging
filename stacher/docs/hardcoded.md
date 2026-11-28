# Stacher 固定配置

本页记录官网端点、包内布局和仓库产物约定。实际版本取自本次下载的 DEB。

| 配置 | 当前取值 | 依据与用途 |
| --- | --- | --- |
| 构建依赖与来源 | AUR `stacher7`、`https://api.stacher.io/api/update/linux/x64/latest`、`amd64` | AUR 包用于准备 Arch 构建环境。官网更新端点用于独立取得本次封装的 DEB，公共 DEB 入口核对目标架构。 [Stacher 官网](https://www.stacher.io/) · [AUR 配方](https://github.com/archlinux/aur/blob/stacher7/PKGBUILD) |
| 包内路径 | `usr/lib/stacher7`、`usr/share/applications/stacher7.desktop`、`usr/share/pixmaps/stacher7.png` | 使用安装包原有的程序布局和桌面资源，AppImage 主程序为 `Stacher7`。 [AUR 配方](https://github.com/archlinux/aur/blob/stacher7/PKGBUILD) |
| 启动参数 | `SHARUN_WORKING_DIR=${SHARUN_DIR}/bin`、`--no-sandbox --disable-setuid-sandbox` | 延续原便携入口的工作目录和 Chromium 参数，并传递用户传入的参数。 [构建脚本](../build_stacher.sh) |
| 产物 | `dist/stacher.AppImage`、`dist/stacher.AppImage.sha256`、`dist/version.txt` | 沿用现有发布资产名、成品摘要和版本文件位置。 [构建脚本](../build_stacher.sh) · [应用清单](../../.github/appimage-apps.json) |

流程差异和验收状态见[模板差异](./template-deviations.md)与[应用说明](../README.md#变更记录)。
