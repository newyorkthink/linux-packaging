# WorkBuddy AppImage

## 用途与产物

本目录动态下载 WorkBuddy 官方 Linux x64 DEB，保留官方 Electron 程序和资源，通过 quick-sharun 生成 `dist/workbuddy.AppImage`。目标架构为 Linux x86_64。

## 技术栈与打包方式

本项目采用 [Electron 直接下载安装包标准模板](../anylinux_projects.md#直接下载安装包的标准模板)，打包分类见 [打包分类](../docs/packaging-classification.md)。模板允许软件名称、路径、依赖、下载接口和版本来源参数不同；通用代码、注释、执行阶段及空行逐行对齐。

| 配置 | 当前值 |
| --- | --- |
| AUR 软件包 | `workbuddy` |
| 官方 DEB 程序目录 | `workbuddy-unpacked/opt/WorkBuddy/` |
| 主程序 | `MAIN_BIN=workbuddy` |
| 图标 | `/usr/share/icons/hicolor/512x512/apps/workbuddy.png` |
| 桌面入口 | `/usr/share/applications/workbuddy.desktop` |

构建脚本先安装基础包、应用及其依赖，再通过公共下载和解包入口取得官方 DEB，把完整程序目录原样放入 `AppDir/bin`。AUR 安装结果用于依赖、图标和 desktop，最终程序文件取自另行下载的官方 DEB。

quick-sharun 使用显式指定的主程序生成 AppRun，并收集 GTK 3 输入模块。程序目录中的 `chrome-sandbox` 和相邻资源继续保留。中文 locale 在第一次 quick-sharun 之后、最终封装之前生成，运行时通过 `.env` 使用包内的 `zh_CN.UTF-8`。

下载入口使用 `common/download/download_json_deb_asset.sh`，从官方更新 JSON 获取 URL 和 SHA-256，校验 DEB 类型、包名、版本及架构。接口版本的前三段仅用于 DEB 校验，文件名匹配保留构建号。

原有 `/usr/bin/ls`、`/usr/bin/mkdir`、`/usr/bin/ln`、`/usr/bin/grep` 继续作为 quick-sharun 输入显式部署。它们对应的真实故障证据保留在 [docs/hardcoded.md](docs/hardcoded.md)。

## 版本元数据

在原有打包前位置调用公共入口，从已安装的 AUR 软件包读取版本，保留去掉 epoch 和发行版 pkgrel 的规则：

```bash
# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" pacman workbuddy)"
```

公共入口复用 `common/arch/get_package_version.sh`。最终版本仍取自 AUR 安装结果，不使用 JSON 下载入口中的 DEB 校验版本覆盖它，也不增加 Cursor 专属的构建版本文件或 desktop 写入参数。

最终 AppImage 生成成功后，再用一行公共调用保存同一个版本：

```bash
# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" dist/workbuddy.AppImage "$VERSION" dist/version.txt
```

公共保存入口先确认最终产物存在且非空，再写入 `dist/version.txt`。当前 workflow 通过 `software_key: workbuddy` 发布版本元数据。

## 运行

在仓库的 `workbuddy` 目录中打开 Linux 终端，已有构建产物时执行：

```bash
# 启动已生成的 AppImage。
./dist/workbuddy.AppImage
```

## 构建与发布

正式构建由 `.github/workflows/build.yml` 的 WorkBuddy 独立 Arch Job 执行。该 Job 保留原有 Xvfb 检查，检查通过后发布 `workbuddy.AppImage`，再由当前 Job 更新自己的 `software_versions.json` 条目。

固定配置依据见 [docs/hardcoded.md](docs/hardcoded.md)，程序专属参数见 [docs/template-deviations.md](docs/template-deviations.md)。

## 变更记录

### 2026-10-29：统一公共版本读取与直接下载模板

版本读取改为原位置的单行公共调用，保留 AUR 版本来源和原有版本清理规则；末尾版本保存改为单行调用。两边脚本的行数、通用注释、代码结构和空行保持一致。README 与 docs 删除已经失效的临时克隆、asar 检查、启动壳和旧基线说明，保留当前参数所需的真实故障证据。

提交前检查 Bash 语法、两种版本来源、元数据写入和失败处理、模板逐行一致性、文档链接及完整差异。本次未在本地构建或启动 AppImage。

### 当前仍需保留的运行命令

原有 `ln`、`grep` 部署曾经由真实 Linux 运行反馈确认可消除对应的 `/bin/sh` 语法错误，提交为 `921ae73fe1cd4b351fe2f40a6f7eef26c7d698b1`。当前脚本继续保留这两项以及原有 `ls`、`mkdir` 输入，具体报错见 [docs/hardcoded.md](docs/hardcoded.md)。

## 当前可忽略的非致命日志

在 WorkBuddy 已正常启动并进入主界面的前提下，以下日志目前不属于 AppImage 打包故障，不应仅为了消除日志而修改稳定基线：

- `punycode` deprecated：Node / Electron 依赖弃用警告。
- `Glycin running without sandbox`：Glycin 运行警告，当前未造成启动或功能失败。
- `wb.js bundle NOT found`：当前主界面及已验证功能仍可正常运行；只有对应 webview / 扩展功能实际异常时再针对处理。
- `packaged linux runtime not found ... falling back to archive extraction`：WorkBuddy 会自动回退到归档解压流程；只要后续 `failed=0`，无需为此改包。
- `rpc slow` / `rpc VERY SLOW`：性能日志，不等同于构建或启动失败。

只有当某条日志能够稳定对应到明确的实际功能异常时，才单独定位和处理该问题。

## 用户数据

用户数据位于：

```text
~/.workbuddy/
```

该目录不属于 AppImage 构建内容，不得打包或上传。它可能包含账号会话、Connector token、自定义模型 API Key、对话历史和本地文件索引等私有数据。
