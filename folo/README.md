# Folo AppImage

## 用途与产物

本目录从 [Folo 官方正式 Desktop Release](https://github.com/RSSNext/Folo/releases) 独立下载 Linux x64 DEB，使用 quick-sharun 重新封装，最终资产固定为 `folo.AppImage`。Folo 用于集中阅读 RSS 和其他订阅内容。

## 技术栈与打包方式

Folo 为 Electron / GTK3 桌面应用。构建脚本由 [Electron GitHub DEB 标准模板](../templates/quick-sharun/electron-github-deb.sh) 通过仓库生成器生成，在正式 Arch 构建环境中先安装 `folo-bin` 及运行依赖，再由公共入口按 `desktop/` 标签前缀选择官方稳定 DEB，核对 GitHub SHA-256、包名 `folo` 和架构 `amd64`。

解包后的 `usr/lib/folo` 整个目录原样放入 `AppDir/bin`，保留官方 Electron、ASAR 和相邻资源。图标与 desktop 使用 AUR 安装提供的系统资源；`DEPLOY_GTK=1` 由 quick-sharun 部署 GTK 和已安装的输入模块，并按模板生成包内中文 locale。启动入口由 quick-sharun 生成，现有统一 [Build AppImages](../.github/workflows/build.yml) 继续构建和发布。

模板参数、旧处理移除范围和验证边界见 [模板参数与重写说明](./docs/template-deviations.md)，具体取值和兼容依据见 [固定配置说明](./docs/hardcoded.md)。本次按 Folo、Follow 查找 pkgforge-dev，未找到对应打包仓库。

## 版本元数据

公共下载入口把本次所选 Release 的实际版本保存为 `work/source-version.txt`，构建脚本在第一次 quick-sharun 前通过公共版本入口读取。最终 AppImage 成功生成后，公共保存入口写入 `dist/version.txt`。workflow 继续使用 `SOFTWARE_KEY=folo` 接入统一 `software_versions.json`，不把 AUR 安装版本当作最终 DEB 的版本。

## 运行

```bash
./folo.AppImage
```

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加 `dist/version.txt` 与 workflow 清单接入，不改变现有 Folo Electron 运行目录、音频依赖、输入法或启动逻辑。

### 2026-09-23：为 GitHub Releases API 接入统一认证

- 故障现象：构建读取 Folo Releases API 时收到 HTTP 403，在下载官方 AppImage 前退出。
- 根因：应用脚本直接发起未认证的 GitHub API 请求，容易触发匿名请求限额。
- 修改文件：`folo/build_folo.sh`、本 README。
- 修复内容：改用仓库现有 `common/github/github_api.sh` 请求 Release 元数据，自动使用 workflow 提供的 `GH_TOKEN`，并保留原有稳定版筛选、资产 URL 与摘要校验逻辑。
- 已知结果：API 请求已接入统一认证与重试入口；实际构建结果以下一次 Actions 为准。

### 2026-11-03：通过生成器迁移到标准 DEB 模板

- 修改对象：本目录构建脚本和说明、公共 GitHub Release 下载与解析入口，以及新模板的登记和生成器参数。
- 原有问题：旧脚本自行解析 AppImage、定位资源、审计 ELF、写入 AppRun 并执行最终解包和 Xvfb 冒烟检查；现有公共版本入口也不识别 `desktop/v<version>` 标签。
- 修改内容：公共入口新增显式 `--tag-prefix`，不传选项的旧调用保持原规则；登记完整 Electron GitHub DEB 模板，并由生成器重写本脚本。模板外的旧处理全部移除，历史变更记录保留。
- 验证：29 项离线检查通过，覆盖旧接口对比、前缀筛选、摘要拒绝、真实 DEB 身份检查和生成器逐字节复现；官方 DEB 的 SHA-256、目录、desktop 和图标已核对。Bash 语法检查通过；ShellCheck 在生成稿和新模板上仅提示既有 `export ARCH="$(uname -m)"` 的 SC2155，按模板保留。
- 验证边界：本轮未执行完整 AppImage 构建或 Folo 运行测试；本次修改不作为音频、中文输入、协议回调或跨发行版功能验收的依据。
