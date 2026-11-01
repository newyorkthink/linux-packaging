# linuxdeploy 更新与中间封装兼容

## 为什么相同脚本会从成功变成失败

本仓库通过公共工具准备入口动态下载官方 continuous 资产。下载地址和构建脚本保持不变，不代表每次下载到的 linuxdeploy 文件相同；它内置的 AppImage 输出插件和 appimagetool 也可能随构建更新。

linuxdeploy 的依赖部署与最后独立执行的 appimagetool 封装是两个阶段。中间封装提前失败时，后面的公共权限、图标准备和最终封装均不会执行。此前多次成功，只能证明当时的工具组合能完成该流程，不能证明后续工具更新仍会接受尚未整理的 AppDir。

## 两个封装阶段

| 阶段 | 实际使用的工具 | 当前公共准备的位置 |
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

本次只补充已有证据与处理边界，未修改公共脚本或应用构建脚本，也未实施中间封装修复。实现公共接入点时仍须核实当前输出插件的实际调用方式；本文不提供未经验证的 wrapper 或替代封装命令。
