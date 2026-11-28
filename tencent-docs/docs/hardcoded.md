# Tencent Docs 固定配置

本页记录官网下载接口、官方 DEB 包内布局及产物路径约定。实际版本号由官方接口每次构建时动态返回，不写死版本。

| 配置 | 当前取值 | 依据与用途 |
| --- | --- | --- |
| 构建依赖与来源 | AUR `tencent-docs-bin`、`https://docs.qq.com/api/package/get?channel_id=30001&version_id=latest&package_name=TencentDocs-x64.deb`、`tdappdesktop`、`amd64` | AUR 包提供 Arch 构建环境对照；正式封装包经官网接口动态下载并启用 `--ipv4-fallback`，公共入口核对 DEB 包名 `tdappdesktop` 与架构 `amd64`。 [腾讯文档下载页](https://docs.qq.com/home/download) · [AUR 配方](https://aur.archlinux.org/packages/tencent-docs-bin) |
| 包内路径 | `opt/腾讯文档`、`usr/share/applications/tdappdesktop.desktop`、`resources/icon.png` | 沿用实测官方 DEB 的安装目录及 `1024x1024` 图标资源，主程序为 `tdappdesktop`。实测 DEB 无多余 `*musl*` 文件。 [构建脚本](../build_tencent-docs.sh#L27-L38) |
| 运行与启动参数 | `SHARUN_WORKING_DIR=${SHARUN_DIR}/bin`、`SHARUN_EXTRA_LIBRARY_PATH=${SHARUN_DIR}/bin:${SHARUN_EXTRA_LIBRARY_PATH}`、`--lang=zh-CN` | 在 `.env` 中保留官方目录为工作目录与库搜索路径，并通过 `AppDir/bin/90-tencent-docs-arguments.hook` 固定简体中文界面参数后追加用户参数，替代自写 `AppRun.sh`。 [构建脚本](../build_tencent-docs.sh#L82-L90) |
| 产物与 CI | `dist/tencent-docs.AppImage`、`dist/version.txt`、`kind: standard`（`artifact_dir: tencent-docs/dist`） | 构建脚本直接通过公共入口写入 `dist/version.txt`，接入 `.github/workflows/build.yml` 标准矩阵发布流程。 [构建脚本](../build_tencent-docs.sh#L93-L96) · [应用清单](../../.github/appimage-apps.json) |

流程差异见 [模板差异](./template-deviations.md)，说明与历史变更见 [README](../README.md)。
