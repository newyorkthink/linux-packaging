# 打包分类

本页只登记近期已经按当前标准完成重写或整理的项目，不是全仓应用清单。未重写的项目不加入，也不因分类整理而改动其稳定脚本。表中“标准化”说明代码和文档采用的结构，不等于所有构建或运行功能均已验收；具体状态以各应用 README 为准。

同类项目共用标准阶段、通用注释、代码结构和空行。软件名、包名、路径及允许变化的参数在原位置替换；经核实并保留的专属差异必须有应用文档，不要求不同来源和专属段强行具有相同总行数。

## 用 quick-sharun 打包的 Electron 程序

### 直接下载安装包

必须先在构建系统安装应用及运行依赖，再从 AUR 元数据、软件官方网站等核实的来源独立下载 DEB 或预编译 tar 等安装包，解包后把完整程序目录放入 `AppDir/bin`。系统安装结果用于依赖、图标、desktop 或既定版本元数据；不得用系统程序目录复制替代独立下载。

**本分类的基础模板是 [Cursor](../cursor/build_cursor.sh) 和 [WorkBuddy](../workbuddy/build_workbuddy.sh)。** 后续同类项目按两份脚本的共同结构、执行顺序、通用注释及对应空行编写，允许的参数变化和专属差异按 [Electron 直接下载标准](../anylinux_projects.md#直接下载安装包的标准模板) 记录。

| 已标准化项目 | 构建脚本 | 程序及版本来源 | 专属差异说明 |
| --- | --- | --- | --- |
| Antigravity | [build_antigravity.sh](../antigravity/build_antigravity.sh) | 官网独立下载 Linux x64 tar；实际下载链接的版本先保存为文本，再由公共版本入口读取。 | [模板差异](../antigravity/docs/template-deviations.md) |
| Antigravity IDE | [build_antigravity-ide.sh](../antigravity-ide/build_antigravity-ide.sh) | 官网独立下载 Linux x64 tar；实际下载链接的版本先保存为文本，再由公共版本入口读取。 | [模板差异](../antigravity-ide/docs/template-deviations.md) |
| ChatGPT | [build_chatgpt.sh](../chatgpt/build_chatgpt.sh) | 先安装 chatgpt-desktop；公共 AUR 入口独立下载 OpenAI 官方 DEB 并校验 SHA-256，版本读取本次包内 Linux 元数据。 | [模板差异](../chatgpt/docs/template-deviations.md) |
| Claude Desktop | [build_claude-desktop.sh](../claude-desktop/build_claude-desktop.sh) | 公共 AUR 下载入口独立取得 DEB 并校验摘要；版本由公共入口读取 AUR 安装结果。 | [模板差异](../claude-desktop/docs/template-deviations.md) |
| Cursor | [build_cursor.sh](../cursor/build_cursor.sh) | 官方独立下载 DEB；版本由公共入口读取包内 `package.json`。 | [模板差异](../cursor/docs/template-deviations.md) |
| Grok Bot | [build_grok-bot.sh](../grok-bot/build_grok-bot.sh) | 先安装 grok-bot-bin；独立下载官方 stable JSON 对应 DEB，公共版本入口读取同次下载记录。 | [模板差异](../grok-bot/docs/template-deviations.md) |
| Visual Studio Code | [build_vscode.sh](../vscode/build_vscode.sh) | Microsoft 官方 stable tar；版本由公共入口读取包内 `package.json`。 | [模板差异](../vscode/docs/template-deviations.md) |
| WorkBuddy | [build_workbuddy.sh](../workbuddy/build_workbuddy.sh) | 官方更新接口独立下载 DEB 并校验摘要；版本由公共入口读取 AUR 安装结果。 | [模板差异](../workbuddy/docs/template-deviations.md) |

两份基础模板当前使用 DEB；其他归档格式保持同一执行阶段，按真实格式选择公共入口。原样采用的 pkgforge-dev 专属代码及其必要性、来源和影响由对应应用文档说明，不复制到其他应用。

版本读取保留在第一次 quick-sharun 之前；最终 AppImage 成功生成后，统一单行调用公共保存入口写入 `dist/version.txt`。包名、下载接口、路径、版本来源及必要运行参数可以不同，不能把参数差异误判为模板失配。

### 从系统里已安装的程序取得

仅在核实 AUR、软件官方网站、软件包仓库及 Release 等来源后，仍未找到适用的预编译安装包时采用。先在构建系统安装应用及其依赖，再使用已安装的真实程序；Electron 必须保留完整程序目录和相邻资源。以后若确认已有适用二进制包，应按规则重新判断来源，不因本表继续源码构建。

| 已标准化项目 | 构建脚本 | 程序及版本来源 | 专属差异说明 |
| --- | --- | --- | --- |
| DeepSeek Harness Desktop | [build_deepseek-harness-desktop.sh](../deepseek-harness-desktop/build_deepseek-harness-desktop.sh) | 当前 AUR 从官方桌面源码及社区 Linux 适配构建；复制完整安装目录，公共版本入口读取 AUR 安装版本。 | [模板差异](../deepseek-harness-desktop/docs/template-deviations.md) |

该分类不添加并不存在的 DEB 下载和解包阶段。DeepSeek 保留的 simdjson、兼容库、Python 私有库路径和许可证复制都有本应用的依据，只作为专属差异保留，不加入直接下载基础模板。

## 用 quick-sharun 打包的 Tauri / GTK 程序

### 直接下载安装包

采用相同的先安装、再独立下载和校验流程，共用标准阶段、通用注释、元数据及版本接口。程序布局按实际软件包处理；GTK、WebKitGTK 和输入模块由当前工具依据依赖部署，动态加载库只保留有应用依据的显式输入。

| 已标准化项目 | 构建脚本 | 程序及版本来源 | 专属差异说明 |
| --- | --- | --- | --- |
| CC Switch | [build_cc-switch.sh](../cc-switch/build_cc-switch.sh) | 独立下载官方正式 Release DEB，核对 GitHub SHA-256、包名和架构；公共版本入口读取同一下载操作记录的版本文本。 | [模板差异](../cc-switch/docs/template-deviations.md) |
| Grok App | [build_grok-app.sh](../grok-app/build_grok-app.sh) | 独立下载 RongleCat/grok-app 正式 Release DEB；版本由同次下载记录。按用户确认的 DEB 例外只安装真实运行依赖，桌面资源取自 DEB。 | [模板差异](../grok-app/docs/template-deviations.md) |

Grok App 尚未核实同源 Arch/AUR 应用包，本次采用用户明确确认的官方 DEB 路线，作为安装阶段的应用专属例外；不改变其他项目先安装应用、再独立下载的默认要求。其选目录工具、宿主 bwrap 和协议登记保留原有依据。Grok Bot 则完整执行标准两阶段，并保留音频、启动兼容及登录回调；这些专属段不加入通用模板。

## 用 quick-sharun 打包的 Arch 官方仓库原生程序

### 从系统真实入口收集

先核实 pkgforge-dev 对应打包和当前二进制来源。选择 Arch 官方仓库原生包、且 `/usr/bin/<主程序>` 是真实可执行程序时，安装应用及依赖后直接交给 quick-sharun，不另行下载同一主程序，不预复制到 `AppDir/bin`。这类与上面的 Electron / Tauri 直接下载分类分开，不能把存在 shell launcher 的应用归入本类。

基础结构、通用注释及空行以 [原生程序系统入口标准](../anylinux_projects.md#arch-官方仓库原生程序系统入口标准) 为准。只登记已经实际完成标准化重写的项目；尚未重写的项目不提前加入。

| 已标准化项目 | 构建脚本 | 程序及版本来源 | 专属差异说明 |
| --- | --- | --- | --- |
| htop | [build_htop.sh](../htop/build_htop.sh) | 安装 Arch 官方 htop 及原有依赖，直接收集 `/usr/bin/htop` 与既有辅助程序、动态库；公共入口读取实际安装版本。 | [模板差异](../htop/docs/template-deviations.md) |
| mpv | [build_mpv.sh](../mpv/build_mpv.sh) | 安装 Arch 官方 mpv 及依赖，直接收集 `/usr/bin/mpv`；公共入口读取实际安装版本。 | [模板差异](../mpv/docs/template-deviations.md) |

mpv 的 yt-dlp 继续在构建时下载、校验并内置，未启用官方运行时 yt-dlp 安装与自更新 hooks；locale 和独立无参数窗口 hook 的来源及取舍见其应用文档。这些专属段不属于本类通用模板。

htop 保留原有 MAIN_BIN、Open Files / Trace 辅助命令和运行时动态加载库，未照搬 pkgforge-dev 的静态源码构建、UPINFO 或 simple-test；仍使用 Arch 官方二进制和本仓库公共版本接口，具体依据见其应用文档。

## 专属处理与维护入口

pkgforge-dev 的实现须先核实是否必要和适用，再决定采用或不采用；具体原文、官方原因、依据、影响及未启用状态放在对应应用的 `docs/pkgforge-differences.md`。没有对应处理时不创建空清单。后续拟加入历史未启用项时，先核实官方当前是否仍保留且仍适用，不能直接恢复旧快照。

固定配置及原始故障放在对应应用的 `docs/hardcoded.md`，当前模板差异放在 `docs/template-deviations.md`，运行状态和完整修复历史从应用 README 查找。新增分类条目时先核对实际重写提交、当前脚本及说明；只改版本、仅有旧打包脚本或尚未重写的项目不补入本页。

## 用 quick-sharun 打包的 Qt 程序

待补充，暂未登记项目。

## linuxdeploy

待补充，暂未登记项目。
