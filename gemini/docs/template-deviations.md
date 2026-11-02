# Gemini 标准模板差异

`build_gemini.sh` 的通用阶段遵循 [Anylinux / quick-sharun 规范](../../anylinux_projects.md)，参数和专属处理按本文件保留。Gemini 使用 Windows 产品层配合 Linux Electron 的移植路线；主脚本保持基础工具、运行依赖、目录准备、下载、解包、资源组装、打包元数据、版本读取、依赖收集、中文 locale、封装和版本保存的顺序。

## 来源与系统安装阶段

- 位置：基础包及运行依赖安装之后，打包元数据之前。
- 依据：Google 官方桌面下载入口提供 Windows 和 macOS 版本，当前使用 Windows x64 完整 NSIS 包，不把 Windows 安装程序安装到 Linux 构建系统。
- AUR 核对：2026-11-02 读取了 `gemini-desktop-bin` 的 [PKGBUILD](https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=gemini-desktop-bin) 和 [.SRCINFO](https://aur.archlinux.org/cgit/aur.git/plain/.SRCINFO?h=gemini-desktop-bin)。其版本为 `1.15.0-1`，使用系统 `electron44`、自编译 Rust Linux 模块及额外产品层修改，并非可原样安装的 Google Linux 桌面二进制。本项目不安装或复制这套替代实现，也不编译原生模块。
- 差异与影响：保留既有移植路线，只通过公共入口安装真实运行依赖；正式程序来自独立下载的 Google 完整包及匹配的官方 Linux Electron runtime，不冒称已经完成不存在的 Google Linux 包系统安装。

## 下载、校验和解包

- 位置：目录准备之后。
- 处理：`download_omaha_package.sh` 负责请求、XML 解析、包名与来源限制、大小和 SHA-256；`extract_archive.sh` 负责 NSIS 和 ZIP 解包；`download_latest_checksum_asset.sh` 负责根据官方 SHA-256 清单下载唯一匹配的 Linux runtime。
- 依据与影响：复用已存在的公共入口，主脚本不再维护联网请求、摘要解析或通用格式解包。应用版本及 runtime 版本仍动态取得，不回退旧 Release，也不锁定旧工具。
- 目录：继续通过现有工作区入口清理本项目的 `cache`、`work`、`AppDir`、`dist`；`cache` 清理后不重建。软件的正常配置目录不在清理范围。

## 精确运行时版本

- 位置：完整包解开并定位唯一 `resources/app.asar` 后，下载 Linux runtime 前。
- 处理：保留从对应 `Gemini.exe` 的 ASCII / UTF-16LE 内嵌标识读取精确 Electron 版本的既有命令；找不到时明确失败。
- 依据：1.17.0 实包内的 `package.json` 声明开发依赖 `^42.4.1`，同一目录的实际程序却标识 `Electron/44.5.1`。开发依赖范围不能作为实际 runtime 版本，因而不采用 pkgforge 的该项读取，也不继续使用旧的 package.json 回退或 Chromium 反查分支。
- 影响：不会因照抄陈旧开发依赖而把产品层配到错误 runtime；未来程序隐藏版本标识时仍须重新核对，不能猜测一个版本。

## 产品资源与最小补丁

- 位置：Linux runtime 解包之后、打包元数据之前。
- 处理：先放入完整 Linux runtime，再替换为 Windows 包中的产品资源；继续移除 `chrome-sandbox` 及资源内的 Windows `.exe` / `.dll`，不新增其他运行开关。
- 顺序：先完整提取 ASAR，再从外置目录和提取目录同时移除已经识别的 PE 格式 `gemini_native.node`；未知 PE 模块、未知路径或缺少提取副本仍由原脚本拒绝。
- 窗口：`disable_visible_on_all_workspaces.py` 只接收 ASAR 提取目录，只把显式 `setVisibleOnAllWorkspaces(true/!0)` 改为 `false`。原生模块检测不再与上游英文日志或功能开关名称绑定，未识别窗口调用仍会失败。
- 启动：`patches/Gemini` 原样安装，继续传递 `--lang=zh-CN`、`LANGUAGE=zh_CN:zh` 和全部用户参数。大写启动器及 `Gemini.AppImage` 名称保持不变。
- 非本次范围：不恢复白边、窗口尺寸、任务切换器图标注入或其他已经撤回的补丁。

## 图标与中文环境

- 图标：原样采用 pkgforge 的 `ICON` 设置，直接读取 `resources/app.asar.unpacked/assets/icon.png`，交由 quick-sharun 部署；不再调用 ICO 提取工具。旧 `extract_ico_png.py` 与修复历史保留，但不在当前构建链中执行。
- 元数据：显式设置模板的 `ARCH`、`MAIN_BIN`、`DEPLOY_GTK=1`，保留既有应用名称、窗口类、输出目录、产物名和 `NO_STRIP=1`。版本在依赖收集前通过公共入口读取，并追加 desktop 的 `X-AppImage-Version`。
- 依赖：`--base` 继续提供 7zip、Python、binutils、NSS、IBus、inetutils 等；独立安装行保留原来的 `asar alsa-lib gtk3 cups libxss libxtst libnotify libsecret libpulse mesa fcitx5-gtk`。仅移除退出构建链后不再需要的 `icoutils`。
- 中文：第一次 quick-sharun 之后，按模板生成包内 `zh_CN.UTF-8`，并追加 `LANG`、`LANGUAGE`、`LC_MESSAGES`、`LOCPATH`；不自写 AppRun，不改已有中文启动器。

## 上游采用与未采用项

当前所读 pkgforge commit 为 `e7bf2237e223c0cb8b2625dfdd0b1d2f211ccabc`。逐项原文、采用理由与未启用项见 [pkgforge-differences.md](pkgforge-differences.md)；固定参数及原始故障见 [hardcoded.md](hardcoded.md)。

未启用 pkgforge 的开发依赖版本读取、解包时直接排除所有 `.node`、瘦身包替换、额外 NSS 安装命令、小写程序重命名、自更新 hook、额外图标副本和正式 `--test` 步骤；不把记录原文视为启用这些处理。

## 验证边界

2026-11-02 使用已经校验的 Gemini 1.17.0 实包和按官方 SHA-256 清单下载的 Electron 44.5.1 完成实际资源组装。28 项检查覆盖旧断言复现、版本识别、ASAR 提取与重封装、两处原生模块移除、非 sticky 修补、其他产品资源逐项不变、PNG 原样保留、版本与 desktop 元数据及失败保护。

临时验证使用官方 ASAR 工具，未启动 Windows 程序，也未编译替代模块。完整 Arch quick-sharun AppImage 构建、GUI、登录和实际中文输入未在本次检查中执行；此前已经确认的旧版 Linux 使用结果继续保留。推送由既有 workflow 正常处理，提交后不等待或监控 Actions。
