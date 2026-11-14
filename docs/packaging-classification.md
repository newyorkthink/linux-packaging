# 打包分类

本页登记近期已按当前标准完成重写或整理的项目，以及经核实采用专用打包流程的项目。表中“标准化”描述代码和文档采用的结构。各项目的构建与运行验收状态以应用 README 为准。

当前 AppImage 项目对应的 pkgforge-dev 打包参考见 [上游打包参考索引](./upstream-packaging-index.md)。该索引也保留尚未查到参考实现的项目。

同类标准化项目共用标准阶段、通用注释、代码结构和空行。软件名、包名、路径及允许变化的参数在原位置替换；经核实并保留的专属差异必须有应用文档，不要求不同来源和专属段强行具有相同总行数。

quick-sharun 按标准重写时，从 [唯一标准模板](../anylinux_projects.md#唯一标准模板) 按软件来源和技术栈选择完整底稿。所有模板见 [模板索引](../templates/README.md)。

## 用 quick-sharun 打包的 Electron 程序

### 直接下载安装包

必须先在构建系统安装应用及运行依赖，再从 AUR 元数据、软件官方网站等核实的来源独立下载 DEB 或预编译 tar 等安装包，解包后把完整程序目录放入 `AppDir/bin`。系统安装结果用于依赖、图标、desktop 或既定版本元数据；不得用系统程序目录复制替代独立下载。

**官方 DEB 且版本来自包内 `package.json` 的标准底稿为 [electron-deb.sh](../templates/quick-sharun/electron-deb.sh)。** 带标签前缀的 GitHub 正式 Release DEB 使用 [electron-github-deb.sh](../templates/quick-sharun/electron-github-deb.sh)，版本读取同次校验下载的记录。其他来源或版本布局先核对固定模板的适用条件。Cursor 和 WorkBuddy 保留为既有实现参考。

| 已标准化项目 | 构建脚本 | 程序及版本来源 | 专属 export | 专属差异说明 |
| --- | --- | --- | --- | --- |
| Antigravity | [build_antigravity.sh](../antigravity/build_antigravity.sh) | 官网独立下载 Linux x64 tar；实际下载链接的版本先保存为文本，再由公共版本入口读取。 | export DEPLOY_GTK=1<br>export DEPLOY_OPENGL=1<br>export DEPLOY_VULKAN=1 | [模板差异](../antigravity/docs/template-deviations.md) |
| Antigravity IDE | [build_antigravity-ide.sh](../antigravity-ide/build_antigravity-ide.sh) | 官网独立下载 Linux x64 tar；实际下载链接的版本先保存为文本，再由公共版本入口读取。 | export DEPLOY_GTK=1<br>export DEPLOY_OPENGL=1<br>export DEPLOY_VULKAN=1 | [模板差异](../antigravity-ide/docs/template-deviations.md) |
| ChatGPT | [build_chatgpt.sh](../chatgpt/build_chatgpt.sh) | 先安装 chatgpt-desktop；公共 AUR 入口独立下载 OpenAI 官方 DEB 并校验 SHA-256，版本读取本次包内 Linux 元数据。 | export DEPLOY_GTK=1 | [模板差异](../chatgpt/docs/template-deviations.md) |
| Claude Desktop | [build_claude-desktop.sh](../claude-desktop/build_claude-desktop.sh) | 公共 AUR 下载入口独立取得 DEB 并校验摘要；版本由公共入口读取 AUR 安装结果。 | export DEPLOY_GTK=1 | [模板差异](../claude-desktop/docs/template-deviations.md) |
| Cursor | [build_cursor.sh](../cursor/build_cursor.sh) | 官方独立下载 DEB；版本由公共入口读取包内 `package.json`。 | export DEPLOY_GTK=1 | [模板差异](../cursor/docs/template-deviations.md) |
| Folo | [build_folo.sh](../folo/build_folo.sh) | 先安装 folo-bin；公共入口按 `desktop/` 前缀独立选择官方正式 Release DEB，核对 GitHub SHA-256、包名和架构，版本读取同次下载记录。 | export DEPLOY_GTK=1 | [模板参数](../folo/docs/template-deviations.md) |
| Grok Bot | [build_grok-bot.sh](../grok-bot/build_grok-bot.sh) | 先安装 grok-bot-bin；独立下载官方 stable JSON 对应 DEB，公共版本入口读取同次下载记录。 | export DEPLOY_GTK=1 | [模板差异](../grok-bot/docs/template-deviations.md) |
| Obsidian | [build_obsidian.sh](../obsidian/build_obsidian.sh) | 先安装 AUR `obsidian-bin`；公共入口从 Obsidian 官方正式 Release 独立下载 AMD64 DEB，核对 SHA-256、包名和架构，同次保存版本。 | export DEPLOY_GTK=1<br>export DEPLOY_OPENGL=1<br>export DEPLOY_VULKAN=1<br>export DEPLOY_PIPEWIRE=1 | [模板差异](../obsidian/docs/template-deviations.md) · [上游取舍](../obsidian/docs/pkgforge-differences.md) |
| TradingView | [build_tradingview.sh](../tradingview/build_tradingview.sh) | 先安装 AUR 的 tradingview-bin-latest；从官方签名 APT 仓库独立下载当前 DEB，版本读取同次下载记录。 | export DEPLOY_GTK=1<br>export NO_STRIP=1<br>export STRACE_MODE=0 | [模板差异](../tradingview/docs/template-deviations.md) |
| Visual Studio Code | [build_vscode.sh](../vscode/build_vscode.sh) | Microsoft 官方 stable tar；版本由公共入口读取包内 `package.json`。 | export DEPLOY_GTK=1<br>export DEPLOY_OPENGL=1<br>export DEPLOY_VULKAN=1 | [模板差异](../vscode/docs/template-deviations.md) |
| WorkBuddy | [build_workbuddy.sh](../workbuddy/build_workbuddy.sh) | 官方更新接口独立下载 DEB 并校验摘要；版本由公共入口读取 AUR 安装结果。 | export DEPLOY_GTK=1 | [模板差异](../workbuddy/docs/template-deviations.md) |

当前登记的直接下载模板使用 DEB。其他归档格式超出适用范围时，按[专用打包流程](#专用打包流程)的授权规则处理。原样采用的 pkgforge-dev 专属代码及其必要性、来源和影响由对应应用文档说明，不复制到其他应用。

版本读取保留在第一次 quick-sharun 之前；最终 AppImage 成功生成后，统一单行调用公共保存入口写入 `dist/version.txt`。包名、下载接口、路径、版本来源及必要运行参数可以不同，不能把参数差异误判为模板失配。

### 从系统里已安装的程序取得

仅在核实 AUR、软件官方网站、软件包仓库及 Release 等来源后，仍未找到适用的预编译安装包时采用。先在构建系统安装应用及其依赖，再使用已安装的真实程序；Electron 必须保留完整程序目录和相邻资源。以后若确认已有适用二进制包，应按规则重新判断来源，不因本表继续源码构建。

| 已标准化项目 | 构建脚本 | 程序及版本来源 | 专属 export | 专属差异说明 |
| --- | --- | --- | --- | --- |
| DeepSeek Harness Desktop | [build_deepseek-harness-desktop.sh](../deepseek-harness-desktop/build_deepseek-harness-desktop.sh) | 当前 AUR 从官方桌面源码及社区 Linux 适配构建；复制完整安装目录，公共版本入口读取 AUR 安装版本。 | export DEPLOY_GTK=1 | [模板差异](../deepseek-harness-desktop/docs/template-deviations.md) |

该分类不添加并不存在的 DEB 下载和解包阶段。DeepSeek 保留的 simdjson、兼容库、Python 私有库路径和许可证复制都有本应用的依据，只作为专属差异保留，不加入直接下载基础模板。

### Windows 产品层移植

独立下载官方 Windows 完整安装包，提取 Electron 产品资源，再与实际程序对应版本的官方 Linux Electron runtime 组装到 `AppDir/bin`，由 quick-sharun 收集运行依赖并封装。Windows 安装包只用于解包，不在 Linux 构建系统中执行；系统依赖与兼容补丁按应用专属文档保留。

| 已标准化项目 | 构建脚本 | 程序及版本来源 | 专属 export | 专属差异说明 |
| --- | --- | --- | --- | --- |
| Gemini | [build_gemini.sh](../gemini/build_gemini.sh) | Google Omaha 动态取得 Windows x64 完整 NSIS 包；产品版本读取同次下载记录，Linux Electron 精确版本取自对应 `Gemini.exe`。 | export DEPLOY_GTK=1<br>export NO_STRIP=1 | [模板差异](../gemini/docs/template-deviations.md) |

Gemini 保留现有中文启动器、已识别 PE 模块移除顺序及非 sticky 修补，直接使用包内 PNG。上游采用与未采用项见其 [上游差异](../gemini/docs/pkgforge-differences.md)，实际验证范围见 [README](../gemini/README.md)。

## 用 quick-sharun 打包的 Tauri / GTK 程序

### 直接下载安装包

采用相同的先安装、再独立下载和校验流程，共用标准阶段、通用注释、元数据及版本接口。程序布局按实际软件包处理；GTK、WebKitGTK 和输入模块由当前工具依据依赖部署，动态加载库只保留有应用依据的显式输入。

| 已标准化项目 | 构建脚本 | 程序及版本来源 | 专属 export | 专属差异说明 |
| --- | --- | --- | --- | --- |
| CC Switch | [build_cc-switch.sh](../cc-switch/build_cc-switch.sh) | 独立下载官方正式 Release DEB，核对 GitHub SHA-256、包名和架构；公共版本入口读取同一下载操作记录的版本文本。 | export DEPLOY_GTK=1 | [模板差异](../cc-switch/docs/template-deviations.md) |
| Grok App | [build_grok-app.sh](../grok-app/build_grok-app.sh) | 独立下载 RongleCat/grok-app 正式 Release DEB；版本由同次下载记录。按用户确认的 DEB 例外只安装真实运行依赖，桌面资源取自 DEB。 | export DEPLOY_GTK=1<br>export DEPLOY_OPENGL=1<br>export DEPLOY_WEBKIT2GTK=1<br>export WEBKIT2GTK_DIR=/usr/lib/webkit2gtk-4.1 | [模板差异](../grok-app/docs/template-deviations.md) |

Grok App 尚未核实同源 Arch/AUR 应用包，本次采用用户明确确认的官方 DEB 路线，作为安装阶段的应用专属例外；不改变其他项目先安装应用、再独立下载的默认要求。其选目录工具、宿主 bwrap 和协议登记保留原有依据。Grok Bot 则完整执行标准两阶段，并保留音频、启动兼容及登录回调；这些专属段不加入通用模板。

## 用 quick-sharun 打包的 Arch 官方仓库原生程序

### 从系统真实入口收集

先核实 pkgforge-dev 对应打包和当前二进制来源。选择 Arch 官方仓库原生包、且 `/usr/bin/<主程序>` 是真实可执行程序时，安装应用及依赖后直接交给 quick-sharun，不另行下载同一主程序，不预复制到 `AppDir/bin`。这类与上面的 Electron / Tauri 直接下载分类分开，不能把存在 shell launcher 的应用归入本类。

基础结构、通用注释及空行以 [原生程序系统入口标准](../anylinux_projects.md#arch-官方仓库原生程序系统入口标准) 为准。只登记已经实际完成标准化重写的项目；尚未重写的项目不提前加入。

[Newsboat](../newsboat/build_newsboat.sh) 是同一 Arch 官方包提供多个真实终端入口时的基础参考。脚本使用的仓库 desktop 和窗口类设置按应用差异说明维护。

| 已标准化项目 | 构建脚本 | 程序及版本来源 | 专属 export | 专属差异说明 |
| --- | --- | --- | --- | --- |
| htop | [build_htop.sh](../htop/build_htop.sh) | 安装 Arch 官方 htop 及原有依赖，直接收集 `/usr/bin/htop` 与既有辅助程序、动态库；公共入口读取实际安装版本。 | 无 | [模板差异](../htop/docs/template-deviations.md) |
| mpv | [build_mpv.sh](../mpv/build_mpv.sh) | 安装 Arch 官方 mpv 及依赖，直接收集 `/usr/bin/mpv`；公共入口读取实际安装版本。 | 无 | [模板差异](../mpv/docs/template-deviations.md) |
| Newsboat | [build_newsboat.sh](../newsboat/build_newsboat.sh) | 安装 Arch 官方 newsboat 及原有依赖，一次收集同包的 newsboat 和 podboat，公共入口读取实际安装版本。 | export STARTUPWMCLASS=newsboat | [模板差异](../newsboat/docs/template-deviations.md) |
| Xephyr | [build_xephyr.sh](../xephyr/build_xephyr.sh) | 安装 Arch 官方 xorg-server-xephyr 及原有依赖，直接收集 Xephyr 和 xkbcomp；公共入口读取实际安装版本。 | export STRACE_MODE=0<br>export PATH_MAPPING（XKB 路径映射） | [模板差异](../xephyr/docs/template-deviations.md) |

mpv 的 yt-dlp 继续在构建时下载、校验并内置，未启用官方运行时 yt-dlp 安装与自更新 hooks；locale 和独立无参数窗口 hook 的来源及取舍见其应用文档。这些专属段不属于本类通用模板。

htop 保留原有 MAIN_BIN、Open Files / Trace 辅助命令和运行时动态加载库，未照搬 pkgforge-dev 的静态源码构建、UPINFO 或 simple-test；仍使用 Arch 官方二进制和本仓库公共版本接口，具体依据见其应用文档。

## 用 quick-sharun 打包的官方预编译 ZIP 命令行工具

从软件官方网站独立下载预编译 Linux ZIP，解压后使用 quick-sharun 收集程序与运行依赖。该类不使用 Arch 系统入口模板，必要的应用专属处理以对应文档为准，不新增标准模板。

| 项目 | 构建脚本 | 程序及版本来源 | 打包方式 | 专属差异说明 |
| --- | --- | --- | --- | --- |
| Android Platform Tools | [build_android-tools.sh](../android-tools/build_android-tools.sh) | 下载 Google 官方最新 Linux Platform Tools ZIP，从 `source.properties` 读取实际版本。 | 保留图标与 PATH hook，容器精简后恢复依赖，再由 quick-sharun 封装。 | [模板差异](../android-tools/docs/template-deviations.md) · [上游取舍](../android-tools/docs/pkgforge-differences.md) · [固定配置](../android-tools/docs/hardcoded.md) |

## 用 quick-sharun 打包的 Qt 程序

### 直接下载安装包

安装 AUR 应用及依赖后，通过公共入口独立下载、校验并解包主 DEB。匹配 Qt 主版本的输入法模块随程序收集，保留应用自带 Qt 和 CEF 的相对布局。

| 已标准化项目 | 构建脚本 | 程序及版本来源 | 专属 export | 专属差异说明 |
| --- | --- | --- | --- | --- |
| MailMaster | [build_mailmaster.sh](../mailmaster/build_mailmaster.sh) | 按当前 AUR 配方安装，独立校验并解包主 DEB，公共入口读取同次下载的版本。 | export DEPLOY_GTK=1<br>export DEPLOY_OPENGL=1<br>export DEPLOY_VULKAN=1<br>export DEPLOY_PIPEWIRE=1 | [模板差异](../mailmaster/docs/template-deviations.md) |

### 从系统真实入口收集

先安装 Arch 官方仓库的应用及运行依赖，再将真实程序入口、必要辅助程序和运行资源交给 quick-sharun 收集。有窗口的程序同时保留匹配 Qt 主版本的输入模块和包内中文环境。

**Qt 6 程序打包前必须安装 qt6ct、kvantum、lxqt-qtplugin。** quick-sharun 会收集已安装的主题插件；缺少插件时会出现主题支持警告，完整原文见 [Qt 主题插件说明](../anylinux_projects.md#qt-主题插件)。

| 已标准化项目 | 构建脚本 | 程序及版本来源 | 专属 export | 专属差异说明 |
| --- | --- | --- | --- | --- |
| CopyQ | [build_copyq.sh](../copyq/build_copyq.sh) | 安装 Arch 官方 copyq 及原有依赖，同次收集主程序、功能插件和共享资源；公共入口读取实际安装版本。 | export STARTUPWMCLASS=copyq<br>export DEPLOY_OPENGL=1<br>export DEPLOY_QT=1 | [模板差异](../copyq/docs/template-deviations.md) |
| OBS Studio | [build_obs-studio.sh](../obs-studio/build_obs-studio.sh) | 安装 Arch 官方 obs-studio 及已确认依赖，原样复用官方通配收集命令；公共入口读取实际安装版本。 | export DEPLOY_OPENGL=1<br>export DEPLOY_PIPEWIRE=1<br>export DEPLOY_PYTHON=1<br>export DEPLOY_QT=1<br>export DEPLOY_SDL=1<br>export PATH_MAPPING_HARDCODED='libobs.so*' | [模板差异](../obs-studio/docs/template-deviations.md) |
| SMPlayer | [build_smplayer.sh](../smplayer/build_smplayer.sh) | 安装 Arch 官方 Qt5 版 smplayer，直接收集系统程序、播放器、应用资源和 Qt5 输入模块。公共入口下载并校验 Python 版 yt-dlp，版本读取实际安装的 smplayer。 | export STARTUPWMCLASS=smplayer<br>export QT_DIR=qt<br>export DEPLOY_PYTHON=1 | [模板差异](../smplayer/docs/template-deviations.md) |

OBS Studio 原样采用 pkgforge-dev 的程序与运行资源收集命令，以及 SDL 和 libobs 路径处理配置；共享数据由工具扫描收集。中文环境与 Qt 6 输入、主题插件继续保留，完整原文、用途、取舍和原始故障记录见其应用文档。

## AppDir / 官方 appimagetool 体系

本体系包括 linuxdeploy 部署后封装和完整 AppDir 直接封装两种方式，共用适用的阶段风格、固定注释、工具准备和最终封装入口。quick-sharun / sharun 属于前面的另一套体系，不混用模板。

### linuxdeploy

本类遵循 [linuxdeploy 规范](../linuxdeploy_projects.md) 和 [固定注释标准](./linuxdeploy-comments.md)。标准重写的底稿按来源及技术栈从 [唯一标准模板](../linuxdeploy_projects.md#唯一标准模板) 选择。下表登记已整理的应用。

构建直接使用各项目已确认的 Ubuntu runner，不使用 Docker。linuxdeploy 负责依赖部署和中间输出，最终由官方 appimagetool 配合明确的 Type 2 runtime 封装。

| 已标准化项目 | 构建脚本 | 程序及版本来源 | 技术栈与插件 | 专属差异说明 |
| --- | --- | --- | --- | --- |
| dconf Editor | [build_dconf-editor.sh](../dconf-editor/build_dconf-editor.sh) | Ubuntu 24.04 仓库的 dconf-editor 与 dconf-cli；公共入口按已安装版本下载并解包。 | GTK3 / GLib；gtk | [专属差异](../dconf-editor/docs/template-deviations.md) |
| File Roller | [build_file-roller.sh](../file-roller/build_file-roller.sh) | Ubuntu 24.04 仓库的 file-roller；公共入口按已安装版本下载并解包，同时解包 bzip2、unzip、zip。 | GTK4 / libadwaita；gtk | [专属差异](../file-roller/docs/template-deviations.md) |
| GoldenDict | [build_goldendict.sh](../goldendict/build_goldendict.sh) | Ubuntu 24.04 仓库的原版 goldendict；下载已安装的同版本 DEB，保留完整发行版修订号。 | Qt5 / GStreamer；qt、gstreamer | [专属差异](../goldendict/docs/template-deviations.md) |
| Joplin | [build_joplin.sh](../joplin/build_joplin.sh) | 官方 GitHub 正式 Release DEB；公共入口校验后，将同一份包安装并按原布局解包，返回实际版本。 | Electron / GTK3；gtk | [专属差异](../joplin/docs/template-deviations.md) |
| MediaInfo | [build_mediainfo_linuxdeploy.sh](../mediainfo/build_mediainfo_linuxdeploy.sh) | Ubuntu 24.04 仓库的 mediainfo；公共入口下载已安装的同一版本并解包，返回版本号。 | CLI；无框架插件 | [专属差异](../mediainfo/docs/template-deviations.md) |
| Poppler Utilities | [build_poppler-utils.sh](../poppler-utils/build_poppler-utils.sh) | Ubuntu 24.04 仓库的 poppler-utils 与 poppler-data；公共入口按已安装版本下载并解包，返回主程序版本。 | CLI（13 个命令）；无框架插件 | [专属差异](../poppler-utils/docs/template-deviations.md) |
| rvncconnect | [build_rvncconnect.sh](../rvncconnect/build_rvncconnect.sh) | 官方校验页面中的最新稳定版 x64 DEB；公共入口核对 SHA-256、安装并解包，返回包内实际版本。 | Flutter / GTK3；gtk | [专属差异](../rvncconnect/docs/template-deviations.md) |
| RealVNC Viewer | [build_vncviewer.sh](../vncviewer/build_vncviewer.sh) | 固定从本仓库 `original-package-archive` 获取官方 x64 DEB，公共入口核对 GitHub SHA-256 并读取包内版本。 | X11；无 Qt/GTK 框架插件 | [应用说明](../vncviewer/README.md) |
| Remmina | [build_remmina.sh](../remmina/build_remmina.sh) | Ubuntu 24.04 仓库的 Remmina 与协议插件；各包按已安装版本下载并解包，版本以 remmina 主包为准。 | GTK3 / WebKitGTK；gtk、gstreamer | [专属差异](../remmina/docs/template-deviations.md) |
| XnView MP | [build_xnviewmp.sh](../xnviewmp/build_xnviewmp.sh) | 官方校验清单中的最新稳定版 x64 DEB；公共入口校验后，将同一份包安装并按原布局解包，返回实际版本。 | Qt6；qt | [专属差异](../xnviewmp/docs/template-deviations.md) |

专属补库、桌面入口调整、AppRun 和 patches 处理按各应用的差异说明保留，不作为同类程序的默认步骤。

### 直接 appimagetool

遵循同一规范的 [直接封装补充](../linuxdeploy_projects.md#直接-appimagetool-模式同一体系的精简流程)，省略 linuxdeploy、插件、初始化和中间输出。构建环境与程序专属差异沿用各自已确认的基线，不因归类强制迁移环境或重写入口。

[appimagetool-direct.sh](../templates/appimage/appimagetool-direct.sh) 是直接封装的标准底稿。下表登记已整理的应用。

| 已整理项目 | 构建脚本 | 程序及版本来源 | 工具与封装入口 | 专属差异说明 |
| --- | --- | --- | --- | --- |
| DingTalk | [build_dingtalk.sh](../dingtalk/build_dingtalk.sh) | 当前 AUR 指向的官方 DEB；公共组合入口校验摘要与包身份、安装并解包，返回实际版本。 | Qt/CEF 完整 bundle；工具准备与最终封装均使用公共入口，不调用 linuxdeploy。 | [专属差异](../dingtalk/docs/template-deviations.md) |
| kitty | [build_kitty.sh](../kitty/build_kitty.sh) | 官方 installer 提供的预编译目录；公共版本入口执行当前程序的 `--version` 并按指定字段取版本。 | 工具准备入口的 `--appimagetool` 模式一次取得两个工具并设置权限；公共封装入口统一处理 PNG、封装和版本。 | [专属差异](../kitty/docs/template-deviations.md) |
| Ventoy | [build_ventoy.sh](../ventoy/build_ventoy.sh) | 官方最新稳定 Linux 归档。公共入口校验 GitHub SHA-256 与同一 Release 的官方校验清单，并返回版本。 | 保留完整官方目录与内联 AppRun。工具准备和最终封装复用公共入口。 | [专属差异](../ventoy/docs/template-deviations.md) |

自定义 AppRun 按[内联规则](../linuxdeploy_projects.md#apprun-与框架配置)写入 `build_*.sh`。Kitty 保留独立的 169 行 AppRun，属于长脚本特例，并继续保留既有构建顺序、kitten 分派和专属资源准备。DingTalk 保留 Qt/CEF 布局、完整 NSS/NSPR、可执行栈和依赖收集处理，按统一分区维护；当前来源与验证范围见 [DingTalk README](../dingtalk/README.md#本次核对与验证)。其他尚未整理的直接封装项目不提前登记为已标准化。

## 专用打包流程

官方构建入口、套件组合或共享运行组件等需求超出现有模板的适用范围时，先核对具体冲突，再按 [AGENTS.md](../AGENTS.md) 取得本次授权。专用流程复用适用的公共入口，已有项目以各自经确认的流程为基线。后续项目按下表登记当前构建入口、采用专用流程的原因和验证依据，详细实现与验收状态以各应用 README 为准。

| 项目 | 构建入口 | 采用专用流程的原因 | 稳定基线与验证依据 |
| --- | --- | --- | --- |
| Alacritty | [build_alacritty.sh](../alacritty/build_alacritty.sh) | 现有 X11 IME 修复需要在官方正式版源码中应用补丁并编译，再由 LinuxDeploy 部署、appimagetool 封装；固定 APT 模板不支持此专属过程。 | [专属差异](../alacritty/docs/template-deviations.md) · [上游取舍](../alacritty/docs/pkgforge-differences.md) · [历史与验证](../alacritty/README.md) |
| AltTab | [build_alttab.sh](../alttab/build_alttab.sh) | 官方正式 Release 对应提交的源码需依次应用九个独立补丁，经 configure / make 编译后由 quick-sharun 封装，并以构建指纹识别本仓库更新；公共阶段按同类项目手动对齐。 | [专属差异与参考](../alttab/docs/template-deviations.md) · [稳定基线与历史](../alttab/README.md#稳定基线与维护规则) · [实机验证](../alttab/README.md#实机验证) |
| BlueMail | [build_bluemail.sh](../bluemail/build_bluemail.sh) | AUR 安装前同步官方稳定版 Snap、同次原始归档复用、`shared/bin` 相邻资源布局及 OAuth hook 需要应用专属准备；现有 DEB 模板不覆盖这些步骤。公共注释、工作区和版本接口按统一标准维护。 | [模板差异](../bluemail/docs/template-deviations.md) · [固定配置](../bluemail/docs/hardcoded.md) · [实现与实测记录](../bluemail/README.md) |
| Hermes Desktop | [build_hermes-desktop.sh](../hermes-desktop/build_hermes-desktop.sh) | 从上游正式 Release 标签获取源码，使用上游锁定的 pnpm 构建，并由 electron-builder 生成普通 Desktop AppImage。现有模板无法覆盖这条源码构建与封装流程。桌面客户端可连接已有 Gateway，也可使用单独安装的本机 Agent。 | [构建来源、旧版实机记录和当前验收状态](../hermes-desktop/README.md) |
| KDE Suite | [build_kde_suite.sh](../kde-suite/build_kde_suite.sh) | 多款 KDE 程序共享一个 AppImage 的挂载及 Qt 6 和 KF6 运行组件，最终封装前按套件结构分阶段部署应用和辅助工具。 | [KDE Suite README](../kde-suite/README.md) |
| st | [build_st.sh](../st/build_st.sh) | 从 siduck/st 默认分支获取当前源码，按字体配置生成 config.h 并写入源码默认主题，经 make 安装后由 quick-sharun 封装程序、辅助脚本和 terminfo；与 Arch 原生软件包模板不同，不新增标准模板。 | [专属差异](../st/docs/template-deviations.md) · [实机验证](../st/README.md#实机验证) |
| Webcamoid | [build_webcamoid.sh](../webcamoid/build_webcamoid.sh) | 现有流程从官方正式 Release 源码应用四个补丁，经 CMake + Ninja 安装到暂存目录，再由 quick-sharun 收集插件与运行库；不同于现有 Qt DEB / 系统入口模板，不新增标准模板。 | [当前基线与差异](../webcamoid/docs/template-deviations.md) · [实机验证](../webcamoid/README.md#实机验证) |
| Xberg | [build_xberg.sh](../xberg/build_xberg.sh) | 独立下载官方 GNU 预编译归档，保留主程序及相邻共享库，由 quick-sharun 收集运行依赖并封装；现有系统入口和 DEB 模板不覆盖该来源布局。 | [专属差异](../xberg/docs/template-deviations.md) · [应用说明](../xberg/README.md) |

## 专属处理与维护入口

pkgforge-dev 的实现须先核实是否必要和适用，再决定采用或不采用；具体原文、官方原因、依据、影响及未启用状态放在对应应用的 `docs/pkgforge-differences.md`。没有对应处理时不创建空清单。后续拟加入历史未启用项时，先核实官方当前是否仍保留且仍适用，不能直接恢复旧快照。

固定配置及原始故障放在对应应用的 `docs/hardcoded.md`，当前模板差异放在 `docs/template-deviations.md`，运行状态和完整修复历史从应用 README 查找。标准化条目以实际重写或整理的提交、当前脚本及说明为登记依据。专用流程条目按[专用打包流程](#专用打包流程)登记。
