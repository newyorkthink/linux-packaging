# DwarFS AppImage 图标预览：已知限制与无法修复原因

本文是 KDE Suite 中“DwarFS 格式 AppImage 在 Dolphin 中显示通用图标”问题的唯一完整记录，集中保存当前结论、无法修复的原因和全部历史检查。[KDE Suite README](../README.md) 只保留摘要和链接。

## 当前结论（2026-11-17）

**状态：确认当前无法可靠修复，按已知限制长期保留。用户于 2026-11-17 确认不再修复，只做记录。**

- **影响范围：** 只影响 Dolphin 对 DwarFS 格式 AppImage 内置图标的预览，这类文件显示为通用文件图标。AppImage 本身照常执行；SquashFS 格式的 AppImage 仍能显示内置图标和元数据。
- **本次现象：** 用户 2026-11-17 提供的 Dolphin 实机截图中，同一目录下 `bcompare.AppImage`、`parsec.AppImage` 显示通用图标，`navicat-premium-lite.AppImage`、`smartgit.AppImage`、`smartsynchronize.AppImage` 正常显示应用图标。其中 Parsec 由本仓库按 quick-sharun 路线打包。本次未逐个检查截图中各文件的实际封装格式，现象与下文历史检查一致。

### 无法修复的原因

1. **现有读取链路不支持 DwarFS，属于上游缺口。** Dolphin 的 AppImage 图标由 kio-extras 的 `appimagethumbnail.so` 生成，该插件调用 libappimage 读取 `.DirIcon`，而 libappimage 的 Type 2 读取只支持 SquashFS。2026-11-17 复查：Arch 仓库的 libappimage 仍为 1.0.4.5；KDE [Bug 510656](https://bugs.kde.org/show_bug.cgi?id=510656)（要求不依赖 libappimage、原生显示 AppImage 图标）仍为 CONFIRMED 状态，上游尚未提供 DwarFS 支持。
2. **替代组件已经试过，没有通过。** 候选组件 [kem-a/appimage-thumbnailer](https://github.com/kem-a/appimage-thumbnailer) 在 2026-11-17 复查时最新版本仍为 v4.1.1（2026-07-21 发布），也就是 2026-10-23 云端复核失败的版本。它能从 DwarFS 包中取出图标，但在套件包内运行库下，GdkPixbuf 解码 PNG 超时，根因没有查明，详见下文 2026-10-23 记录。上游没有发布新版本，不具备重试依据。
3. **剩下的方向要撤掉现有插件并自写替代实现。** KIO 已支持 freedesktop 标准的 `.thumbnailer` 缩略图描述文件，但只在某个文件类型没有 KIO 自带插件时才会使用。要走这条路，必须移除现有的 `appimagethumbnail.so`，改由自写脚本提取 `.DirIcon`；SVG 图标转换、包内调用、关闭缩略图缓存时及信息面板中不使用该机制等问题都没有验证。这属于对上游格式缺口的本地规避，按 [AGENTS.md](../../AGENTS.md) 中“上游 Bug 默认保留”的规则不实施，本次也没有做任何验证。

### 处理决定

- 不加入候选组件、DwarFS 提取工具、自写 thumbnailer、补丁或启动干预，不修改构建脚本、依赖和工作流。现有 `appimagethumbnail.so` 与 AppImage 元数据插件保持原样，继续支持 SquashFS 格式的 AppImage。
- 下文 2026-09-12 记录中“后续需要修复时……证据不足时继续保持待确认”的建议，以及 2026-10-22 记录中“后续如需处理”的步骤，已被本结论取代，只作为历史保留。
- 重新评估的条件：libappimage 或 KIO 正式支持 DwarFS，或候选组件发布能够解决包内解码问题的新版本。届时先核对上游当前实现，再按逐次授权规则提出修改清单；不得依据本文自动恢复任何方案。
- 本项不再列为待修或待验收事项，不要求用户重复测试。

## 历史记录

以下记录按时间顺序完整保留，描述的是当时的检查过程和判断；当前状态以上文“当前结论”为准。

### 2026-09-12：Dolphin 部分 AppImage 图标预览

本条原位于 [KDE Suite README](../README.md) 的“检查记录”，2026-11-17 原样迁入本文。

- **检查对象与范围：** 基于仓库提交 `9daecb62f06487341911024f9063722d85a15bb8`，完整阅读 `kde-suite/` 的 12 个文件，核对相关 workflow 的项目选择、独立 Arch 构建容器、公共 action、脚本调用顺序和产物路径。目录内 7 个 Shell 文件的仓库外 `bash -n` 语法检查通过；未发现明显的入口、脚本引用或产物路径错误。
- **问题现象：** 真实运行截图中，Dolphin 的工具栏、文件夹等界面图标正常，部分 AppImage 显示应用图标，另一些显示通用文件图标。此次检查针对 AppImage 内置图标预览，不是整个图标主题失效。
- **证据与已确认结论：** `deploy_suite_apps.sh` 已恢复 `appimagethumbnail.so` 和 AppImage 元数据插件，不能只因 `build_core.sh` 基础阶段移除插件就认定最终漏打包。[KDE 缩略图插件源码](https://github.com/KDE/kio-extras/blob/master/thumbnail/appimagecreator.cpp) 通过 libappimage 读取 `.DirIcon`；[libappimage 的 Type 2 读取实现](https://github.com/AppImageCommunity/libappimage/blob/master/src/libappimage/type2.c) 使用 SquashFS。[检查时的 quick-sharun](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/useful-tools/quick-sharun.sh) 调用的 [pkgforge appimagetool](https://github.com/pkgforge-dev/appimagetool) 使用 DwarFS。该格式兼容缺口与现有“已知限制”及截图现象吻合；上游链接跟随分支变化，后续应重新核对。
- **未确认事项：** 未逐个取得并检查截图中的实际 AppImage，未确认各文件的封装格式、`.DirIcon` 内容及链接目标，也未核对当前使用的 KDE Suite 成品。因此不能断言所有通用图标均由 DwarFS 导致，不能认定包内图标丢失，也不能把脚本语法通过视为构建或实机功能通过。本次未触发或监控 Actions，未重新构建或完成实机验证。
- **当前处理建议：** 保留已验证的打包、主题和启动逻辑，不凭截图改动插件或更换封装工具。后续需要修复时，先对实际缺图标文件核实格式和 `.DirIcon`，再结合 Dolphin 的实际解析结果判断修改范围；证据不足时继续保持待确认。
- **记录状态：** 本条是检查记录，本次仅补充 README，没有实施程序修复。后续有对应修复时，用修复记录替换已处理条目，保留尚未确认部分，并如实注明验证状态。

### 2026-10-22：首次记录

**状态：问题尚未修复，仅供排查参考；本次只记录，不加入修复代码或候选组件。**

#### 问题与上游依据

Dolphin 中部分 AppImage 显示通用文件图标，无法预览包内应用图标。本记录针对 AppImage 的内置图标预览，与工具栏、文件夹和侧栏的图标主题分别处理。

本次核对的 [KDE AppImage 缩略图插件](https://github.com/KDE/kio-extras/blob/master/thumbnail/appimagecreator.cpp) 调用 libappimage 读取 `.DirIcon`；[libappimage 的 Type 2 读取实现](https://github.com/AppImageCommunity/libappimage/blob/master/src/libappimage/type2.c) 使用 SquashFS。本次成品内该读取接口无法读取下列 DwarFS 样本，属于所用读取链路的格式支持缺口。不能据此断言所有通用图标均由 DwarFS 导致，也不能推断文件内图标已经丢失。

#### 云端检查对象与结果

样本于 2026-10-22 从本仓库 [latest Release](https://github.com/newyorkthink/linux-packaging/releases/tag/latest) 下载，已核对文件大小和 SHA-256。以下结果仅对应本次下载快照；后续同名资产可能更新。

云端宿主为 Ubuntu 24.04，使用独立 HOME/XDG 目录。原组件检查调用 KDE Suite 成品内 libappimage 的同一读取接口；候选组件为 [kem-a/appimage-thumbnailer v4.1.1](https://github.com/kem-a/appimage-thumbnailer/releases/tag/v4.1.1)，DwarFS 提取使用官方 [DwarFS 0.15.8](https://github.com/mhx/dwarfs/releases/tag/v0.15.8)。这些版本用于说明历史检查对象，不是生产环境固定版本要求。

| 样本 | 实际封装 | 原组件读取 `.DirIcon` | 候选组件使用云端宿主库独立运行 |
| --- | --- | --- | --- |
| `cc-switch.AppImage` | DwarFS | 失败 | 成功生成有效、非空的 256×256 PNG |
| `aionui.AppImage` | DwarFS | 失败 | 成功生成有效、非空的 256×256 PNG |
| `kde-suite.AppImage` | DwarFS | 失败 | 成功生成有效、非空的 256×256 PNG |
| `hermes-desktop.AppImage` | SquashFS | 成功 | 成功生成有效、非空的 256×256 PNG |

原组件读取三个 DwarFS 样本时均输出 `This doesn't look like a squashfs image`，返回失败且没有取得图标数据；SquashFS 对照读取成功。

本次样本的 SHA-256：

- `cc-switch.AppImage`：`f68009b1643554ebd2874935a00600cec00804280090a5f27677776ee3574b3c`
- `aionui.AppImage`：`cd64bc41ebddfe73015ae5ee61a9b0907da673e7afe0afe72a2c5aa05e06bf63`
- `kde-suite.AppImage`：`5b50917ab4bbe92e7924353f1531ead89502e3a3c7ff50c1ab79f217bca3c214`
- `hermes-desktop.AppImage`：`dca676db9ef9b784cebbe2c1b7f4e27784f71405b79caf2f602158edb38b744c`

#### 包内集成尚未通过

仅在云端解包副本中临时放入候选组件和提取工具，通过 KDE Suite 的 sharun 入口及包内加载器、运行库进行检查，没有改动仓库。

CC Switch 的 DwarFS 提取已成功，取得 15560 字节 PNG 图标数据；后续 GdkPixbuf 图片解码超时，最后日志停在 Glycin 的 bwrap 可用性检测。将一个已验证有效的普通 PNG 直接交给图片解码接口，也在包内运行库下复现超时；同一 PNG 在云端宿主运行库下读取成功。

上述对照区分了 DwarFS 提取与包内图片解码两个阶段，但尚未查清解码超时的具体原因，不能据此判断用户实机也会出现同样卡顿。候选组件独立生成 PNG，不等于已经完成 KDE Suite 集成。

此次没有完成 Dolphin/KIO 的实际缩略图调用、候选组件与原生插件的选择优先级、预览设置及缓存效果的图形验收，也没有完成新 AppImage 的完整构建和实机验收。AppImage 元数据提取不在本次验证范围内。

#### 当前处理决定

目前按已知限制保留，只新增本文档。不加入候选缩略图组件、提取工具、插件、补丁或启动干预，不修改现有打包脚本、依赖、工作流及已验证有效的修复。

本文档不参与当前功能文件版本指纹，不提供安装或启用步骤，也不构成重新实施修复的授权。现有 KIO worker、图标引擎、Kirigami Forms、Haruna 和其他稳定内容保持原样。

后续如需处理，应先重新核对上游当前支持情况，再验证包内图片解码、Dolphin/KIO 调用链以及 SquashFS 兼容性。只有用户知晓格式支持缺口及验证边界后，仍明确要求修复并批准具体修改清单，才实施代码或依赖变更。

相关历史说明见 [KDE Suite README](../README.md)。上游分支链接会随源码更新而变化，后续分析需重新核对，不能把本文当作当前版本已修复的证明。

### 2026-10-23：云端复核未通过，停止本轮修复

本轮仅在 Ubuntu 24.04 云端解包副本和独立 HOME/XDG 目录中验证，未改动正式功能文件。使用本仓库 Release 中重新下载并核对大小和 SHA-256 的 `cc-switch.AppImage`、`kde-suite.AppImage`、`hermes-desktop.AppImage`，以及上游当时最新的 `appimage-thumbnailer v4.1.1` 预编译 DEB。以下结果对应本轮下载快照，不沿用上文 2026-10-22 的样本摘要，也不是生产版本固定要求。

#### 已通过的部分

- DwarFS 内容提取成功：CC Switch 的 `.DirIcon` 为 15560 字节 PNG，KDE Suite 的 `.DirIcon` 为 412 字节 SVG。
- 候选组件使用云端系统库时，能够为上述两个 DwarFS 样本及 Hermes Desktop 的 SquashFS 样本生成有效、非空的 256×256 PNG。
- 候选组件使用包内运行库时，KDE Suite 的 SVG 图标也能生成有效 PNG。因此不能把本轮失败笼统归为 DwarFS 提取失败，也不能把 SVG 成功扩大为所有图标或 Dolphin 实际预览已经正常。

#### 仍卡住的位置

- 使用包内运行库处理普通 32×32 PNG 时，GdkPixbuf 解码在 30 秒内未完成；同一 PNG 使用云端系统库能够立即解码。
- 候选组件通过包内入口处理 CC Switch 时，DwarFS 提取已经成功，但后续 PNG 解码在 12 秒内未完成。最后日志均停在 Glycin 的 `Testing bwrap availability`，没有取得该检测返回及图片解码完成的结果。
- 直接通过包内动态加载器运行 PNG 解码探针（绕过 sharun 入口），以及在此基础上将 PATH 改为系统目录的对照，也分别在 12 秒、8 秒内未完成。尚未锁定根因，不能把最后一条日志直接认定为 bwrap 本身存在 Bug，也不能断定属于上游或打包问题。

#### 验证边界与处理决定

云端独立调用 bwrap 时存在 namespace/NETLINK_ROUTE 权限错误，strace 也因 ptrace 权限限制未取得系统调用跟踪。这些限制只描述当前云端验证环境，不能据此判断用户实机同源或同样卡顿。

本轮没有完成 Dolphin/KIO 实际缩略图调用、插件选择优先级、包内 SquashFS 兼容性和普通文件预览的完整图形验证，也没有生成新的正式 AppImage 或进行用户实机验收；部分样本能生成 PNG，不等于可靠集成已经通过。

**按用户要求停止本轮修复，继续保留 DwarFS AppImage 显示通用图标的已知限制。** 不加入候选组件、提取工具、补丁、禁用沙箱、提权或其他启动干预，不改动现有打包脚本、依赖和工作流。没有新的有效证据及用户针对具体修改的明确授权，不自动重复本轮失败方向，也不要求用户重复测试。
