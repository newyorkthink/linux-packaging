# Cursor AppImage

## 用途与产物

本目录动态下载 Cursor 官方 Linux x64 DEB，保留官方 Electron 程序和资源，通过 quick-sharun 生成 `dist/cursor.AppImage`。目标架构为 Linux x86_64。

## 技术栈与打包方式

本项目采用 [Electron 直接下载安装包标准模板](../anylinux_projects.md#直接下载安装包的标准模板)，打包分类见 [打包分类](../docs/packaging-classification.md)。模板允许软件名称、路径、依赖、下载接口和版本来源参数不同；通用代码、注释、执行阶段及空行逐行对齐。

| 配置 | 当前值 |
| --- | --- |
| AUR 软件包 | `cursor-bin` |
| 官方 DEB 程序目录 | `cursor-unpacked/usr/share/cursor/` |
| 主程序 | `MAIN_BIN=cursor` |
| 图标 | `/usr/share/pixmaps/co.anysphere.cursor.png` |
| 桌面入口 | `/usr/share/applications/cursor.desktop` |

构建脚本先安装基础包、应用及其依赖，再通过公共下载和解包入口取得官方 DEB，把完整程序目录原样放入 `AppDir/bin`。AUR 安装结果用于依赖、图标和 desktop，最终程序文件取自另行下载的官方 DEB。

quick-sharun 使用显式指定的主程序生成 AppRun，并收集 GTK 3 输入模块。程序目录中的 `chrome-sandbox` 和相邻资源继续保留。中文 locale 在第一次 quick-sharun 之后、最终封装之前生成，运行时通过 `.env` 使用包内的 `zh_CN.UTF-8`。

下载入口使用官方当前版本跳转地址，由 `common/download/download_file.sh` 下载。原有 `/usr/bin/hostname` 继续作为 quick-sharun 输入显式部署。

## 版本元数据

在原有打包前位置调用公共入口，从官方程序内的 `package.json` 根对象读取字符串 `version`：

```bash
# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" package-json AppDir/bin/resources/app/package.json --version-file "$HOME/version" --desktop "$DESKTOP")"
```

`--version-file` 保留原有 `~/version` 写入；`--desktop` 保留缺少 `X-AppImage-Version` 时追加版本的行为，不覆盖已有字段。这些操作均发生在 CI 构建环境中，执行位置仍在第一次 quick-sharun 之前。

最终 AppImage 生成成功后，再用一行公共调用保存同一个版本：

```bash
# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" dist/cursor.AppImage "$VERSION" dist/version.txt
```

公共保存入口先确认最终产物存在且非空，再写入 `dist/version.txt`。当前 workflow 使用 `SOFTWARE_KEY=cursor` 发布版本元数据。

## 运行

在仓库的 `cursor` 目录中打开 Linux 终端，已有构建产物时执行：

```bash
# 启动已生成的 AppImage。
./dist/cursor.AppImage
```

## 构建与发布

正式构建由 `.github/workflows/build.yml` 的标准 Arch matrix 执行，发布资产名为 `cursor.AppImage`。完成构建和发布后，当前 Job 更新自己的 `software_versions.json` 条目。

固定配置依据见 [docs/hardcoded.md](docs/hardcoded.md)，程序专属参数见 [docs/template-deviations.md](docs/template-deviations.md)。

## 变更记录

### 2026-10-29：统一公共版本读取与直接下载模板

版本读取改为原位置的单行公共调用，保留构建版本文件和 desktop 版本字段处理；末尾版本保存改为单行调用。两边脚本的行数、通用注释、代码结构和空行保持一致，清理项按同一顺序排列。README 与 docs 删除失效的旧流程说明，改为维护当前配置及其依据。

提交前检查 Bash 语法、两种版本来源、元数据写入和失败处理、模板逐行一致性、文档链接及完整差异。本次未在本地构建或启动 AppImage。
