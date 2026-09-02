# Mission Center AppImage

## 用途与产物

本目录用于将 Arch Linux Extra 仓库中的官方 `mission-center` 软件包重新封装为可分发 AppImage。

- 上游项目：Mission Center
- 软件来源：Arch Linux Extra `mission-center`
- 架构：x86_64
- 稳定产物：`dist/mission-center.AppImage`
- 构建入口：`build_mission-center.sh`
- CI 入口：`.github/workflows/build.yml`

Mission Center 用于查看 CPU、内存、磁盘、网络、GPU、应用与进程等系统资源信息。

## 技术栈

Mission Center 是 Rust 编写的 GTK4 / Libadwaita 原生 Linux 应用。Arch Linux 软件包同时提供：

- `/usr/bin/missioncenter`：主界面程序。
- `/usr/bin/missioncenter-magpie`：系统信息采集后端。
- GSettings schema、图标、desktop、AppStream、硬件数据库和 gresource 等运行资源。
- GNU gettext 翻译资源，其中 `zh` 为简体中文，`zh_TW` 为繁体中文。
- Fcitx5 中文输入通过 Arch `fcitx5-gtk` 提供的 GTK4 IM module 与宿主 Fcitx5 服务通信；AppImage 只封装 GTK4 客户端输入模块及其依赖，不内置或启动 Fcitx5 守护进程。

## 打包方式

构建环境使用仓库统一的 Arch Linux AnyLinux 容器和 `quick-sharun`。

构建脚本执行以下步骤：

1. 使用 `pacman` 安装 Arch Linux Extra 当前正式版 `mission-center`、`fcitx5-gtk` 及构建所需依赖，不锁定具体应用版本。
2. 核对主程序、`missioncenter-magpie`、desktop、图标、简体/繁体中文 gettext 文件，以及 GTK4 Fcitx5 IM module 与系统生成的 `giomodule.cache`。
3. 按 Mission Center 上游当前 AppImage 方案，同时把 `missioncenter` 与 `missioncenter-magpie` 交给 `quick-sharun` 部署。
4. 由 `quick-sharun` 收集 GTK4、Libadwaita、Fcitx5 GTK4 IM module 及其 ELF 依赖、应用数据和 gettext 资源；随后在 AppDir 的 GTK4 `immodules` 目录执行 `gio-querymodules`，生成适用于 GTK4 的 `giomodule.cache`。
5. 生成 AppImage 自带的 `zh_CN.UTF-8` glibc locale 数据，在 `.env` 中设置简体中文消息环境。
6. 由 `quick-sharun --make-appimage` 生成稳定文件名 `dist/mission-center.AppImage`。

## 中文环境

本 AppImage 使用 Mission Center 上游正式 gettext 翻译，不使用插件、第三方语言包或二进制汉化补丁。

运行时固定：

```text
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
```

其中：

- `zh_CN.UTF-8` locale 数据直接内置到 AppImage，不要求宿主预先生成该 locale。
- `LANGUAGE=zh_CN:zh` 会优先请求简体中文，并回退到上游实际使用的 `zh/LC_MESSAGES/missioncenter.mo`。
- `LC_MESSAGES` 只固定界面消息语言，不强制覆盖其他区域格式类别。
- `zh_TW/LC_MESSAGES/missioncenter.mo` 同样随包保留，但默认界面选择简体中文。

## Fcitx5 中文输入

Mission Center 是 GTK4 应用。构建时额外安装 Arch `fcitx5-gtk`，由 `quick-sharun` 按现有 GTK 部署逻辑自动收集 GTK4 的 `libim-fcitx5.so` 及其动态链接依赖，不手工复制库文件。

GTK4 与 GTK2/GTK3 的输入模块缓存机制不同：GTK4 的 `immodules` 目录属于 GIO 模块机制，缓存文件是同目录下的 `giomodule.cache`，由 `gio-querymodules` 生成，而不是 GTK2/GTK3 使用的 `immodules.cache`。因此构建脚本在 `quick-sharun` 部署完成后，会对 AppDir 自己的 GTK4 `immodules` 目录重新执行 `gio-querymodules`，并强制确认缓存包含 `libim-fcitx5.so: gtk-im-module`。

AppImage 不内置 Fcitx5 输入法守护进程、输入方案或用户配置。运行时仍由宿主会话中已经运行的 Fcitx5 服务提供实际输入；当会话使用 `GTK_IM_MODULE=fcitx` 时，AppImage 内置的 GTK4 Fcitx5 IM module 负责让 Mission Center 的 GTK4 文本框连接宿主 Fcitx5。

## 运行与验证

在当前目录执行：

```bash
./dist/mission-center.AppImage
```

构建阶段会检查：

- Arch Linux 官方包中的主程序与 magpie 后端均存在。
- 简体中文与繁体中文 `missioncenter.mo` 均存在且可由 `msgunfmt` 正确解析。
- Arch `fcitx5-gtk` 已提供 GTK4 `libim-fcitx5.so`，且系统 GTK4 `giomodule.cache` 已登记 `libim-fcitx5.so: gtk-im-module`。
- `quick-sharun` 打包后 GTK4 Fcitx5 IM module 仍存在，并通过 `ldd` 检查，不允许存在 `not found` 动态链接依赖。
- AppDir 的 GTK4 `immodules` 目录重新生成 `giomodule.cache` 后，缓存必须登记 `libim-fcitx5.so: gtk-im-module`。
- `quick-sharun` 打包后两套中文翻译仍存在于 AppDir。
- AppImage 内的 `zh_CN.UTF-8` locale 数据成功生成。
- `.env` 中的中文环境变量和 `LOCPATH` 均完整写入。
- 最终 `dist/mission-center.AppImage` 非空。

Mission Center 的部分硬件指标仍取决于宿主内核、驱动、硬件能力和上游自身支持范围；本打包方案不额外修改这些系统级行为。

## 修复 / 变更记录

### 2026-09-02：新增 Mission Center AppImage 与独立简体中文环境

- 现象：仓库此前没有 Mission Center AppImage 项目，无法通过统一 workflow 构建和发布带明确简体中文环境的稳定资产。
- 根因：Mission Center 上游已经提供正式中文 gettext 资源，但仓库尚未建立对应 AppImage 打包与 locale 运行环境。
- 修改文件：`mission-center/build_mission-center.sh`、`mission-center/README.md`、`.github/workflows/build.yml`。
- 处理：基于 Arch Linux Extra 当前 `mission-center` 包和上游 `quick-sharun` AppImage 路线新增构建；保留官方 `zh` / `zh_TW` 翻译，内置 `zh_CN.UTF-8` locale，并固定界面消息使用简体中文。
- 验证：构建脚本包含 gettext、locale、`.env` 和最终 AppImage 的强制检查；workflow 纳入 push、手动选择、定时全量构建与 latest Release 发布路径。

### 2026-09-02：修复 quick-sharun 缺少 patchelf

- 现象：GitHub Actions 的 `Build Mission Center` 在安装 `mission-center` 1.2.0-1 后，于首次执行 `quick-sharun` 时直接报错 `ERROR: Missing dependency 'patchelf'!` 并退出。
- 根因：仓库统一 AnyLinux 环境安装了 `base-devel`，但当前 `quick-sharun` 的硬依赖列表明确包含 `patchelf`；Arch Linux 的 `base-devel` 不提供该命令，原 Mission Center 构建脚本也未显式安装。
- 修改文件：`mission-center/build_mission-center.sh`、`mission-center/README.md`。
- 处理：在 Mission Center 构建依赖中显式加入 `patchelf`，并将 `patchelf` 纳入构建命令自检，使缺失依赖在调用 `quick-sharun` 前即可被明确检测。
- 验证：已核对失败 Job `100167329168` 的完整日志以及当前 `quick-sharun` 的硬依赖列表；该 Job 在进入打包前唯一报告的缺失硬依赖为 `patchelf`。修复提交由 Mission Center 独立 Job 再次执行完整构建验证。

### 2026-09-02：修复 GTK4 / Fcitx5 中文输入

- 现象：Linux 实机运行 AppImage 时界面中文显示正常，但 GTK4 搜索框只能直接输入 ASCII；终端同时报告 `Gtk-WARNING: No IM module matching GTK_IM_MODULE=fcitx found`。
- 根因：构建环境没有安装 `fcitx5-gtk`，因此没有 GTK4 `libim-fcitx5.so` 可供 `quick-sharun` 收集；进一步核对 GTK4 和当前 `quick-sharun` 后确认，GTK4 输入模块使用 `immodules/giomodule.cache`，而 `quick-sharun` 对 `gtk-*/*/immodules/*.so` 的通用缓存后处理仍尝试读取 GTK2/GTK3 风格的 `immodules.cache`，因此仅安装模块仍不足以保证 GTK4 能发现 Fcitx5。
- 修改文件：`mission-center/build_mission-center.sh`、`mission-center/README.md`。
- 处理：在构建依赖中加入 Arch `fcitx5-gtk`，继续由 `quick-sharun` 部署 GTK4 Fcitx5 IM module 及 ELF 依赖；随后在 AppDir 的 GTK4 `immodules` 目录执行 `gio-querymodules` 重新生成 `giomodule.cache`。不手工复制库，也不修改已经生效的中文 locale、GPU 或 workflow 逻辑。
- 验证：构建前检查系统 `libim-fcitx5.so` 与 GTK4 `giomodule.cache`；打包后检查 AppDir 内模块、`ldd` 依赖以及重新生成的 `giomodule.cache`，并要求缓存明确包含 `libim-fcitx5.so: gtk-im-module`。实际输入仍由宿主正在运行的 Fcitx5 服务提供。
