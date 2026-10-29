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
| Claude Desktop | [build_claude-desktop.sh](../claude-desktop/build_claude-desktop.sh) | 公共 AUR 下载入口独立取得 DEB 并校验摘要；版本由公共入口读取 AUR 安装结果。 | [模板差异](../claude-desktop/docs/template-deviations.md) |
| Cursor | [build_cursor.sh](../cursor/build_cursor.sh) | 官方独立下载 DEB；版本由公共入口读取包内 `package.json`。 | [模板差异](../cursor/docs/template-deviations.md) |
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

## 专属处理与维护入口

pkgforge-dev 的实现须先核实是否必要和适用，再决定采用或不采用；具体原文、官方原因、依据、影响及未启用状态放在对应应用的 `docs/pkgforge-differences.md`。没有对应处理时不创建空清单。后续拟加入历史未启用项时，先核实官方当前是否仍保留且仍适用，不能直接恢复旧快照。

固定配置及原始故障放在对应应用的 `docs/hardcoded.md`，当前模板差异放在 `docs/template-deviations.md`，运行状态和完整修复历史从应用 README 查找。新增分类条目时先核对实际重写提交、当前脚本及说明；只改版本、仅有旧打包脚本或尚未重写的项目不补入本页。
