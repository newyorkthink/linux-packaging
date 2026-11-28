# 待办：推进剩余 AppImage 构建脚本按标准模板整理

**状态：待分批处理。** 本页汇总全仓活跃 AppImage 项目中，尚未按[固定 13 份打包模板](../../Templates/README.md)整理且未登记到[专用打包流程](../packaging-classification.md#专用打包流程)的 **14 个项目**，供维护者与后续 AI 按批推进。

## 处理目标与执行规则

本清单仅用于进度追踪与分批规划，**不构成任何批量修改或自动重写授权**。处理其中任意单个或一批项目前，仍须遵守 [AGENTS.md](../../AGENTS.md)：

1. **先核实两项来源**：先查[上游打包参考索引](../upstream-packaging-index.md)与 `pkgforge-dev` 当前源码，再核实 Arch 官方仓库、AUR 与软件官方网站的现成二进制包及当前应用 README / 故障历史。
2. **逐次列清单授权**：列明目标应用、选用模板（或专用流程依据）、具体文件变动和影响，取得本次明确同意后再修改。
3. **按标准重写流程执行**：符合固定 13 份模板时，先原样备份旧脚本为 `build_<应用名>_old.sh`（排除所有 Action），再通过[统一远端生成入口](../../Scripts/build/generate_build_script.md)全新生成正式脚本；仅在出现实际报错或反馈时按证据定向恢复最小专属处理，并在 `docs/template-deviations.md` 记录（满足 `AGENTS.md` 本地工作区直接最终版例外并获授权时按该例外处理）。
4. **模板无法覆盖时走专用流程**：确因源码打补丁编译、原包同步或双架构封装等与固定模板冲突时，不新增模板，按规则取得逐次授权后接入公共下载/版本/封装入口，并登记到[专用打包流程](../packaging-classification.md#专用打包流程)。
5. **单项验收后同步清理**：项目完成模板整理并补登到[打包分类](../packaging-classification.md)（若保留了 `build_*_old.sh` 备份，须在实机验证后同次删除备份及其引用）后，从本页对应分组移除该行。

## 未按模板标准的项目清单（14 个）

以下分组按改造复杂度与模板契合度由简到繁排列，便于分批推进；具体处理顺序仍以当次任务指定为准。

### 一、官方 DEB / tar / AUR 二进制包（quick-sharun，10 个）

此类多为旧式长脚本或未拆分为“先安装再独立下载解包”两阶段，部分包含直接 `curl`/`wget`/`git clone` 与内联冒烟测试：

| 应用 | 构建脚本 | 当前主要偏离 | 待确认处理方向 |
| --- | --- | --- | --- |
| AionUi | [build_aionui.sh](../../aionui/build_aionui.sh) | 旧式长脚本，直接 `yay`/`curl`，自写 `AppRun.sh` 与内联冒烟测试 | 核实官方更新来源与 AUR 情况，改由公共入口并套用 Electron DEB 模板 |
| Feishu | [build_feishu.sh](../../feishu/build_feishu.sh) | 旧式长脚本，直接 `yay`/`curl`，自写 `AppRun.sh` 与内联冒烟测试 | 核实官方 JSON DEB 接口与 AUR 配方，改由公共入口并按 Electron DEB 标准整理 |
| Stacher | [build_stacher.sh](../../stacher/build_stacher.sh) | 旧式长脚本，直接 `yay`/`curl`，自写 `AppRun.sh` 与内联冒烟测试 | 核实官方 DEB 更新端点与 AUR 配方，改由公共入口并按 Electron DEB 标准整理 |
| Tencent Docs | [build_tencent-docs.sh](../../tencent-docs/build_tencent-docs.sh) | 旧式长脚本，直接 `yay`/`curl`，自写 `AppRun.sh`、冒烟测试与自定义版本文件 | 核实官方 DEB 来源、版本传递与 `build.yml` 独立 Job 配置后按标准整理 |
| Trae | [build_trae.sh](../../trae/build_trae.sh) | 旧式脚本，直接 `yay`/`git clone`/`wget`，未用公共下载与版本入口 | 核实官方 tar/DEB 与 AUR 来源，改由公共入口并按标准整理 |
| Free Download Manager | [build_freedownloadmanager.sh](../../freedownloadmanager/build_freedownloadmanager.sh) | 旧式脚本，直接 `yay --mflags "--skipinteg"`，未拆两阶段独立下载 | 核实 AUR 与官方 DEB 来源、Qt6 依赖及私有库布局后按 `qt-deb.sh` 或对应标准整理 |
| Parsec | [build_parsec.sh](../../parsec/build_parsec.sh) | 旧式脚本，直接 `yay`/`pacman -Q`，未拆两阶段独立下载 DEB | 核实 AUR `parsec-bin` 官方 DEB 与 `ffmpeg4.4`/解码库需求后按两阶段标准整理 |
| Sunshine | [build_sunshine.sh](../../sunshine/build_sunshine.sh)（另有未接入 CI 的 [build_sunshine_latest.sh](../../sunshine/build_sunshine_latest.sh)） | 旧式脚本，直接 `yay`/`wget` 拉取固定版本 `.pkg.tar.zst` | 核实固定归档版本策略与公共下载入口，统一版本读取与保存 |
| Zotero | [build_zotero.sh](../../zotero/build_zotero.sh) | 旧式脚本，直接 `yay`/`wget`，未用公共下载与版本入口 | 核实官方预编译 tar 与 AUR 来源，切换公共下载、解包与版本入口 |
| WPS Office CN | [build_wps-office-cn.sh](../../wps-office-cn/build_wps-office-cn.sh) | 已接入部分公共脚本，但仍是旧分区注释、直接 `pacman -Q`、自定义入口改写与内联 GUI 检查 | 核实自带 Qt、符号字体与启动器修正是否超出固定模板，评估对齐标准或登记专用流程 |

### 二、linuxdeploy 与非 quick-sharun 路线（4 个）

#### 1. linuxdeploy 路线（2 个）

| 应用 | 构建脚本 | 当前主要偏离 | 待确认处理方向 |
| --- | --- | --- | --- |
| PeaZip | [build_peazip.sh](../../peazip/build_peazip.sh) | 旧版 6 个 `#` 分区标题、未合并工具准备与环境加载、非标准注释/续行/AppRun | 核实 UTF-8 补丁与后端暂移专属处理后，对齐 `linuxdeploy-qt-deb.sh` 标准风格并补 `docs/template-deviations.md` |
| 腾讯会议 | [build_wemeet.sh](../../wemeet/build_wemeet.sh) | 旧版 6 个 `#` 分区标题、独立调用 `configure_environment.sh`、非标准注释/续行 | 核实官方 JSON DEB 与 Qt5 专属处理后，对齐 linuxdeploy 标准风格并补 `docs/template-deviations.md` |

#### 2. 官方 AppImage 同步 / 重封装 / appimage-builder 路线（2 个）

| 应用 | 构建脚本 | 当前主要偏离 | 待确认处理方向 |
| --- | --- | --- | --- |
| WinPodX | [build_winpodx_release.sh](../../winpodx/build_winpodx_release.sh) | 解包补丁重封装官方 AppImage，直接调用 `gh release` 与系统 `appimagetool` | 下载与封装改走公共入口，按直接封装标准整理并评估登记专用流程 |
| Wine Staging | [build_wine.sh](../../wine/build_wine.sh) | 使用 `appimage-builder` + `uruntime` 封装双架构 Wine，直接 `curl`/`git ls-remote` 下载 | 将所有下载与校验切至公共入口，评估登记专用流程 |

## 验收与清理条件

- **单项完成条件**：对应项目完成模板整理（或经逐次授权的专用流程整理）并补登到[打包分类](../packaging-classification.md)（若保留了 `build_*_old.sh` 备份，须在实机验证后同次删除备份及其引用）后，从本页对应分组移除该行。
- **整项清理条件**：全部剩余项目均完成处理后，按[待办目录规则](./README.md#任务维护)删除本文件并移除 `./README.md` 中的对应任务条目。
