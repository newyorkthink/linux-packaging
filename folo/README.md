# Folo AppImage

## 用途与产物

本目录从 [Folo 官方正式 Desktop Release](https://github.com/RSSNext/Folo/releases) 独立下载 Linux x64 DEB，使用 quick-sharun 重新封装，最终资产固定为 `folo.AppImage`。Folo 用于集中阅读 RSS 和其他订阅内容。

## 技术栈与打包方式

Folo 为 Electron / GTK3 桌面应用。构建脚本由 [Electron GitHub DEB 标准模板](../templates/quick-sharun/electron-github-deb.sh) 通过仓库生成器生成，在正式 Arch 构建环境中先安装 `folo-bin` 及运行依赖，再由公共入口按 `desktop/` 标签前缀选择官方稳定 DEB，核对 GitHub SHA-256、包名 `folo` 和架构 `amd64`。

解包后的 `usr/lib/folo` 整个目录原样放入 `AppDir/bin`，保留官方 Electron、ASAR 和相邻资源。图标与 desktop 使用 AUR 安装提供的系统资源；`DEPLOY_GTK=1` 由 quick-sharun 部署 GTK 和已安装的输入模块，并按模板生成包内中文 locale。启动入口由 quick-sharun 生成，现有统一 [Build AppImages](../.github/workflows/build.yml) 继续构建和发布。完整扫描列表由本应用填写，当前为 `AppDir/bin/*` 和 `/usr/bin/hostname`。

模板参数、旧处理移除范围和验证边界见 [模板参数与重写说明](./docs/template-deviations.md)，具体取值和兼容依据见 [固定配置说明](./docs/hardcoded.md)。本次按 Folo、Follow 查找 pkgforge-dev，未找到对应打包仓库。

## 版本元数据

公共下载入口把本次所选 Release 的实际版本保存为 `work/source-version.txt`，构建脚本在第一次 quick-sharun 前通过公共版本入口读取。最终 AppImage 成功生成后，公共保存入口写入 `dist/version.txt`。workflow 继续使用 `SOFTWARE_KEY=folo` 接入统一 `software_versions.json`，不把 AUR 安装版本当作最终 DEB 的版本。

## 运行

```bash
./folo.AppImage
```

## 实机验证

### 2026-11-04：用户实测（1.17.0）

依据用户提供的运行界面及终端截图记录，运行版本为 1.17.0。

| 项目 | 已确认结果 |
| --- | --- |
| 启动 | 主界面正常打开；终端记录 `Initialize Folo done` 和 `App is ready`。 |
| 中文界面与深色主题 | 导航、发现页和文章页显示中文，深色界面正常呈现。 |
| 订阅与内容展示 | 可切换订阅与内容视图，列表、文章正文和内嵌图片正常显示。 |
| AI 摘要展示 | 文章页可见中文 AI 摘要卡片。 |
| 中文输入 | 发现页中文输入候选框正常显示，已有界面截图也显示中文可上屏。 |
| 视频页面 | 视频条目页面可打开并显示画面；本项不包含实际出声的确认。 |
| 服务连接与设置同步 | 终端记录 `API Response: 200`、`PushReceiver connected` 和设置同步完成信息。 |

运行观察：

- Fontconfig 提示已有字体缓存由较新版本生成，其后程序完成初始化并展示上述界面。
- 终端出现 `first model result confidence is less than expected relative confidence` 提示，现有材料未确定其具体影响。
- 退出前记录 `Message 2 rejected by interface blink.mojom.Widget`，随后出现 `App is quitting` 并返回终端提示符；现有截图未确认该消息的影响或退出触发原因。

音频已有[成功构建日志](https://github.com/newyorkthink/linux-packaging/actions/runs/41739769283/job/126282889116)证明相关库和模块被收集；实际出声、外部协议回调及跨发行版功能仍未确认。上述已确认项目不再列为待验证。

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
- 后续验收：2026-11-04 用户实测已确认启动、中文界面、深色显示、内容展示和中文输入，详见上文实机验证；音频出声、协议回调及跨发行版功能仍未确认。

### 2026-11-04：按实际目标生成扫描行并恢复 hostname

- 模板改用完整的 `SYSTEM_SCAN_ARGS` 参数，不固定应用目录后再附加通用扫描参数；通过仓库生成器重新生成本脚本。
- 保留原有 `AppDir/bin/*`，恢复旧脚本已有的 `/usr/bin/hostname` 扫描项；不重复加入 quick-sharun 已自动部署的 NSS 和音频库。
- 检查：在禁网临时容器中运行仓库生成器，通过其内置 Bash 语法检查；完整差异确认构建脚本仅变更扫描行。后续 Folo 1.17.0 的用户实机结果已补充至上文，现有材料未单独验证辅助 `hostname` 命令的调用。
