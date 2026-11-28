# AionUi 固定配置

本页记录官网分发接口、包内布局和仓库产物约定。实际版本动态取自官网更新清单。

| 配置 | 当前取值 | 依据与用途 |
| --- | --- | --- |
| 构建依赖与架构 | `electron37-bin`、`aionui-bin`、`python-yaml`、`amd64` | 预先安装 `electron37-bin`，用其提供的 `electron37` 满足 `aionui-bin` 的依赖。PyYAML 用于读取清单，公共 DEB 入口核对目标架构。 [Electron 预编译包声明](https://github.com/archlinux/aur/blob/electron37-bin/.SRCINFO) · [AionUi 配方](https://github.com/archlinux/aur/blob/aionui-bin/PKGBUILD) |
| 官网清单与资产 | `https://static.aionui.com/releases/latest-linux.yml`、`https://static.aionui.com/releases/{version}`、`AionUi-{version}-linux-amd64.deb` | 官网按 Linux x64 渠道发布清单，并按清单版本和资产名下载校验。 [官方发布流程](https://github.com/iOfficeAI/AionUi/blob/e108b6b56b1a6eb99a00904878d0582f657b2908/.github/workflows/release-distribute.yml#L108-L167) |
| 包内路径 | `opt/AionUi`、`usr/share/applications/AionUi.desktop`、`resources/app.png`、`resources/bundled-aioncore/linux-x64/aioncore` | 保留官方应用与后端布局，从同一 DEB 取得图标和桌面入口。 [官方打包配置](https://github.com/iOfficeAI/AionUi/blob/e108b6b56b1a6eb99a00904878d0582f657b2908/packages/desktop/electron-builder.yml) · [AUR 配方](https://github.com/archlinux/aur/blob/aionui-bin/PKGBUILD) |
| 启动与产物 | `SHARUN_WORKING_DIR=${SHARUN_DIR}/bin`、`--no-sandbox --disable-setuid-sandbox`、`dist/aionui.AppImage`、`dist/version.txt` | 延续原便携入口的工作目录和 Chromium 参数，沿用现有发布资产名与版本路径。 [构建脚本](../build_aionui.sh) · [应用清单](../../.github/appimage-apps.json) |

流程差异和验收状态见[模板差异](./template-deviations.md)与[应用说明](../README.md#验证状态)。
