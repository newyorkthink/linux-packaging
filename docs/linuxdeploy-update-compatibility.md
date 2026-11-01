# linuxdeploy 更新与中间封装兼容

## 为什么相同脚本会从成功变成失败

本仓库通过公共工具准备入口动态下载官方 continuous 资产。下载地址和构建脚本保持不变，不代表每次下载到的 linuxdeploy 文件相同；它内置的 AppImage 输出插件和 appimagetool 也可能随构建更新。

linuxdeploy 的依赖部署与最后独立执行的 appimagetool 封装是两个阶段。中间封装提前失败时，后面的公共权限、图标准备和最终封装均不会执行。此前多次成功，只能证明当时的工具组合能完成该流程，不能证明后续工具更新仍会接受尚未整理的 AppDir。

## 修复前的两个封装阶段

| 阶段 | 实际使用的工具 | 修复前公共准备的位置 |
| --- | --- | --- |
| linuxdeploy 生成中间 AppImage | linuxdeploy 的 AppImage 输出插件调用其选中的 appimagetool；本次日志显示使用内置版本。 | 原流程没有在这个输出阶段执行公共权限和 PNG 准备。 |
| 对同一个 AppDir 生成最终 AppImage | 独立下载的官方 appimagetool，显式使用官方 Type 2 runtime。 | `common/linuxdeploy/package_appimage.sh` 在封装前调用 `common/appimage/prepare_appdir_for_appimagetool.sh`。 |

最终阶段已经使用新版 appimagetool 并成功，不代表中间阶段也使用同一版本。中间包不是发布产物，但它仍是当前构建中必须成功的步骤。

## 2026-11-01 已有日志中的工具变化

依据 [运行 #1098](https://github.com/newyorkthink/linux-packaging/actions/runs/41263573517) 与 [运行 #1102](https://github.com/newyorkthink/linux-packaging/actions/runs/41298501421) 的现成日志，对比 MediaInfo、Remmina、XnView MP 三项构建所用的工具。下表的成功只指这三项构建，#1098 整次运行仍有其他项目失败。

| 工具 | 前一次对应项目构建成功 | 本次对应项目构建失败 |
| --- | --- | --- |
| linuxdeploy | build 369，git commit `07333c6` | build 372，git commit `07333c6`；日志标明构建于 2026-11-01。 |
| 中间封装使用的内置 appimagetool | build 295，git version `8c8c91f` | build 340，git version `9bab981` |
| 独立下载、供最终封装使用的 appimagetool | build 340，git version `9bab981`；最终封装成功。 | 仍下载官方 continuous 工具；这三项构建在中间阶段退出，未执行最终封装。 |

linuxdeploy 的 git commit 相同，仍可能对应包含不同内置工具的构建产物。这里记录的版本号用于定位历史证据，不用于锁定、回退或替换正式工具来源。

已对比这三项构建前一次成功时的提交 `65850a8e11bad58bcf30fac33dae6dc20dd31be9` 和本次失败时的提交 `81fabeb25abc7be3726f5d6c63fcba54a0792efe`：三个失败项目的构建脚本、公共图标与权限准备入口、公共最终封装入口及环境配置均保持原文一致。后一个提交给工具准备入口新增了直接 appimagetool 模式，但原 linuxdeploy 模式的官方 continuous 来源、输出路径和插件选择流程保持不变。本次暴露的是中间封装没有执行兼容准备的缺口，不能仅凭两次运行之间修改过公共文件，就认定是新增参数改变了旧接口。

## 两类会导致中间封装退出的问题

| 问题 | 日志中的失败依据 | 应当区分的情况 |
| --- | --- | --- |
| 根图标不可用 | `.DirIcon does not exist`，根目录没有 desktop 的 `Icon` 所指向的同名 PNG / XPM，随后输出 `no AppImage was created because .DirIcon is not valid.`。 | 原 SVG 可以保留；是否接受已有 `.DirIcon` 仍按上游实际规则判断，不能概括成禁止所有 SVG。 |
| 必要文件权限不合格 | 图标文件带有执行位，模式为 `0745`，工具据此检查各用户的执行权限；该路径被列为 `ERROR`，随后输出 `found 1 ERROR(S) in the AppDir` 并拒绝生成 AppImage。 | 其他文件的权限 warning 不等于本次退出原因，应以实际致命错误和退出码为准。 |

这些错误发生在 linuxdeploy 的 AppImage 输出插件调用 appimagetool 时。依赖部署完成，不等于中间封装完成；日志中的普通 notice、warning 或未使进程退出的其他报错，也不能代替真正的失败原因。

图标选择、有效 `.DirIcon` 的回退条件、SVG 转 PNG 的依赖和现有公共处理，见 [appimagetool 图标检查与 SVG 兼容处理](./appimagetool-icon-compatibility.md)。

## 公共处理应覆盖的位置

处理原则是复用现有公共权限与 PNG 准备，让中间封装和最终封装都取得合格的 AppDir，保留已确认的 linuxdeploy 命令、AppRun、依赖来源及最终封装路线。

1. 中间阶段的准备应在依赖、desktop 和图标部署完成后，输出插件实际调用 appimagetool 前执行；只在最终封装前处理，无法修复更早的失败。
2. 不能只把现有准备调用盲目前移到 linuxdeploy 命令之前。公共入口依赖根目录 desktop；根 desktop 尚未部署时会直接返回，而且后续部署还可能新增文件或保留原有权限。
3. 最终封装前的公共准备仍需保留，因为两个阶段之间可能还有应用专属的目录修正和文件整理。不得通过发布中间包、忽略失败或锁定旧工具绕过问题。

提交 `68b4ddaaa7aeaa28738ce341e9f115e0fc0b8f01` 当时只补充已有证据与处理边界，未实施代码修复。当前已接入的公共处理见下一节；原故障、版本对比与处理边界继续保留。

## 2026-11-01：接入中间封装的公共准备

本次代码修复由两个公共文件完成，三个应用的 build、AppRun、linuxdeploy 命令和最终封装命令保持原文不变：

| 公共文件 | 当前职责 |
| --- | --- |
| [工具准备入口](../common/linuxdeploy/prepare_linuxdeploy_tools.sh) | 普通 linuxdeploy 模式额外下载并校验当前官方 AppImage 输出插件，只从资产中提取原始插件程序为 `appimage-output`，与当前下载的 appimagetool 放在同一目录；安装外部包装入口和公共准备脚本的链接。原独立执行、source 参数及直接 appimagetool 模式保留。 |
| [输出包装入口](../common/linuxdeploy/linuxdeploy-plugin-appimage.sh) | 对插件探测和帮助查询直接调用官方入口；实际收到 `--appdir` 后先准备权限和 PNG，再原样传递全部参数并执行官方输出插件，保留原 LDAI 配置和退出状态。 |

本次检查发现，当前官方独立输出插件资产仍捆绑 appimagetool build 295。本仓库只提取其中未经修改的插件程序；按其官方源码的同目录搜索规则，实际调用本次独立下载并校验的 appimagetool，而不依赖资产内的旧工具。

这是本仓库的构建工具兼容包装，不是应用 AppRun、启动 hook，也没有重写官方输出插件的参数转换和封装逻辑。官方输出插件仍处理输出路径、runtime、AppStream、更新信息、签名等环境配置。输出插件保存在工具目录，不放入 AppDir；中间产物仍不发布，最终产物与版本保存仍使用原公共封装入口。

### 官方接入依据

- [linuxdeploy 插件查找源码](https://github.com/linuxdeploy/linuxdeploy/blob/07333c6e942c7d71782b66be924c5d867f9dfdfc/src/plugin/plugin.cpp)：优先扫描 linuxdeploy AppImage 所在目录，同名外部插件先于内置插件。
- [linuxdeploy 执行顺序](https://github.com/linuxdeploy/linuxdeploy/blob/07333c6e942c7d71782b66be924c5d867f9dfdfc/src/main.cpp)：输入插件和根桌面资源部署完成后，才调用输出插件。
- [官方输出插件说明](https://github.com/linuxdeploy/linuxdeploy-plugin-appimage/blob/536b068787179ea901964bd7dabc7bf61e4941c3/README.md) 与 [源码](https://github.com/linuxdeploy/linuxdeploy-plugin-appimage/blob/536b068787179ea901964bd7dabc7bf61e4941c3/src/main.cpp)：支持外部输出入口、插件探测、`--appdir` 及既有 LDAI 参数转换。

上述固定 commit 仅定位本次所读证据；正式工具仍动态下载官方 continuous 资产并核对 SHA-256，不固定旧版本。

### 验证范围

- 已实际下载并校验当前官方工具，验证官方输出插件本体的提取、外部入口安装和 linuxdeploy 的选择优先级。
- 在隔离临时目录中，用 linuxdeploy build 372 的内置输出入口分别复现 SVG 根图标和 `0745` 权限失败；修复后让中间封装明确使用本次 appimagetool build 340。三个临时 AppDir 均通过中间封装、最终封装及小型 CLI 启动，`.DirIcon` 指向 PNG，AppRun 正文与包外文件权限保持不变，最终版本文件正确。SVG 转换使用隔离命令入口调用系统 librsvg / Cairo 实际渲染，未安装或改变系统软件包。
- 已检查 Shell 语法、六种原插件组合、独立执行及 source 参数、直接 appimagetool 双文件模式，以及准备失败、官方插件失败时的退出状态、参数和 LDAI 环境传递。接口检查的联网调用使用临时固定数据，工具本体与封装另按上一项实际执行。
- 已核对正文、相对链接和完整 diff。没有将验证脚本加入仓库，也没有修改应用 build、AppRun、workflow 或手动触发 Actions。

这些结果验证公共接入位置与两类故障的修复，不代替三个完整应用的新一轮正式构建及桌面功能验收；本次未执行这三项完整应用构建，提交后不等待或监控 Actions。既有用户实测成功的功能和运行配置继续作为稳定基线保留。
