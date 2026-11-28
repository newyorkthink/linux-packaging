# Zotero 固定配置

本页记录官网下载接口、包内布局和仓库产物约定。实际版本取自下载归档内的 Mozilla 应用配置。

| 配置 | 当前取值 | 依据与用途 |
| --- | --- | --- |
| 构建依赖与来源 | Arch Extra `zotero`、`https://www.zotero.org/download/client/dl?channel=release&platform=linux-x86_64` | 用 Arch 包准备系统依赖，再独立取得官网 Linux x86_64 正式版归档。 [Arch Extra 软件包](https://archlinux.org/packages/extra/x86_64/zotero/) · [官方下载页](https://www.zotero.org/download/) |
| 归档路径与版本 | `Zotero_linux-x86_64`、`app/application.ini` 的 `Version` 字段 | 保持 Mozilla 程序与相邻运行资源布局，以本次归档的版本为准。 [官方安装说明](https://www.zotero.org/support/installation#official_tarball) · [官方 Linux 启动器](https://github.com/zotero/zotero/blob/main/app/linux/zotero) |
| 桌面入口与图标 | `Exec=zotero -url %U`、`icons/icon128.png`、`STARTUPWMCLASS=zotero` | 保留原有桌面启动行为和窗口匹配，使用本次归档内的官方图标。 [构建脚本](../build_zotero.sh) |
| 产物 | `dist/zotero.AppImage`、`dist/version.txt` | 沿用现有发布资产名和版本文件位置。 [应用清单](../../.github/appimage-apps.json) |

流程差异见[模板差异](./template-deviations.md)，产物及用法见[应用说明](../README.md)。
