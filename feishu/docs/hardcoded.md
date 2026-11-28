# Feishu 固定配置

本页记录官方 JSON 接口约束、DEB 包内布局与运行环境变量约定。实际版本号每次构建由官方 API 动态返回，不写死版本。

| 配置 | 当前取值 | 依据与用途 |
| --- | --- | --- |
| 构建依赖与来源 | AUR `feishu-bin`、`https://www.feishu.cn/api/package_info?platform=10`、`bytedance-feishu-stable`、`amd64` | 通过公共 JSON DEB 入口限制 `feishucdn.com` 官方 CDN 域名、文件名正则与 MD5 摘要，并核对 DEB 包名与架构。 [构建脚本](../build_feishu.sh#L13-L21) |
| 包内路径 | `opt/bytedance/feishu`、`usr/share/applications/bytedance-feishu.desktop`、`product_logo_256.png` | 沿用实测官方 DEB 布局；包内主启动器为 `bytedance-feishu`（Shell 包装脚本调用 `feishu`），DEB 实测不含 `chrome-sandbox`、`vulcan/` 或嵌套 ELF。 [构建脚本](../build_feishu.sh#L27-L38) |
| 运行环境变量 | `SHARUN_WORKING_DIR=${SHARUN_DIR}/bin`、`SHARUN_EXTRA_LIBRARY_PATH=${SHARUN_DIR}/bin:${SHARUN_EXTRA_LIBRARY_PATH}`、`zh_CN.UTF-8` locale | 在 `AppDir/.env` 保留官方程序目录与相邻共享库搜索路径，替代自写 `AppRun.sh`。 [构建脚本](../build_feishu.sh#L72-L85) |
| 产物与 CI | `dist/feishu.AppImage`、`dist/version.txt`、`kind: standard`（`artifact_dir: feishu/dist`） | 沿用标准矩阵构建配置与统一版本文件位置。 [构建脚本](../build_feishu.sh#L88-L91) · [应用清单](../../.github/appimage-apps.json) |

流程差异见 [模板差异](./template-deviations.md)，应用说明见 [README](../README.md)。
