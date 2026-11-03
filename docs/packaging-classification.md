# 打包分类

本页只登记近期已经按当前标准完成重写或整理的项目，不是全仓应用清单。未重写的项目不加入，也不因分类整理而改动其稳定脚本。表中“标准化”说明代码和文档采用的结构，不等于所有构建或运行功能均已验收；具体状态以各应用 README 为准。

全部当前 AppImage 项目对应的上游仓库和构建代码见 [上游打包参考索引](./upstream-packaging-index.md)；该索引保留未查到上游的空白行，不改变本页只登记已标准化项目的范围。

同类项目共用标准阶段、通用注释、代码结构和空行。软件名、包名、路径及允许变化的参数在原位置替换；经核实并保留的专属差异必须有应用文档，不要求不同来源和专属段强行具有相同总行数。

## 用 quick-sharun 打包的 Electron 程序

### 直接下载安装包

必须先在构建系统安装应用及运行依赖，再从 AUR 元数据、软件官方网站等核实的来源独立下载 DEB 或预编译 tar 等安装包，解包后把完整程序目录放入 `AppDir/bin`。系统安装结果用于依赖、图标、desktop 或既定版本元数据；不得用系统程序目录复制替代独立下载。

**本分类的基础模板是 [Cursor](../cursor/build_cursor.sh) 和 [WorkBuddy](../workbuddy/build_workbuddy.sh)。** 后续同类项目按两份脚本的共同结构、执行顺序、通用注释及对应空行编写，允许的参数变化和专属差异按 [Electron 直接下载标准](../anylinux_projects.md#直接下载安装包的标准模板) 记录。

| 已标准化项目 | 构建脚本 | 程序及版本来源 | 专属 export | 专属差异说明 |
| --- | --- | --- | --- | --- |
| Antigravity | [build_antigravity.sh](../antigravity/build_antigravity.sh) | 官网独立下载 Linux x64 tar；实际下载链接的版本先保存为文本，再由公共版本入口读取。 | export DEPLOY_GTK=1<br>export DEPLOY_OPENGL=1<br>export DEPLOY_VULKAN=1 | [模板差异](../antigravity/docs/template-deviations.md) |
| Antigravity IDE | [build_antigravity-ide.sh](../antigravity-ide/build_antigravity-ide.sh) | 官网独立下载 Linux x64 tar；实际下载链接的版本先保存为文本，再由公共版本入口读取。 | export DEPLOY_GTK=1<br>export DEPLOY_OPENGL=1<br>export DEPLOY_VULKAN=1 | [模板差异](../antigravity-ide/docs/template-deviations.md) |
| ChatGPT | [build_chatgpt.sh](../chatgpt/build_chatgpt.sh) | 先安装 chatgpt-desktop；公共 AUR 入口独立下载 OpenAI 官方 DEB 并校验 SHA-256，版本读取本次包内 Linux 元数据。 | export DEPLOY_GTK=1 | [模板差异](../chatgpt/docs/template-deviations.md) |
| Claude Desktop | [build_claude-desktop.sh](../claude-desktop/build_claude-desktop.sh) | 公共 AUR 下载入口独立取得 DEB 并校验摘要；版本由公共入口读取 AUR 安装结果。 | export DEPLOY_GTK=1 | [模板差异](../claude-desktop/docs/template-deviations.md) |
| Cursor | [build_cursor.sh](../cursor/build_cursor.sh) | 官方独立下载 DEB；版本由公共入口读取包内 `package.json`。 | export DEPLOY_GTK=1 | [模板差异](../cursor/docs/template-deviations.md) |
| Grok Bot | [build_grok-bot.sh](../grok-bot/build_grok-bot.sh) | 先安装 grok-bot-bin；独立下载官方 stable JSON 对应 DEB，公共版本入口读取同次下载记录。 | export DEPLOY_GTK=1 | [模板差异](../grok-bot/docs/template-deviations.md) |
| TradingView | [build_tradingview.sh](../tradingview/build_tradingview.sh) | 先安装 AUR 的 tradingview-bin-latest；从官方签名 APT 仓库独立下载当前 DEB，版本读取同次下载记录。 | export DEPLOY_GTK=1<br>export NO_STRIP=1<br>export STRACE_MODE=0 | [模板差异](../tradingview/docs/template-deviations.md) |
| Visual Studio Code | [build_vscode.sh](../vscode/build_vscode.sh) | Microsoft 官方 stable tar；版本由公共入口读取包内 `package.json`。 | export DEPLOY_GTK=1<br>export DEPLOY_OPENGL=1<br>export DEPLOY_VULKAN=1 | [模板差异](../vscode/docs/template-deviations.md) |
| WorkBuddy | [build_workbuddy.sh](../workbuddy/build_workbuddy.sh) | 官方更新接口独立下载 DEB 并校验摘要；版本由公共入口读取 AUR 安装结果。 | export DEPLOY_GTK=1 | [模板差异](../workbuddy/docs/template-deviations.md) |

两份基础模板当前使用 DEB；其他归档格式保持同一执行阶段，按真实格式选择公共入口。原样采用的 pkgforge-dev 专属代码及其必要性、来源和影响由对应应用文档说明，不复制到其他应用。

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
| ToDesk | [build_todesk.sh](../todesk/build_todesk.sh) | 先安装 todesk-bin；公共 AUR 入口独立下载并按原摘要校验官方 DEB，版本读取同次下载记录。 | export DEPLOY_GTK=1<br>export NO_STRIP=1<br>export PATH_MAPPING='/opt/todesk:${SHARUN_DIR}/bin/todesk' | [模板差异](../todesk/docs/template-deviations.md) |

Grok App 尚未核实同源 Arch/AUR 应用包，本次采用用户明确确认的官方 DEB 路线，作为安装阶段的应用专属例外；不改变其他项目先安装应用、再独立下载的默认要求。其选目录工具、宿主 bwrap 和协议登记保留原有依据。Grok Bot 则完整执行标准两阶段，并保留音频、启动兼容及登录回调；这些专属段不加入通用模板。

## 用 quick-sharun 打包的 Arch 官方仓库原生程序

### 从系统真实入口收集

先核实 pkgforge-dev 对应打包和当前二进制来源。选择 Arch 官方仓库原生包、且 `/usr/bin/<主程序>` 是真实可执行程序时，安装应用及依赖后直接交给 quick-sharun，不另行下载同一主程序，不预复制到 `AppDir/bin`。这类与上面的 Electron / Tauri 直接下载分类分开，不能把存在 shell launcher 的应用归入本类。

基础结构、通用注释及空行以 [原生程序系统入口标准](../anylinux_projects.md#arch-官方仓库原生程序系统入口标准) 为准。只登记已经实际完成标准化重写的项目；尚未重写的项目不提前加入。

| 已标准化项目 | 构建脚本 | 程序及版本来源 | 专属 export | 专属差异说明 |
| --- | --- | --- | --- | --- |
| htop | [build_htop.sh](../htop/build_htop.sh) | 安装 Arch 官方 htop 及原有依赖，直接收集 `/usr/bin/htop` 与既有辅助程序、动态库；公共入口读取实际安装版本。 | 无 | [模板差异](../htop/docs/template-deviations.md) |
| mpv | [build_mpv.sh](../mpv/build_mpv.sh) | 安装 Arch 官方 mpv 及依赖，直接收集 `/usr/bin/mpv`；公共入口读取实际安装版本。 | 无 | [模板差异](../mpv/docs/template-deviations.md) |
| Xephyr | [build_xephyr.sh](../xephyr/build_xephyr.sh) | 安装 Arch 官方 xorg-server-xephyr 及原有依赖，直接收集 Xephyr 和 xkbcomp；公共入口读取实际安装版本。 | export STRACE_MODE=0<br>export PATH_MAPPING（XKB 路径映射） | [模板差异](../xephyr/docs/template-deviations.md) |

mpv 的 yt-dlp 继续在构建时下载、校验并内置，未启用官方运行时 yt-dlp 安装与自更新 hooks；locale 和独立无参数窗口 hook 的来源及取舍见其应用文档。这些专属段不属于本类通用模板。

htop 保留原有 MAIN_BIN、Open Files / Trace 辅助命令和运行时动态加载库，未照搬 pkgforge-dev 的静态源码构建、UPINFO 或 simple-test；仍使用 Arch 官方二进制和本仓库公共版本接口，具体依据见其应用文档。

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
| OBS Studio | [build_obs-studio.sh](../obs-studio/build_obs-studio.sh) | 安装 Arch 官方 obs-studio 及已确认依赖，原样复用官方通配收集命令；公共入口读取实际安装版本。 | export DEPLOY_OPENGL=1<br>export DEPLOY_PIPEWIRE=1<br>export DEPLOY_PYTHON=1<br>export DEPLOY_QT=1<br>export DEPLOY_SDL=1<br>export PATH_MAPPING_HARDCODED='libobs.so*' | [模板差异](../obs-studio/docs/template-deviations.md) |

OBS Studio 原样采用 pkgforge-dev 的程序与运行资源收集命令，以及 SDL 和 libobs 路径处理配置；共享数据由工具扫描收集。中文环境与 Qt 6 输入、主题插件继续保留，完整原文、用途、取舍和原始故障记录见其应用文档。

## AppDir / 官方 appimagetool 体系

本体系包括 linuxdeploy 部署后封装和完整 AppDir 直接封装两种方式，共用适用的阶段风格、固定注释、工具准备和最终封装入口。quick-sharun / sharun 属于前面的另一套体系，不混用模板。

### linuxdeploy

本类遵循 [linuxdeploy 规范](../linuxdeploy_projects.md) 和 [固定注释标准](./linuxdeploy-comments.md)。基础标准参考为 Joplin（GTK）、XnView MP（Qt）和 MediaInfo（CLI）；Remmina 是已按该标准整理的 GTK / GStreamer 项目。

构建直接使用各项目已确认的 Ubuntu runner，不使用 Docker。linuxdeploy 负责依赖部署和中间输出，最终由官方 appimagetool 配合明确的 Type 2 runtime 封装。

| 已标准化项目 | 构建脚本 | 程序及版本来源 | 技术栈与插件 | 专属差异说明 |
| --- | --- | --- | --- | --- |
| Joplin | [build_joplin.sh](../joplin/build_joplin.sh) | 官方 GitHub 正式 Release DEB；公共入口校验后，将同一份包安装并按原布局解包，返回实际版本。 | Electron / GTK3；gtk | [专属差异](../joplin/docs/template-deviations.md) |
| MediaInfo | [build_mediainfo_linuxdeploy.sh](../mediainfo/build_mediainfo_linuxdeploy.sh) | Ubuntu 24.04 仓库的 mediainfo；公共入口下载已安装的同一版本并解包，返回版本号。 | CLI；无框架插件 | [专属差异](../mediainfo/docs/template-deviations.md) |
| RealVNC Connect | [build_realvnc-rvnc-connect.sh](../realvnc-rvnc-connect/build_realvnc-rvnc-connect.sh) | 官方校验页面中的最新稳定版 x64 DEB；公共入口核对 SHA-256、安装并解包，返回包内实际版本。 | Flutter / GTK3；gtk | [专属差异](../realvnc-rvnc-connect/docs/template-deviations.md) |
| Remmina | [build_remmina.sh](../remmina/build_remmina.sh) | Ubuntu 24.04 仓库的 Remmina 与协议插件；各包按已安装版本下载并解包，版本以 remmina 主包为准。 | GTK3 / WebKitGTK；gtk、gstreamer | [专属差异](../remmina/docs/template-deviations.md) |
| XnView MP | [build_xnviewmp.sh](../xnviewmp/build_xnviewmp.sh) | 官方校验清单中的最新稳定版 x64 DEB；公共入口校验后，将同一份包安装并按原布局解包，返回实际版本。 | Qt6；qt | [专属差异](../xnviewmp/docs/template-deviations.md) |

专属补库、桌面入口调整、AppRun 和 patches 处理按各应用的差异说明保留，不作为同类程序的默认步骤。

### 直接 appimagetool

遵循同一规范的 [直接封装补充](../linuxdeploy_projects.md#直接-appimagetool-模式同一体系的精简流程)，省略 linuxdeploy、插件、初始化和中间输出。构建环境与程序专属差异沿用各自已确认的基线，不因归类强制迁移环境或重写入口。

| 已整理项目 | 构建脚本 | 程序及版本来源 | 工具与封装入口 | 专属差异说明 |
| --- | --- | --- | --- | --- |
| DingTalk | [build_dingtalk.sh](../dingtalk/build_dingtalk.sh) | 当前 AUR 指向的官方 DEB；公共组合入口校验摘要与包身份、安装并解包，返回实际版本。 | Qt/CEF 完整 bundle；工具准备与最终封装均使用公共入口，不调用 linuxdeploy。 | [专属差异](../dingtalk/docs/template-deviations.md) |
| kitty | [build_kitty.sh](../kitty/build_kitty.sh) | 官方 installer 提供的预编译目录；公共版本入口执行当前程序的 `--version` 并按指定字段取版本。 | 工具准备入口的 `--appimagetool` 模式一次取得两个工具并设置权限；公共封装入口统一处理 PNG、封装和版本。 | [专属差异](../kitty/docs/template-deviations.md) |

kitty 保留既有构建顺序、独立 AppRun、kitten 分派和专属资源准备。DingTalk 保留 Qt/CEF 布局、完整 NSS/NSPR、可执行栈和依赖收集处理，按统一分区维护；当前来源与验证范围见 [DingTalk README](../dingtalk/README.md#本次核对与验证)。其他尚未整理的直接封装项目不提前登记为已标准化。

## 专属处理与维护入口

pkgforge-dev 的实现须先核实是否必要和适用，再决定采用或不采用；具体原文、官方原因、依据、影响及未启用状态放在对应应用的 `docs/pkgforge-differences.md`。没有对应处理时不创建空清单。后续拟加入历史未启用项时，先核实官方当前是否仍保留且仍适用，不能直接恢复旧快照。

固定配置及原始故障放在对应应用的 `docs/hardcoded.md`，当前模板差异放在 `docs/template-deviations.md`，运行状态和完整修复历史从应用 README 查找。新增分类条目时先核对实际重写提交、当前脚本及说明；只改版本、仅有旧打包脚本或尚未重写的项目不补入本页。
