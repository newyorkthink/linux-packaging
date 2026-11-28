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

构建环境使用仓库统一的 Arch Linux 容器与 `quick-sharun`，脚本已对齐 [arch-native 标准模板](../Templates/quick-sharun/arch-native.sh)，专属配置见 [模板差异说明](./docs/template-deviations.md)：

1. 通过 `Common/arch/install_packages.sh` 安装统一基础工具（含 `gettext`、`patchelf`、`zsync` 等）、Arch `mission-center` 与 `fcitx5-gtk`，并由 `Common/build/prepare_x86_64_workspace.sh` 清理工作区。
2. 导出 `DEPLOY_GTK=1`、`GTK_DIR=gtk-4.0` 与 `DEPLOY_LOCALE=1`，通过 `Common/build/read_app_version.sh pacman mission-center` 读取实际安装的官方包版本。
3. 同时将 `/usr/bin/missioncenter` 与 `/usr/bin/missioncenter-magpie` 交给 `quick-sharun` 部署，收集 GTK4、Libadwaita、Fcitx5 GTK4 IM module 及 gettext 资源；确认包内存在 `libim-fcitx5.so` 后为最终 GTK4 `immodules` 目录写入 `giomodule.cache`。
4. 按仓库 GUI 中文规范生成 `AppDir/lib/locale/zh_CN.utf8` 并在 `.env` 追加简体中文消息环境（`LANGUAGE=zh_CN:zh`）。
5. 由 `quick-sharun --make-appimage` 生成 `dist/mission-center.AppImage`，成功后经 `Common/build/save_appimage_version.sh` 校验产物并保存 `dist/version.txt`。

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

GTK4 与 GTK2/GTK3 的输入模块缓存机制不同：GTK4 的 `immodules` 目录属于 GIO 模块机制，缓存文件是同目录下的 `giomodule.cache`，而不是 GTK2/GTK3 使用的 `immodules.cache`。Fcitx5 GTK4 模块在该缓存中的注册项为 `libim-fcitx5.so: gtk-im-module`。

系统 `/usr/lib/gtk-4.0/.../immodules/giomodule.cache` 属于系统安装环境针对实际模块目录生成的派生缓存，不是 `fcitx5-gtk` 软件包必须固定提供的文件，也不是 AppImage 构建前置条件。构建前只要求源 GTK4 `libim-fcitx5.so` 存在；`quick-sharun` 部署后再确认 AppDir 内模块存在且 `ldd` 无 `not found`，随后针对最终 AppDir 目录写入对应 GIO 注册缓存。这里不再让宿主 `gio-querymodules` 重新加载已经经过 `quick-sharun` 重定位和后处理的模块，避免构建环境与最终 AppImage 运行环境不同导致缓存探测为空。

AppImage 不内置 Fcitx5 输入法守护进程、输入方案或用户配置。运行时仍由宿主会话中已经运行的 Fcitx5 服务提供实际输入；当会话使用 `GTK_IM_MODULE=fcitx` 时，AppImage 内置的 GTK4 Fcitx5 IM module 负责让 Mission Center 的 GTK4 文本框连接宿主 Fcitx5。

## 运行与验证

在当前目录执行：

```bash
./dist/mission-center.AppImage
```

构建阶段会确认包内包含 `libim-fcitx5.so` 并写入 `giomodule.cache`（`libim-fcitx5.so: gtk-im-module`），由公共版本保存入口校验最终 `dist/mission-center.AppImage` 非空后生成 `dist/version.txt`。

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

### 2026-09-02：修正 GTK4 系统缓存前置校验

- 现象：GitHub Actions Job `100180092730` 在 `pacman` 已执行 `Updating GTK4 module cache...` 后，构建脚本仍因 `/usr/lib/gtk-4.0/4.0.0/immodules/giomodule.cache` 不存在而提前退出，尚未进入 `quick-sharun` 部署。
- 根因：上一版把系统安装环境中的 `giomodule.cache` 错误当成了构建前置条件。`fcitx5-gtk` 软件包实际提供的是 GTK4 `libim-fcitx5.so`；`giomodule.cache` 是由 `gio-querymodules` 针对具体模块目录生成的派生缓存，不是 `fcitx5-gtk` 包内固定文件，也不应作为 AppImage 是否可构建的判断依据。
- 修改文件：`mission-center/build_mission-center.sh`、`mission-center/README.md`。
- 处理：删除系统 `/usr/lib/.../giomodule.cache` 的存在性与内容校验，只保留源 GTK4 `libim-fcitx5.so` 本体检查；`quick-sharun` 完成后继续在 AppDir 自己的 GTK4 `immodules` 目录执行 `gio-querymodules`，并对最终缓存和模块依赖做强校验。
- 验证：已核对 Arch 当前 `fcitx5-gtk` 文件清单、GTK4 的 pacman hook 脚本以及 GIO `gio-querymodules` 行为；静态检查确认构建不再依赖系统缓存，最终 AppDir 缓存校验仍保留。完整构建结果以本次修改触发的 Mission Center Job 为准。

### 2026-09-02：修正 AppDir GTK4 GIO 缓存生成方式

- 现象：GitHub Actions Job `100183618023` 已成功安装 `fcitx5-gtk`，`quick-sharun` 日志也明确显示 `libim-fcitx5.so` 和 `libFcitx5GClient.so` 已部署到 AppDir，但脚本随后执行宿主 `gio-querymodules` 后没有生成 AppDir 的 `giomodule.cache`，因此在缓存存在性检查处退出。
- 根因：模块已经经过 `quick-sharun` 的收集、重定位和后处理；再使用构建容器中的宿主 `gio-querymodules` 动态加载该最终 AppDir 模块进行探测，并不能保证得到缓存。与此同时，Fcitx5 GTK4 模块的 GIO 注册项本身是确定的 `libim-fcitx5.so: gtk-im-module`，不需要依赖这次二次动态探测来推导。
- 修改文件：`mission-center/build_mission-center.sh`、`mission-center/README.md`。
- 处理：继续保留模块存在性和 `ldd` 未解析依赖强校验；随后直接为最终 AppDir `immodules` 目录写入 Fcitx5 GTK4 的标准 GIO 注册项，并用精确匹配再次校验缓存内容。删除脚本自身对 `gio-querymodules` 的构建命令依赖，不修改中文 locale、`patchelf`、GPU 或 workflow 基线。
- 验证：已核对失败 Job `100183618023` 的完整日志，确认 `quick-sharun` 实际部署路径为 `AppDir/lib/gtk-4.0/4.0.0/immodules/libim-fcitx5.so`，且 Fcitx5 的 GTK4 诊断输出使用的缓存条目为 `libim-fcitx5.so: gtk-im-module`。完整构建和 Linux 实机中文输入仍以本次修改后的产物结果为准。

## 2026-09-16：接入统一软件版本元数据

- 构建时继续从本次实际安装的 Arch `mission-center` 软件包读取版本。
- 更新器版本去掉 Arch epoch 与 pkgrel 后写入 `dist/version.txt`，不改变 GTK4、Libadwaita、Fcitx5 或中文 locale 逻辑。
- workflow 使用 `SOFTWARE_KEY=mission-center` 接入统一 `software_versions.json`。

### 2026-11-28：按标准模板整理并精简通用自检

- **核实来源**：确认 `pkgforge-dev` 组织无独立仓库（Issue `#330` 因上游源码仓自行采用 `quick-sharun` 而关闭）；沿用 Arch 官方 `extra/mission-center` 与 `fcitx5-gtk`，同时核对 CI Job `140872258325` 日志确认 `quick-sharun` 仍未生成 GTK4 `giomodule.cache`。
- **代码调整**：按 [arch-native.sh](../Templates/quick-sharun/arch-native.sh) 重写 `mission-center/build_mission-center.sh`，将 `gettext`、`patchelf`、`zsync` 收口到 `--base` 并接入公共工作区与版本入口；保留 `DEPLOY_GTK=1`、`GTK_DIR=gtk-4.0`、`DEPLOY_LOCALE=1`、`giomodule.cache` 生成及 `zh_CN.utf8` locale / `.env` 配置，移除冗余通用自检并新增 [模板差异说明](./docs/template-deviations.md)。
- **检查范围**：已完成模板逐行对照、依赖覆盖、静态差异与 Git 文件模式核对；标准化后的正式构建以 GitHub Actions `Build Mission Center` 运行结果为准。
