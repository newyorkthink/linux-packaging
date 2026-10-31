# Joplin AppImage

本目录用于把 Joplin 官方发布的 Linux x64 DEB 重新封装为 `joplin.AppImage`。既有正式包已经实际确认 Joplin 可正常启动、Adwaita 深色主题正常、IBus 中文输入正常；当前脚本保留这些兼容处理，并按仓库统一 linuxdeploy 规范重排打包链路。

## 唯一标准模板

[`build_joplin.sh`](./build_joplin.sh) 是本仓库所有 linuxdeploy 项目的唯一标准模板，完整原文和强制规则见 [`linuxdeploy_projects.md`](../linuxdeploy_projects.md)。

- 当前模板共 85 行，其中 29 行为空行、56 行为非空行，包含 9 个固定分区；脚本内生成的 AppRun 计入总行数。
- 应用名称、软件包及依赖参数、下载来源参数、路径、真实启动参数和 AppRun 专属配置按当前程序实际需要确定；除此之外，通用部分的字符、字数、注释、标点、顺序、缩进、空格、行数及空行位置必须逐字逐行一致。所有命令保持原有单行写法，不添加反斜杠续行。
- 模板没有的代码、变量、函数、检查、复制、循环、desktop 修正、wrapper 和环境设置不得自行加入；模板已有内容也不得自行删减、移动或换词。
- Qt / GTK 差异、不同来源和布局、额外运行库、输入法设置等特殊情况，必须先列明模板原文、拟用完整代码、位置、必要性、证据、行数与空行变化及影响，获得明确同意后再实施，并同步记录到对应应用的 `docs/template-deviations.md`。
- 任何通过 linuxdeploy 打包的项目一律禁止使用 Docker。特殊差异流程不得豁免；已有脚本使用 Docker 也不能作为继续使用的理由。

本目录的实际环境为 GitHub Actions Ubuntu 22.04 runner，直接运行构建脚本，不经过 Docker。已确认有效的 Joplin AppRun、GTK3、IBus/GIO、Adwaita 深色主题和 NSS 处理继续保留，不因其他应用需要调整而改写这个标准模板。

## 依赖列表和 AppRun 的适用范围

依赖安装行中的软件包清单是 Joplin 自身的构建和运行依赖，不是所有 linuxdeploy 项目的固定清单。其他程序按自身实际需要确定包名和数量，并核对公共基础包的覆盖范围；调用位置、公共入口和单行写法保持模板一致。

AppRun 的真实启动入口、参数、搜索路径和 Qt / GTK 等框架专属配置，以及语言、输入法、主题等兼容项，也由各程序的实际布局和已验证需求决定。通用脚本结构、注释和三个 `/usr` 基础搜索目录仍遵循模板；增删专属配置行时说明原因、具体代码和行数变化，按规范获准并记录，不照搬 Joplin 的 GTK/GIO、Adwaita 或 NO_AT_BRIDGE 配置。

85 行、29 行空行是 Joplin 本身的完整基线，不要求其他程序为了凑字数和行数保留无关依赖或 AppRun 配置。Joplin 已验证的依赖和 AppRun 保持原样。

## 构建来源

- 构建脚本单行调用 `common/github/install_and_extract_latest_stable_release_deb.sh`，由它复用 `common/github/download_latest_stable_release_asset.sh` 读取 Joplin 官方 Releases，忽略 draft / prerelease，选择版本号最高且唯一提供 `Joplin-<版本>.deb` 的 Linux x64 正式版本，校验 GitHub Release 的 SHA-256 digest 后，将同一份 DEB 安装到构建环境并解包到 AppDir，全部成功后返回版本号。
- 保留官方 `/opt/Joplin`、`resources/app.asar`、Node 原生模块、desktop 文件和图标，不修改 Joplin 官方 `app.asar`。
- GitHub Releases API 在 Actions 中优先使用现有 GitHub 认证，避免匿名 API 请求触发限流或 403。

## 构建环境与依赖

- GitHub Actions 构建环境固定为 `ubuntu-22.04`，由 Ubuntu runner 直接执行 `build_joplin.sh`，不使用 Docker、Dockerfile、Compose 或额外容器包装。
- 标准 `source` / `AppDir` / `dist` / `source/tools` 工作区和 x86_64 检查由 `common/linuxdeploy/prepare_build_workspace.sh` 统一处理；构建依赖通过 `common/apt/install_packages.sh` 安装，官方 DEB 的下载、校验、安装和解包统一由组合入口负责。
- 同一份官方 DEB 既安装到当前 Ubuntu runner 供 linuxdeploy 解析依赖，也按上游布局解包到 AppDir。
- 安装 GTK3、GLib/GIO、GDK Pixbuf、Pango、IBus、NSS、X11/Electron 等运行依赖。
- `ibus-gtk3` 和 `libibus-1.0-5` 负责把 GTK3 的 IBus 输入模块及运行库带入 AppDir；已解包成品可见 `im-ibus.so`、`libibus-1.0.so.5` 等文件，因此运行日志中的 `IBUS-WARNING` 不是构建环境未安装 IBus。不在 AppRun 中强制写死 `GTK_IM_MODULE`、`QT_IM_MODULE` 或 `XMODIFIERS`，输入法选择继续由宿主机会话管理。
- `adwaita-icon-theme`、`adwaita-icon-theme-full`、`gnome-themes-extra-data` 通过 `common/apt/download_and_extract_packages.sh` 下载并按原始 DEB 布局解包进 AppDir，保证 Adwaita 图标和 GTK 主题资源完整。

## linuxdeploy 规范流程

- 单行 `source common/linuxdeploy/prepare_linuxdeploy_tools.sh`，传入工具目录、gtk 插件、中间 AppImage 和 runtime 四个参数；下载完成后在当前脚本中加载通用环境，不再单独调用 `configure_environment.sh`。
- 动态取得 linuxdeploy、官方 GTK 插件、appimagetool 和 Type 2 runtime；GTK 插件上游未提供 Release digest，因此从官方仓库默认分支解析当前文件并核对 Git blob SHA。公共准备脚本随后仅在上游仍缺少时补入已验证的 GIO modules 复制逻辑，并输出最终文件的本地 SHA-256。
- 单行调用 `common/linuxdeploy/initialize_appdir.sh`，由公共入口在空目录执行原始普通 linuxdeploy 命令。
- 初始化后才下载官方 DEB；应用主体保持在 `AppDir/opt/Joplin`，不再创建人工 `AppDir/usr/bin/joplin` 二次转发入口。
- 第二次 linuxdeploy 前写入完整根 `AppDir/AppRun`，直接执行 `opt/Joplin/joplin`。根 AppRun 固定把 `usr/bin`、`usr/lib`、`usr/share` 分别加入 `PATH`、`LD_LIBRARY_PATH`、`XDG_DATA_DIRS`，并只把 `/opt/Joplin` 加入程序和库搜索路径。
- 第二次执行 `export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin gtk --output appimage`；linuxdeploy 检测到 GTK hook 后生成顶层启动入口，并把实际 Joplin 启动逻辑保留到 `AppRun.wrapped`。
- 最终 AppImage 已经完成解包和实际运行核对，构建脚本直接保留确认后的准确 AppRun 路径，不再调用公共路径整理脚本。
- `AppRun.wrapped` 保留 AppImage 内部的 `PATH`、`LD_LIBRARY_PATH`、`XDG_DATA_DIRS`、`GSETTINGS_SCHEMA_DIR` 和 `GIO_MODULE_DIR`，避免运行时错误混用宿主机 GTK/GLib/GIO 模块。
- 固定 `GTK_THEME=Adwaita-dark`，保证 Joplin 使用已打包的 Adwaita 深色主题。
- 使用动态取得的官方 `linuxdeploy-plugin-gtk` 部署 GTK schemas、GIO modules、GTK input modules、GDK Pixbuf loaders、Pango 等 GTK 运行资源。

## NSS

Electron/NSS 会通过 `dlopen` 动态加载 NSS 模块。为避免 AppImage 内旧版 NSS 与宿主机新版 NSS 混用，构建时调用 `common/linuxdeploy/copy_nss_runtime.sh`，把 Ubuntu 22.04 同一套 `libnss3` 核心库和 NSS modules 一起放入 `AppDir/usr/lib`；公共 helper 内保持原先已经实际运行确认的文件清单。

这部分用于避免类似以下版本冲突：

```text
libnssutil3.so: version `NSSUTIL_xxx' not found
```

## 最终封装

`linuxdeploy` 负责整理 AppDir、部署 GTK/运行库依赖并完成 hook 与 AppRun 包装；它生成的 AppImage 只作为中间产物：

```bash
# 再次运行 linuxdeploy，部署运行资源并生成中间 AppImage。
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin gtk --output appimage
```

项目脚本最终单行调用 `common/linuxdeploy/package_appimage.sh`；公共入口内部仍由官方 `appimagetool` 使用指定的 Type-2 runtime 封装，并统一负责最终资产非空检查、可执行权限、SHA-256 输出，以及在封装成功后写入版本元数据：

```bash
# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
```

不得把 linuxdeploy 的中间 AppImage 发布为正式资产，也不得因为 appimagetool、runtime、GitHub 或 CDN 的临时网络错误增加自动 fallback 到其他封装方式；下载失败应由当前构建直接失败，后续正常重试。

## 已知非致命日志

在 Joplin GUI、深色主题和中文输入均正常时，以下日志属于当前 Electron/Chromium/IBus 或宿主字体缓存相关提示，不作为 AppImage 打包失败处理：

```text
[DEP0040] DeprecationWarning: The `punycode` module is deprecated
Fontconfig warning: cache files were generated by a newer version
IBUS-WARNING: joplin has no capability of surrounding-text feature
ERROR:ui/gfx/x/atom_cache.cc ... Add application/vnd.portal.* to kAtomsToCache
```

其中 `has no capability of surrounding-text feature` 表示当前应用输入上下文没有向 IBus 提供光标附近文本能力，不表示 IBus 模块或运行库缺失。当前实测普通中文输入正常；依赖 surrounding-text 删除、替换光标前后字符的特殊输入法功能不在本次验证范围内。不得为了消除该提示额外打包 `ibus-daemon`，也不得强制覆盖宿主会话的输入法环境变量。

以下类型则属于实际依赖混用错误，不应忽略：

```text
libdconfsettings.so: undefined symbol: ...
libnssutil3.so: version `NSSUTIL_...' not found
```

## 稳定基线

- 不修改 Joplin 官方 `app.asar`。
- 不主动删除 Joplin 官方 DEB 中的文件，包括官方提供的 1024×1024 图标；打包工具的图标尺寸限制不得作为删减上游包内容的理由。
- 不为消除非致命 warning 强行增加输入法环境变量或替换已经正常工作的 GTK/GLib/NSS 依赖。
- 不增加 Xvfb / GUI smoke test、额外 ELF 遍历或仅用于“让 Actions 变绿”的测试代码。
- 两次 linuxdeploy 都保留 `--output appimage`，但不把它生成的中间 AppImage 作为最终封装结果。
- 已确认正常的 AppRun、GTK/IBus、主题、GIO 和 NSS 处理方式视为稳定基线，后续仅在出现新的实际故障并确认根因后再修改。
- 正式构建由 `.github/workflows/build.yml` 中独立的 `Build Joplin` Job 完成，发布文件名固定为 `joplin.AppImage`。

## 版本元数据接入（2026-09-16）

- 构建脚本复用当前 Joplin Releases 解析得到的正式版 `VERSION`，交给公共最终封装入口在 AppImage 成功生成后写入 `dist/version.txt`。
- 自定义 Joplin Job 上传 `software-version-joplin` artifact，并在成功构建后增量写入 `latest/software_versions.json`。
- 本次不改动现有 Ubuntu 22.04、GTK/IBus、NSS、AppRun 或 appimagetool 稳定基线。

## 实际运行验证（2026-09-20）

- AppImage 可正常启动，Joplin 主界面、Adwaita 深色主题、笔记编辑和普通 IBus 中文输入均正常。
- 解包后确认 GTK immodules、`im-ibus.so`、IBus 运行库和 AppRun 中的 AppDir `GIO_MODULE_DIR` 路径均已保留。
- 终端仍会重复输出 `has no capability of surrounding-text feature`；结合成品文件和中文输入结果，确认它不是 IBus 缺包或 AppImage 启动失败。
- 本次证据来自用户实际运行；没有把仅靠静态检查的结论写成 GUI 验证结果。

## 变更记录

### 2026-10-31：确认唯一标准模板并同步公共入口说明

当前标准脚本来自提交 `86ad3f255081b171d46a272b5a46f70318dbff86`，共 85 行、29 行空行。工作区、依赖安装、工具准备、AppDir 初始化、应用准备、桌面资源和运行库、AppRun、核心打包及最终产物整理均按固定位置排列，通用注释和空行属于模板正文。

工具准备已合并为单行 source 调用，下载成功后立即在当前脚本加载构建环境；官方 DEB 已改为单行调用下载、校验、安装和解包组合入口，相关步骤不再分散维护。Joplin 保留官方 desktop，不额外改写 Exec 或 Icon；已验证的根 AppRun、主题、IBus/GIO、NSS 和第二次 linuxdeploy 命令保持原样。

本次更新 README、linuxdeploy 规范、对应 AGENTS 规则和文档索引，明确所有 linuxdeploy 项目必须逐字逐行遵循 Joplin，禁止使用 Docker，特殊差异必须说明完整代码、依据、位置、行数与空行变化，并在获准后记录。本次未修改应用构建脚本或 workflow，既有实机确认范围保持不变。

### 2026-09-21：复用 linuxdeploy 公共构建入口

Joplin 构建脚本现与仓库当前 linuxdeploy 规范对齐：标准工作区、x86_64 检查、APT 安装、GitHub 正式 Release 解析 + 下载、主题包下载 + 解包、NSS 运行库复制、linuxdeploy 通用环境和最终 appimagetool 封装分别交给对应 `common/` 入口。应用脚本只保留 Joplin 自身依赖、desktop 调整、已验证 AppRun、GTK3 选择和第二次 linuxdeploy。

同时删除应用脚本内的 `die` / `uname -m`、Release `mapfile` 元数据拆分、直接 `apt-get download` + DEB 遍历、重复 NSS 文件清单、`desktop-file-validate`、固定 AppRun 的内联 `bash -n`、最终 AppImage 重复检查和手写 `version.txt`。后续取消对官方 1024×1024 Joplin 图标的主动删除，保持上游 DEB 内容完整。本次没有改动已经实际运行确认的 Joplin 根 AppRun、GTK3、IBus/GIO、Adwaita 深色主题、NSS 文件集合和第二次 `export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin gtk --output appimage` 命令；`.github/workflows/build.yml` 的 Ubuntu 22.04 独立 Job 也保持不变。

### 2026-09-20：复用公共空 AppDir 初始化入口

第一次普通 linuxdeploy 已集中到 `common/linuxdeploy/initialize_appdir.sh`；本项目构建脚本只保留一行调用。Joplin 专用 GTK、GIO、AppRun 和第二次 linuxdeploy 逻辑均未改变。

### 2026-09-20：固化最终 AppRun

实际成品已经确认顶层 GTK hook、`AppRun.wrapped`、应用入口和各路径型环境变量正确，Joplin 可正常启动、使用深色主题并进行普通 IBus 中文输入。构建脚本现直接写入已验证的最终 AppRun，删除只供首次目录尚未确认时使用的 `normalize_apprun_paths.sh` 调用；以后以这份 AppRun 为稳定基线。

### 2026-09-20：复用公共 GitHub API 与 Release 解析入口

原脚本内重复维护 GitHub 认证头、API 下载和 Python Release 筛选。现已把 `GITHUB_TOKEN`、`GH_TOKEN`、checkout extraheader 的认证优先级与请求参数提取到 `common/github/github_api.sh`，并把“正式 semver Release + `{version}` 资产名模板 + GitHub SHA-256 digest”提取到 `common/github/resolve_latest_stable_release_asset.sh`。Joplin 脚本只保留官方仓库名和 `Joplin-{version}.deb` 资产模板，不再需要内嵌 Python；linuxdeploy 工具准备也复用同一 GitHub API 入口。

### 2026-09-20：恢复 GTK 插件的 GIO modules 部署

官方 `linuxdeploy-plugin-gtk.sh` 长期没有复制 `gio-2.0` 的动态模块，而 Joplin 已验证需要把同一构建环境中的 GIO modules 放入 AppDir，避免运行时混用宿主模块。公共工具准备脚本现在先下载并核对官方当前文件的 Git blob SHA，再在确认上游仍缺少 `gio_moduledir` 逻辑时加入最小 GIO 修复；上游将来合入同类修复后会自动跳过，避免重复插入。

现有修正版同时包含 WebKit2GTK 和 JavaScriptCore 3/4 收集逻辑；这些不是所有 GTK 应用的通用依赖，其中 JavaScriptCore 两个 pkg-config 查询还会在相应开发包不存在时中断插件，因此没有并入公共修复。

### 2026-09-20：按空 AppDir 两阶段流程规范 Joplin 打包

旧脚本先解包 Joplin，再人工创建 `usr/bin/joplin`，而且第二次 GTK linuxdeploy 缺少 `--output appimage`，与当前仓库强制流程冲突。脚本现改为先初始化空 AppDir，再安装并解包同一份官方 DEB；根 AppRun 直接执行 `/opt/Joplin/joplin`，第二次 linuxdeploy 同时启用 GTK 插件与 AppImage 输出阶段，最后仍由官方 appimagetool 和明确的 Type 2 runtime 生成正式资产。

本次保留 Ubuntu 22.04、Adwaita 深色主题、IBus/GIO 与同版本 NSS 运行库基线；打包工具改由公共入口动态取得，并删除仓库内固定的 GTK 插件副本。已完成 Shell 语法、静态规则和完整 diff 检查；随后提供的实际运行结果确认 AppImage、深色主题和普通 IBus 中文输入正常，终端 `surrounding-text` 提示按上文边界记录为非致命日志。
