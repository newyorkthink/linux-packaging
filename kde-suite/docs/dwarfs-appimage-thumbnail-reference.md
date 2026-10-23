# DwarFS AppImage 图标预览问题记录（2026-10-22）

**状态：问题尚未修复，仅供排查参考；本次只记录，不加入修复代码或候选组件。**

## 问题与上游依据

Dolphin 中部分 AppImage 显示通用文件图标，无法预览包内应用图标。本记录针对 AppImage 的内置图标预览，与工具栏、文件夹和侧栏的图标主题分别处理。

本次核对的 [KDE AppImage 缩略图插件](https://github.com/KDE/kio-extras/blob/master/thumbnail/appimagecreator.cpp) 调用 libappimage 读取 `.DirIcon`；[libappimage 的 Type 2 读取实现](https://github.com/AppImageCommunity/libappimage/blob/master/src/libappimage/type2.c) 使用 SquashFS。本次成品内该读取接口无法读取下列 DwarFS 样本，属于所用读取链路的格式支持缺口。不能据此断言所有通用图标均由 DwarFS 导致，也不能推断文件内图标已经丢失。

## 云端检查对象与结果

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

## 包内集成尚未通过

仅在云端解包副本中临时放入候选组件和提取工具，通过 KDE Suite 的 sharun 入口及包内加载器、运行库进行检查，没有改动仓库。

CC Switch 的 DwarFS 提取已成功，取得 15560 字节 PNG 图标数据；后续 GdkPixbuf 图片解码超时，最后日志停在 Glycin 的 bwrap 可用性检测。将一个已验证有效的普通 PNG 直接交给图片解码接口，也在包内运行库下复现超时；同一 PNG 在云端宿主运行库下读取成功。

上述对照区分了 DwarFS 提取与包内图片解码两个阶段，但尚未查清解码超时的具体原因，不能据此判断用户实机也会出现同样卡顿。候选组件独立生成 PNG，不等于已经完成 KDE Suite 集成。

此次没有完成 Dolphin/KIO 的实际缩略图调用、候选组件与原生插件的选择优先级、预览设置及缓存效果的图形验收，也没有完成新 AppImage 的完整构建和实机验收。AppImage 元数据提取不在本次验证范围内。

## 当前处理决定

目前按已知限制保留，只新增本文档。不加入候选缩略图组件、提取工具、插件、补丁或启动干预，不修改现有打包脚本、依赖、工作流及已验证有效的修复。

本文档不参与当前功能文件版本指纹，不提供安装或启用步骤，也不构成重新实施修复的授权。现有 KIO worker、图标引擎、Kirigami Forms、Haruna 和其他稳定内容保持原样。

后续如需处理，应先重新核对上游当前支持情况，再验证包内图片解码、Dolphin/KIO 调用链以及 SquashFS 兼容性。只有用户知晓格式支持缺口及验证边界后，仍明确要求修复并批准具体修改清单，才实施代码或依赖变更。

相关历史说明见 [KDE Suite README](../README.md)。上游分支链接会随源码更新而变化，后续分析需重新核对，不能把本文当作当前版本已修复的证明。

## 2026-10-23：云端复核未通过，停止本轮修复

本轮仅在 Ubuntu 24.04 云端解包副本和独立 HOME/XDG 目录中验证，未改动正式功能文件。使用本仓库 Release 中重新下载并核对大小和 SHA-256 的 `cc-switch.AppImage`、`kde-suite.AppImage`、`hermes-desktop.AppImage`，以及上游当时最新的 `appimage-thumbnailer v4.1.1` 预编译 DEB。以下结果对应本轮下载快照，不沿用上文 2026-10-22 的样本摘要，也不是生产版本固定要求。

### 已通过的部分

- DwarFS 内容提取成功：CC Switch 的 `.DirIcon` 为 15560 字节 PNG，KDE Suite 的 `.DirIcon` 为 412 字节 SVG。
- 候选组件使用云端系统库时，能够为上述两个 DwarFS 样本及 Hermes Desktop 的 SquashFS 样本生成有效、非空的 256×256 PNG。
- 候选组件使用包内运行库时，KDE Suite 的 SVG 图标也能生成有效 PNG。因此不能把本轮失败笼统归为 DwarFS 提取失败，也不能把 SVG 成功扩大为所有图标或 Dolphin 实际预览已经正常。

### 仍卡住的位置

- 使用包内运行库处理普通 32×32 PNG 时，GdkPixbuf 解码在 30 秒内未完成；同一 PNG 使用云端系统库能够立即解码。
- 候选组件通过包内入口处理 CC Switch 时，DwarFS 提取已经成功，但后续 PNG 解码在 12 秒内未完成。最后日志均停在 Glycin 的 `Testing bwrap availability`，没有取得该检测返回及图片解码完成的结果。
- 直接通过包内动态加载器运行 PNG 解码探针（绕过 sharun 入口），以及在此基础上将 PATH 改为系统目录的对照，也分别在 12 秒、8 秒内未完成。尚未锁定根因，不能把最后一条日志直接认定为 bwrap 本身存在 Bug，也不能断定属于上游或打包问题。

### 验证边界与处理决定

云端独立调用 bwrap 时存在 namespace/NETLINK_ROUTE 权限错误，strace 也因 ptrace 权限限制未取得系统调用跟踪。这些限制只描述当前云端验证环境，不能据此判断用户实机同源或同样卡顿。

本轮没有完成 Dolphin/KIO 实际缩略图调用、插件选择优先级、包内 SquashFS 兼容性和普通文件预览的完整图形验证，也没有生成新的正式 AppImage 或进行用户实机验收；部分样本能生成 PNG，不等于可靠集成已经通过。

**按用户要求停止本轮修复，继续保留 DwarFS AppImage 显示通用图标的已知限制。** 不加入候选组件、提取工具、补丁、禁用沙箱、提权或其他启动干预，不改动现有打包脚本、依赖和工作流。没有新的有效证据及用户针对具体修改的明确授权，不自动重复本轮失败方向，也不要求用户重复测试。
