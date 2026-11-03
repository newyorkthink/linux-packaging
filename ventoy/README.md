# Ventoy

本目录将 Ventoy 官方最新稳定 Linux Release 重新封装为单文件 AppImage，保持官方 Linux 包的完整目录结构和原始功能，不对 Ventoy 本体做功能删减或授权相关修改。

## 用途与产物

- 上游项目：`ventoy/Ventoy`
- 上游输入：最新稳定 Release 的 `ventoy-<版本>-linux.tar.gz`
- 目标架构：x86_64
- 构建脚本：`ventoy/build_ventoy.sh`
- Release 稳定资产名：`ventoy.AppImage`

AppImage 内保留官方 Linux Release 的完整 `ventoy/` 目录，包括 `VentoyGUI.x86_64`、各 GUI 后端、worker、工具、WebUI、boot image 和 Ventoy 运行资源。这里不做无依据的“瘦身”，避免破坏安装、更新、Secure Boot、分区或其他上游功能所需文件。

## 技术栈

Ventoy Linux 包不是单一 GTK 程序。其 x86_64 图形入口为原生 `VentoyGUI.x86_64` launcher，launcher 会根据可用环境选择 GTK2、GTK3 或 Qt5 GUI 后端；同时整个发行包还包含 Shell worker、原生工具、WebUI、boot image 和多架构辅助文件。

当前 AppImage 以官方 Linux tarball 为输入，目标架构为 x86_64。

## 打包方式

本项目采用“官方完整 Linux Release + 顶层 AppRun + 官方 appimagetool 直接封装”的路线，不使用 linuxdeploy 或 quick-sharun 重排 Ventoy 官方目录。

构建流程如下。

1. 公共工作目录入口使用独立临时目录下载和解包，重建本应用的 `AppDir` 和 `dist`。
2. 公共下载入口读取 `ventoy/Ventoy` 的 `/releases/latest`，从同一稳定 Release 取得 Linux 归档和 `sha256.txt`。入口校验两个资产的 GitHub SHA-256，再用官方清单复核归档，并返回版本号和 tag 对应的提交信息。
3. 公共解包入口解开归档。构建脚本把完整发行目录复制到 `AppDir/ventoy/`，生成桌面入口，并从 tag 对应的提交获取图标。
4. 公共入口生成包内简体中文 locale。构建脚本内联生成根 `AppDir/AppRun`，设置 locale、程序及运行库的搜索路径和无障碍桥接选项，再执行官方 `VentoyGUI.x86_64`。
5. 公共工具入口从官方 `/releases/latest` 下载并校验 appimagetool 和 Type 2 runtime。公共封装入口处理 AppDir 权限和图标，生成 `ventoy.AppImage`，输出 SHA-256 并写入 `dist/version.txt`。
6. 仓库统一的 `.github/workflows/build.yml` 构建并发布 `ventoy.AppImage`。软件版本来自本次下载的 Release。

应用专属处理及模板差异见[专属差异说明](./docs/template-deviations.md)。

## 运行与权限

顶层 `AppRun` 本身不执行 `sudo`、`pkexec`、systemd、udev、网络配置或系统文件修改，只负责启动官方 `VentoyGUI.x86_64`。

当前 AppImage 在 Linux 实机上应直接以 root 权限启动。Ventoy 需要枚举、分区并写入 USB / 磁盘块设备；实际测试中普通用户直接运行还可能在进入 Ventoy GUI 前出现内部 `VentoyGUI.x86_64: Permission denied`，因此不要依赖非 root 启动后再由上游提权。

在 `ventoy.AppImage` 所在目录打开 Linux 终端执行：

```bash
# 以 root 权限启动 Ventoy AppImage
sudo ./ventoy.AppImage
```

命令示例统一以“当前目录”为基准，不假设 AppImage 位于 `Downloads` 或其他固定路径。

GTK 和 Qt 界面在没有保存语言选择时默认使用简体中文。已有语言选择优先，也可在界面的语言菜单中切换。包内中文环境的配置依据见[固定配置说明](./docs/hardcoded.md)。

Ventoy 的核心功能是向用户选择的 USB / 磁盘设备安装或更新 Ventoy。实际安装 / 更新过程中，官方 worker 会进行分区和块设备写入。因此，执行安装、更新等磁盘操作前应确认 GUI 中选中的目标设备；这些操作可能重建分区或写入块设备。CI 执行下载校验和封装，不执行磁盘安装或更新。

## 构建与验证

- 公共入口校验最新稳定 Release 的两个资产摘要和官方 `sha256.txt`，并校验两个封装工具的摘要。
- 封装成功后，公共入口检查 AppImage 非空，输出 SHA-256 并写入 `dist/version.txt`。
- 2026-11-03 实机验证通过。Ventoy 1.1.18 AppImage 下载后通过 SHA-256 校验，上传用于核对的成品与 [GitHub Release](https://github.com/newyorkthink/linux-packaging/releases/tag/latest) 中的资产摘要一致。
- 执行 `sudo ventoy` 后，GTK3 界面显示简体中文并识别 U 盘。设备上的 Ventoy 从 1.1.17 升级到 1.1.18，界面提示更新成功，随后显示设备版本为 1.1.18。

## 变更记录

### 2026-10-30：补齐 appimagetool 要求的权限

- 故障依据：[Actions run 41010671616](https://github.com/newyorkthink/linux-packaging/actions/runs/41010671616) 的 Build Ventoy。appimagetool continuous build 333（git `b082d2e`，2026-10-29）报 `ventoy/tool/languages.json` 为 `0744`，没有生成 AppImage。
- 处理：封装前调用 `common/appimage/prepare_appdir_for_appimagetool.sh`。原 `appimagetool --runtime-file` 命令和 AppRun 未改。
- 验证范围：公共脚本做过语法检查和临时目录检查。没有重打 Ventoy，没有重跑 Actions。

### 2026-09-02：接入统一 AppImage 构建

- 现象：旧构建参考脚本固定到特定 Ventoy 版本，并依赖本地 `appimagetool.AppImage`；旧的 zsync 更新目标还指向其他仓库，无法作为本仓库持续构建方案。
- 根因：旧脚本是一次性本地打包逻辑，没有按本仓库的动态版本、供应链校验、统一 workflow 和稳定 Release 资产规则维护。
- 修改文件：`ventoy/build_ventoy.sh`、`ventoy/README.md`、`.github/workflows/build.yml`。
- 修复：改为官方 latest Release 动态解析，校验 Release digest 与 `sha256.txt`，完整保留官方 Ventoy Linux 包，并接入统一 `Build AppImages` workflow，发布稳定资产 `ventoy.AppImage`。
- 验证：构建脚本内加入 checksum、ELF、desktop、动态库、AppImage 提取和关键文件一致性检查；最终 CI 构建结果以对应 GitHub Actions run 为准。

### 2026-09-02：补充实际运行权限与语言说明

- 现象：普通用户直接启动 AppImage 时，可能在进入 GUI 前出现内部 `VentoyGUI.x86_64: Permission denied`；以 root 权限启动后 GUI 可以正常进入。中文图形会话无需额外导出 locale 环境变量。
- 根因：Ventoy 本身需要直接访问和写入块设备，当前 AppImage 的实际运行方式应以 root 启动为准；原 README 对非 root / `pkexec` 路径的说明与实机行为不一致。
- 修改文件：`ventoy/README.md`。
- 修复：明确统一使用当前目录下的 `sudo ./ventoy.AppImage` 启动，不再在示例中写死 `Downloads` 等目录；同时说明中文 locale 环境无需额外执行 `export LANG` / `LC_ALL`。
- 验证：Linux 实机中 `sudo ./ventoy.AppImage` 可进入 Ventoy GUI，并可在 `Language` 菜单中看到 `Chinese Simplified (简体中文)` 语言选项。

## 2026-09-16：接入统一软件版本元数据

- 版本继续来自 Ventoy 官方最新稳定 Release 的 tag，并与官方 Linux 包内 `ventoy/version` 保持现有一致性校验。
- 构建成功后将已经确认的 `VENTOY_VERSION` 写入 `dist/version.txt`。
- workflow 使用 `SOFTWARE_KEY=ventoy` 接入统一 `software_versions.json`；官方 Linux 包、AppRun、权限模型与封装方式保持不变。
