# Folo 模板参数与重写说明

## 当前模板

构建脚本由 [generate_build_script.py](../../scripts/build/generate_build_script.py) 使用 [electron-github-deb.sh](../../templates/quick-sharun/electron-github-deb.sh) 生成。除模板允许的参数替换外，无新增代码、注释、分区或空行差异；不在生成后手工修改脚本。

该模板适用于官方 GitHub 正式 Release 使用非空标签前缀、提供完整 Electron DEB 且版本由同次下载记录的应用。保留先安装、再独立下载和解包两个阶段；完整程序目录原样复制到 `AppDir/bin`，由 quick-sharun 收集依赖并生成入口。

## 本次参数

| 参数 | Folo 取值 |
| --- | --- |
| `SYSTEM_PACKAGE` | `folo-bin` |
| `RELEASE_TAG_PREFIX` | `desktop/` |
| `GITHUB_REPOSITORY` | `RSSNext/Folo` |
| `RELEASE_ASSET_PATTERN` | `Folo-{version}-linux-x64.deb` |
| `DEB_PACKAGE`、`DEB_ARCH` | `folo`、`amd64` |
| `DEB_PROGRAM_DIR` | `usr/lib/folo` |
| `APP_NAME`、`MAIN_BIN`、`STARTUPWMCLASS` | `Folo`、`Folo`、`Folo` |
| `ICON` | `/usr/share/pixmaps/folo.png` |
| `DESKTOP` | `/usr/share/applications/folo.desktop` |
| `APP_BASENAME` | `folo` |
| `SYSTEM_SCAN_ARGS` | `AppDir/bin/* /usr/bin/hostname`，作为完整扫描列表提供。 |
| `DEPENDENCY_ARGS` | 保留原脚本中公共基础包以外的 30 个包，并增加 `fcitx5-gtk`；完整参数见生成脚本的安装行。 |

上述名称和路径的实际来源、原始元数据与标签兼容复现见 [固定配置说明](./hardcoded.md)。AUR 当前快照为 1.16.0，官方稳定 DEB 为 1.17.0；安装阶段只用来准备依赖和桌面资源，最终程序与版本均取自第二阶段独立下载，不锁定这两个核对版本。

## 完整扫描列表

模板的收集命令为 `quick-sharun __SYSTEM_SCAN_ARGS__`，扫描目标全部由应用按实际情况提供，不固定 `AppDir/bin/*` 再拼接额外列表。Folo 保留此前已验证的目录扫描，并恢复旧脚本已有的 `/usr/bin/hostname`；该命令由基础包中的 `inetutils` 提供，无需新增安装命令。

## 版本、GTK 与中文环境

公共下载入口在同次选择中绑定 Release 版本、唯一匹配资产和 GitHub SHA-256，并核对 DEB 包名及架构。仅向 stdout 返回版本，写入 `work/source-version.txt`；公共版本入口在第一次 quick-sharun 前读取该文本。

官方使用 `asar: true`，因此不套用独立 `package.json` 的版本路径，也不为读取版本解开 ASAR。最终产物成功生成后，公共保存入口写入 `dist/version.txt`，继续供现有软件版本清单流程使用。

保留模板的 `DEPLOY_GTK=1` 和包内中文 locale；IBus 由公共基础包安装，Fcitx5 GTK 模块由应用依赖提供，输入模块交给 quick-sharun 收集。官方提供 [简体中文翻译](https://github.com/RSSNext/Folo/blob/987e180426228e91d35d99abf445dd5d2f5b337f/locales/app/zh-CN.json)。语言环境、软件翻译和中文输入分别按其实际来源处理。

## 移除的模板外旧处理

2026-11-03 按标准重写时，以下旧实现未迁移到当时的新脚本、辅助脚本或启动链：

- 自写 GitHub Release JSON 解析、资产 URL 选择与摘要校验；由已有公共入口统一负责。
- 官方 AppImage 提取、资源和主程序动态查找、图标大小选择、包装层筛除。
- Node 模块权限改写与 ELF 审计、完整 ELF 枚举、构建期库搜索路径拼接及逐文件 ldd 检查。
- desktop 字段改写、自写 AppRun、固定 `--no-sandbox --disable-setuid-sandbox` 参数及 `~/version` 写入。
- `DEPLOY_OPENGL`、`DEPLOY_VULKAN`、`DEPLOY_PIPEWIRE`、`STRACE_MODE`、`NO_STRIP` 等模板外开关，以及显式音频、NSS、hostname 和输入模块扫描参数。
- 最终 AppImage 二次解包、资源和音频库断言、Node 检查、Xvfb 冒烟执行及日志判断。

后续仅恢复上文列明的 `hostname` 扫描项，其余旧处理保持原状。

这些移除源于当次标准重写范围。原运行依赖继续保留，现有 README 历史记录也完整保留。

## pkgforge-dev 核实与验证

2026-11-03 按 Folo 和旧名 Follow 在 pkgforge-dev 查找，未找到对应打包仓库，因此本次没有接入官方专属处理，也不创建空的专属代码取舍清单。

- 已完成：29 项离线检查，包括旧接口结果对比、前缀按字面筛选、版本排序、草稿和预发布过滤、无效摘要拒绝、真实 DEB 包名和架构核对、校验清单模式兼容及生成器逐字节复现。
- 已完成：官方 DEB SHA-256 与实际程序目录、desktop、图标核对；Bash 语法检查通过。
- 静态分析：公共脚本无 ShellCheck 告警；新模板和生成稿仅有继承的 `export ARCH="$(uname -m)"` 所对应的 SC2155，按模板保持原样。
- 后续构建：已核对 [Folo 成功构建日志](https://github.com/newyorkthink/linux-packaging/actions/runs/41739769283/job/126282889116)，其中可见 Electron、PipeWire、PulseAudio 及相关库的自动部署记录。
- 用户实测：2026-11-04 用户实机验证通过，启动、中文界面、深色显示、订阅与内容展示、AI 摘要卡片展示、中文输入候选及上屏、视频页面画面等结果和终端观察见 [README 实机验证](../README.md#实机验证)。
