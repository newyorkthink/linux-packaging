# linuxdeploy 项目清单与打包规范

本文件是本仓库所有 linuxdeploy 打包项目的强制规范。[`joplin/build_joplin.sh`](./joplin/build_joplin.sh) 是唯一标准模板，不得另选其他应用、上游脚本或自行编写的变体作为模板。

## 强制规则：禁止使用 Docker

**任何通过 linuxdeploy 打包的项目，一律禁止使用 Docker。** 构建脚本、workflow、公共入口和应用专用脚本均不得直接或间接调用 Docker，不得通过 Dockerfile、Compose、容器 Action 或额外容器包装执行这条打包链路。

实际打包必须直接在 GitHub Actions 的 Ubuntu runner 中执行。不得以环境隔离、Qt / GTK 版本、依赖扫描、安装包布局或旧脚本已经使用为由加入 Docker。特殊差异说明和审批也不能豁免这条禁令。

## 唯一标准模板：逐字逐行遵循 Joplin

**凡实际调用 linuxdeploy 的项目，无论技术栈、安装包格式或程序目录布局，都必须以 Joplin 脚本为唯一模板，逐字逐句、逐行逐处对齐。** 本要求同时适用于聊天拟稿、修改方案和实际文件。

只允许在模板原有位置替换当前应用的软件名称、软件包及依赖参数、下载来源参数、文件路径和真实启动参数。参数以外的全部字符、字数、标点、引号、命令写法、变量顺序、分区标题、通用注释、缩进、空格、行数和空行必须完全一致；参数值长度不同不构成改写周围内容的理由。

模板没有的代码、变量、函数、检查、复制、循环、桌面入口修正、wrapper、环境变量和执行步骤，一律不得自行添加。模板已有内容也不得自行删除、移动、拆分、合并或换词。技术栈变化、需要删除不适用的 GTK 代码、增加 Qt 配置或使用其他公共入口，均须先按下节说明精确差异并获得明确同意。

命令保持模板中的单行写法，禁止添加反斜杠续行。模板已有的 `export ARCH=x86_64; linuxdeploy ...` 必须整行保留，不得拆分。文件使用 LF 换行，末尾保留一个换行符；行距以空行的位置和数量为准，不得用占位命令、无关注释或额外空行凑行数。

### 固定行数与位置

当前基线为 [提交 86ad3f2 中的原脚本](https://github.com/newyorkthink/linux-packaging/blob/86ad3f255081b171d46a272b5a46f70318dbff86/joplin/build_joplin.sh)。该快照用于核对已确认原文，不用于固定应用或打包工具版本。开始任务时仍须读取最新 main；模板发生变化时须先确认变更，禁止自行切换基线。

| 核对项 | 固定要求 |
| --- | --- |
| 总行数 | 85 行，包括脚本内部生成的 AppRun。 |
| 空行数 | 29 行。 |
| 非空行数 | 56 行。 |
| 空行位置 | 第 2、5、8、10、13、15、18、20、23、25、28、30、33、35、38、41、43、47、50、53、58、62、66、70、73、75、78、81、83 行。 |
| 分区标题 | 9 个，分别位于第 9、14、19、24、29、34、42、74、82 行。 |
| 注释与字数 | 通用注释逐字复制，包括标点，不作润色、缩写或同义改写。 |
| 代码与空白 | 参数以外的每个字符、缩进、空格和空行逐处一致。 |

没有获批特殊差异时，必须同时满足以上要求。已获批准的差异只能改变记录中列明的具体位置，其他行仍须与模板原文一致。

### 特殊情况必须逐项说明

特殊情况不能由 AI 自行认定后直接写入。必须先在聊天中列出以下内容，并在用户针对该清单明确同意后实施；聊天拟稿也不得先混入尚未说明的差异。

| 必须说明的内容 | 具体要求 |
| --- | --- |
| 应用与位置 | 写明文件路径、模板行号、所在分区和实际使用者。 |
| 模板原文 | 原样列出本次涉及的完整注释和命令，不用省略号替代。 |
| 拟用代码 | 完整列出准备新增、删除或替换的内容，包括相邻空行。 |
| 必要性与依据 | 说明解决的实际问题，提供包内布局、原始日志、源码或已确认运行结果；不得只写程序特殊、原脚本已有或为了兼容。 |
| 公共能力覆盖 | 说明模板、安装包和现有公共入口为什么不能直接满足需要；通用能力不得重复写在应用脚本中。 |
| 行数与字符差异 | 写明增加、删除的行数，调整后的总行数、空行数和受影响的字符；未涉及部分保持逐字一致。 |
| 影响与验证 | 说明依赖、启动、资源部署、输出和验证范围，不把语法检查当作运行通过。 |
| 授权与记录 | 明确本次决定和授权范围，并在同一次修改中写入该应用的 `docs/template-deviations.md`，由应用 README 提供入口。 |

涉及固定配置时同步维护该应用的 `docs/hardcoded.md`；涉及 pkgforge-dev 专属代码时同时按 `AGENTS.md` 维护来源和采用、未采用记录。记录必须列出实际完整代码及位置，不能只写采用、保留或参考官方。

删除 GTK 专属段、设置 Qt 查询工具、增加 Qt 路径、修正 desktop / icon、复制额外运行库、创建查询工具 wrapper、增加输入法或显示选项、调用 AppRun 路径整理入口，都属于需要说明的差异，不因常见或已有而自动允许。不得为了模板一致而擅自删除已经验证有效的处理；需要保留时应明确记录并取得本次授权。

Docker 不属于可批准的特殊情况。`--executable`、手工创建 hook 或 AppRun.wrapped、发布中间 AppImage 等现有禁令也不得通过差异说明绕过。

### Joplin 标准原文

以下代码与当前基线脚本逐字一致，共 85 行；这是唯一完整模板。代码中的应用参数属于 Joplin，其他应用只能按前述参数替换和差异审批规则处理，不得机械复制不适用的依赖或兼容配置。

```bash
#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

###### 准备构建目录 ######

# 设置构建路径，并清理、重建当前应用的 source、AppDir 和 dist 目录。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" joplin

###### 准备构建环境 ######

# 安装构建工具和应用所需的依赖包。
"$SCRIPT_DIR/../common/apt/install_packages.sh" dpkg-dev pkgconf libglib2.0-bin libglib2.0-dev libgirepository1.0-dev libgtk-3-bin libgtk-3-dev libgdk-pixbuf2.0-bin libgdk-pixbuf-2.0-dev librsvg2-dev librsvg2-common libpango1.0-dev ibus-gtk3 libibus-1.0-5 libasound2 libatk1.0-0 libatk-bridge2.0-0 libatspi2.0-0 libcairo2 libcups2 libdbus-1-3 libdrm2 libgbm1 libgdk-pixbuf-2.0-0 libglib2.0-0 libgtk-3-0 libnotify4 libnspr4 libnss3 libpango-1.0-0 libsecret-1-0 libuuid1 libappindicator3-1 libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 libxi6 libxinerama1 libxkbcommon0 libxrandr2 libxrender1 libxshmfence1 libxss1 libxtst6 xdg-utils shared-mime-info hicolor-icon-theme

###### 下载打包工具 ######

# 下载并校验打包工具及所需插件，随后加载构建环境配置。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" gtk "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"

###### 初始化 AppDir ######

# 首次运行 linuxdeploy，创建 AppDir 的基础目录。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

###### 下载并准备应用 ######

# 下载并校验官方安装包，将其安装到构建环境并解包到 AppDir，成功后返回版本号。
VERSION="$("$SCRIPT_DIR/../common/github/install_and_extract_latest_stable_release_deb.sh" "laurent22/joplin" 'Joplin-{version}.deb' "$SOURCE_DIR/joplin.deb" "$APPDIR")"

###### 准备桌面资源和运行库 ######

# 下载并解包应用所需的图标与主题资源。
"$SCRIPT_DIR/../common/apt/download_and_extract_packages.sh" "$APPDIR" adwaita-icon-theme adwaita-icon-theme-full gnome-themes-extra-data

# 复制构建环境中的 NSS 核心库及其配套动态加载模块。
"$SCRIPT_DIR/../common/linuxdeploy/copy_nss_runtime.sh" "$APPDIR/usr/lib"

###### 准备 AppRun ######

# 在 AppDir 根目录创建完整的 AppRun 启动脚本。
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
HERE="$(dirname "$(readlink -f "${0}")")"

# 设置程序、运行库和共享数据的搜索路径。
export PATH="$HERE/opt/Joplin:$HERE/usr/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$HERE/opt/Joplin:$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$HERE/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

# GTK 运行环境：指定 GSettings schema 和 GIO 动态模块的目录。
export GSETTINGS_SCHEMA_DIR="$HERE/usr/share/glib-2.0/schemas${GSETTINGS_SCHEMA_DIR:+:$GSETTINGS_SCHEMA_DIR}"
export GIO_MODULE_DIR="$HERE/usr/lib/x86_64-linux-gnu/gio/modules"

# 设置深色主题和辅助功能兼容选项。
export GTK_THEME=Adwaita-dark
export NO_AT_BRIDGE=1

# 启动包内程序，并保留传入的命令行参数。
exec "$HERE/opt/Joplin/joplin" "$@"
APPRUN

# 为启动脚本添加执行权限。
chmod +x "$APPDIR/AppRun"

###### 核心打包 ######

# 指定 GTK 主版本。
export DEPLOY_GTK_VERSION=3

# 再次运行 linuxdeploy，部署运行资源并生成中间 AppImage。
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin gtk --output appimage

###### 整理产物 ######

# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
```

## 当前项目清单

| 项目 | 构建脚本 | 使用方式 |
| --- | --- | --- |
| GoldenDict | `goldendict/build_goldendict.sh` | Ubuntu 24.04 官方 DEB，linuxdeploy + Qt / GStreamer 插件 |
| Alacritty | `alacritty/build_alacritty_linuxdeploy.sh` | linuxdeploy |
| MediaInfo | `mediainfo/build_mediainfo_linuxdeploy.sh` | linuxdeploy |
| PeaZip | `peazip/build_peazip.sh` | linuxdeploy + Qt 插件 |
| Joplin | `joplin/build_joplin.sh` | linuxdeploy + GTK 插件 |
| Binance | `binance/build_binance.sh` | linuxdeploy + GTK 插件 |
| XnView MP | `xnviewmp/build_xnviewmp.sh` | linuxdeploy + Qt 插件 |
| Poppler Utils | `poppler-utils/build_poppler-utils.sh` | linuxdeploy |
| Remmina | `remmina/build_remmina.sh` | linuxdeploy + GTK / GStreamer 插件 |
| dconf Editor | `dconf-editor/build_dconf-editor.sh` | linuxdeploy |
| Rainlendar2 | `rainlendar2/build_rainlendar2.sh` | linuxdeploy + GTK 插件 |
| RealVNC RVNC Connect | `realvnc-rvnc-connect/build_realvnc-rvnc-connect.sh` | linuxdeploy + GTK 插件 |
| 腾讯会议 | `wemeet/build_wemeet.sh` | linuxdeploy + Qt 插件 |

仅在 README、注释或说明文字中出现 linuxdeploy，但构建脚本没有实际调用的项目，不计入本清单。清单只表示实际使用这条路线，不表示所有既有脚本已经完成模板对齐；本次规范更新不授权批量修改其他应用。

## 既有工具行为与产物证据

本规范基于以下证据整理：

- 当前仓库全部 linuxdeploy 构建脚本；
- 用户本地已经实际使用的两阶段命令；
- 用户提供的 PeaZip 与 File Roller AppImage 解包结果；
- linuxdeploy、linuxdeploy-plugin-qt、linuxdeploy-plugin-gtk 和 Type 2 runtime 的实际行为。

历史样本解包后都确认存在顶层 `AppRun`、`AppRun.wrapped` 和 `apprun-hooks/`：当时的 PeaZip 顶层 AppRun 自动加载 `linuxdeploy-plugin-qt-hook.sh`，File Roller 顶层 AppRun 自动加载 `linuxdeploy-plugin-gtk.sh`，随后执行 `AppRun.wrapped`。这些样本证明第二次 linuxdeploy 必须保留 `--output appimage`，但不证明当前每个插件版本都会生成 hook；例如当前官方 Qt 插件会跳过 Qt6 hook。最终结构必须以当前官方工具实际产物为准，禁止为了复刻历史样本手工补 hook。

## 模板与技术说明的边界

处理任何 linuxdeploy 项目前先完整阅读 Joplin 原脚本、本文、当前应用 README 及对应 workflow。其他应用只能用于核实已经出现的技术差异，不能作为第二套模板；其他技术栈、下载格式或旧实现中的额外代码，也不能直接复制进拟稿。

## 标准流程的技术说明

以下内容解释公共入口、打包工具和已经核实的行为，不是另一份模板，也不授权从中挑选代码拼接脚本。涉及与 Joplin 原文不同的调用、参数以外的修改或额外步骤时，必须先执行前述特殊差异流程。

### 公共入口与职责

应用脚本复用下列入口，不重复实现下载、校验、安装、解包或初始化逻辑。入口支持某项能力不等于应用获准额外添加调用；默认调用位置和写法以唯一模板为准。

| 公共入口 | 职责与参数 |
| --- | --- |
| `common/linuxdeploy/prepare_build_workspace.sh` | 按脚本目录和资产基础名设置工作路径、检查 x86_64，并清理、重建当前应用的标准工作目录。 |
| `common/apt/install_packages.sh` | 安装基础工具及调用方提供的精确依赖；后续本地 DEB 安装使用 `--no-update`，不重复更新索引。 |
| `common/linuxdeploy/prepare_linuxdeploy_tools.sh` | 模板使用 `source` 并传入工具目录、插件、中间 AppImage、runtime 四个参数，下载和校验工具后在当前脚本加载通用环境。 |
| `common/linuxdeploy/configure_environment.sh` | 设置 ARCH、工具 PATH、中间输出和 runtime 等通用环境，由工具准备入口加载；模板不再单独调用。 |
| `common/linuxdeploy/initialize_appdir.sh` | 接收 AppDir 和已下载的 linuxdeploy 路径，在空目录运行第一次普通 linuxdeploy。 |
| `common/github/install_and_extract_latest_stable_release_deb.sh` | 默认接收仓库、资产模板、DEB 保存路径和 AppDir，统一下载、校验、安装和解包；所有步骤成功后只向 stdout 返回版本。GitHub 模式可追加 DEB 包名和架构。 |
| 同一 DEB 入口的 `--checksum` 模式 | 接收 HTTPS 校验清单、完整资产名正则、DEB 保存路径和 AppDir，复用官网清单下载入口；后续安装和解包保持共用。 |
| `common/apt/download_and_extract_packages.sh` | 只下载调用方指定的图标、主题等 APT 包，并按各自原始布局解包到 AppDir。 |
| `common/linuxdeploy/copy_nss_runtime.sh` | 复制同一构建环境的 NSS 核心库及其配套动态加载模块。 |
| `common/linuxdeploy/package_appimage.sh` | 接收 appimagetool、AppDir、正式输出文件、runtime 和软件版本，完成正式封装、SHA-256 输出及成功后的 version.txt 保存。 |
| `common/download/download_file.sh` | 统一 HTTPS 下载、重试、超时、临时文件及可选 SHA-256 校验。 |
| `common/download/download_latest_checksum_asset.sh` | 从官方 SHA-256 清单选择并校验最新匹配资产，只返回实际版本；DEB 的安装和解包由组合入口继续处理。 |
| `common/github/download_latest_stable_release_asset.sh` | 按正式 semver、资产名模板及 GitHub digest 下载并校验，支持可选 DEB 包名和架构核对。 |
| `common/download/download_json_deb_asset.sh` | 按调用方参数解析官方 JSON 中的版本和 DEB 地址，并校验来源、资产名及 DEB 元数据。 |
| `common/archive/extract_archive.sh` | 统一解包 DEB 和 tar 系列归档；特殊来源使用时也不在应用脚本重复格式判断。 |
| `common/linuxdeploy/normalize_apprun_paths.sh` | 仅供已说明并获批的特殊目录情况整理现有路径型 export，不属于 Joplin 默认模板步骤。 |

工具和应用版本继续通过官方动态入口取得，不固定旧标签、旧提交或旧资产。GTK 插件从官方默认分支动态取得并校验 Git blob SHA；公共入口只在上游仍缺少 GIO modules 复制时补入既有最小修复，上游提供等价能力后跳过。

`source` 的环境设置在当前构建脚本中生效，因此模板不再保留第二条独立的环境配置调用。DEB 组合入口负责使用同一份已校验安装包完成安装和解包，应用脚本不再另设下载文件变量并重复这三步。

新增项目或当前修改触及对应代码时，项目脚本对每一次下载、安装、解包或空 AppDir 初始化只能保留一条公共脚本调用命令，并把当前应用的 URL、完整资产名正则、输出路径、版本文件、依赖名称、归档文件或 AppDir 路径作为参数传入。禁止在项目脚本中自行使用 `curl`、`wget`、Release / API 查询、校验清单解析、最新版选择、摘要拼装、`apt-get update`、`apt-get install`、`dpkg-deb -x`、`tar -x`、root / sudo 判断，或重复第一次 linuxdeploy 命令。需要修复通用行为时只修改 `common/` 公共实现；下载后的应用专用文件定位和 AppDir 布局调整仍由项目脚本处理。本规则不授权批量改写本次任务未触及的稳定项目。

GIO dynamic modules 与 GI typelibs、GTK input modules 不是同一类资源。官方插件已经处理 typelibs 和 GTK immodules，但这不能替代 `gio-2.0` modules。新增、迁移或重做 GTK linuxdeploy 项目时不得直接下载未修补的官方 `linuxdeploy-plugin-gtk.sh`；必须给公共工具准备脚本传入 `gtk`，并在第二次 linuxdeploy 后确认最终 AppDir 中存在构建环境实际 `giomoduledir` 对应的模块目录。项目若明确设置 `GIO_MODULE_DIR`，必须指向该 AppDir 内的实际目录，不能指向宿主机。

GitHub Release 版本由资产名模板和 digest 绑定，不强制要求 DEB 内部 Version 与 Release tag 完全相同。公共下载、安装及解析入口内部统一处理认证、重试、root / sudo 和非交互安装，调用方不重复实现。公共脚本只能依赖本仓库自身及软件官方来源，不建立外部代码库运行时依赖。

### linuxdeploy 命令形式固定

以下只列出工具参数的含义，不构成可替换 Joplin 的第二套模板。

| 技术栈 | 输入插件参数 |
| --- | --- |
| 普通程序 | 不设置 `--plugin`。 |
| GTK | `--plugin gtk`。 |
| Qt | `--plugin qt`。 |

所有类型都保留 `--appdir AppDir` 和 `--output appimage`。改变技术栈和对应代码必须逐项说明相对模板的差异；`--desktop-file`、`--icon-file` 和精确的 `-l <库路径>` 也必须先说明必要性、实际完整命令及行数影响并获得本次授权。禁止追加 `--executable`。

### 第一步：在空目录运行普通 linuxdeploy，只创建 AppDir 基础目录

应用文件进入 AppDir 之前，项目构建脚本只调用一次公共入口：

```bash
# 首次运行 linuxdeploy，创建 AppDir 的基础目录。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"
```

公共入口内部逐字保留已经验证的 `export ARCH=x86_64; linuxdeploy --appdir AppDir --output appimage`。项目脚本不得复制这段实现，只保留上面一行调用；应用各自的 Qt、GTK、QMAKE、NO_STRIP 等环境仍按项目需要在调用前设置。

这一步只用于让 linuxdeploy 创建 AppDir 目录结构，不应提前放入应用、desktop、icon、AppRun 或自制入口。当前 linuxdeploy 在创建目录后，会因为空 AppDir 尚无 desktop 而在 `--output appimage` 阶段返回 1；公共入口直接兼容该结果，不添加其他检查。

第一次命令不会产生正式资产，也不把它的输出放入发布目录。

### 第二步：下载应用，同时安装到构建环境并解压到 AppDir

第一次目录初始化完成后，再取得应用文件。不得只安装到构建环境而不解压 AppDir，也不得只解压 AppDir 却遗漏构建环境中用于依赖解析的对应软件包和依赖。

#### Debian / Ubuntu 软件源中的应用

对应下载、安装和解包必须调用已有公共入口；公共实现不支持当前来源时，先明确说明并扩展公共能力，不得在应用脚本中直接加入 apt 下载、安装或解包命令。来源变化及其相对 Joplin 的完整差异必须先说明并获准。

#### 网上直接下载的 DEB

由 `common/github/install_and_extract_latest_stable_release_deb.sh` 统一下载、校验、安装并解包同一份 DEB。调用方只保留模板中的一行 VERSION 赋值；官网清单来源使用该入口的 `--checksum` 参数，不再拆成下载、安装、解包三条调用，也不得混用不同版本。

#### tar、压缩包或 GitHub Release

通过 `common/archive/extract_archive.sh` 按上游真实目录结构解压到 AppDir：上游在 `/opt/<应用>` 就保持 `AppDir/opt/<应用>`，在 `/usr/bin`、`/usr/lib`、`/usr/share` 就保持对应 AppDir 路径。构建环境同时安装该应用明确需要的运行依赖；不得为了填充空的 `AppDir/usr/bin` 而复制主程序、创建 wrapper 或使用 `--executable`。

### 第三步：写入完整根 AppDir/AppRun

所有 linuxdeploy 项目的自定义启动逻辑都必须直接写入根 `AppDir/AppRun`。禁止把启动逻辑写入新建的 `AppDir/usr/bin/<程序名>`，再让根 AppRun 二次转发。

完整 AppRun 只从唯一模板复制，以下说明各变量的用途，不另提供一份缩写模板。

| 变量 | 必须保留的基础目录 |
| --- | --- |
| `PATH` | `$HERE/usr/bin`，用于查找程序。 |
| `LD_LIBRARY_PATH` | `$HERE/usr/lib`，用于查找运行库。 |
| `XDG_DATA_DIRS` | `$HERE/usr/share`，用于共享数据、desktop、locale 和 schemas。 |

应用位于 `/opt` 时，只在模板原位置替换为当前程序和运行库的真实路径，不能删掉三个 `/usr` 基础目录。超出参数值替换的新增、删除和其他环境设置均须按特殊差异流程处理。

Qt 应用再按最终 AppDir 的真实内容加入 `usr/plugins`、`usr/qml`、`usr/translations` 及对应的上游 `/opt` 目录；GTK hook 会处理 GTK 专用目录，但不能因此删除上述三个 `/usr` 基础路径。各变量只加入与自身用途对应的目录，不要求每行目录数量相同。

`AppDir/usr/bin` 可以为空；只要上游没有真实入口，就不得为了填满目录制造 `usr/bin/<程序名>`。完整根 AppRun 应直接执行上游真实主程序。

### 第四步：按技术栈执行第二次 linuxdeploy

> [!IMPORTANT]
> **禁止项目脚本、workflow、公共 helper 或 AI 手工创建、复制、下载、修改或注入任何 linuxdeploy hook。禁止空 hook、`true` hook、兼容 hook和占位 hook；当前官方插件没有生成 hook 时，禁止为了得到 `AppRun.wrapped` 无中生有补 hook，也禁止把缺少 `AppRun.wrapped` 当作构建失败。完整根 `AppDir/AppRun` 在无 hook 时就是最终顶层入口。**

第二次 linuxdeploy 的原始写法见唯一模板，不再提供另一份可自行复制的脚本。框架差异按下表核实后，仍须逐项说明并获准。

| 项目 | 核实要求 |
| --- | --- |
| GTK 主版本 | 模板为 `DEPLOY_GTK_VERSION=3`；GTK 2 / 4 必须有主程序实际版本依据，不能自行换值。 |
| Qt 查询工具 | 大写 `QMAKE` 指向与主程序一致的真实 qmake 命令或完整路径；Qt 6 使用 qmake6，Qt 5 使用 qmake。必须核实当前环境的实际工具路径。 |
| Qt 资源 | 运行库、qmake、plugins、输入上下文和 QML 必须保持同一主版本。 |
| 其他输入插件 | 仅在真实依赖及普通 ELF 收集不足的证据明确后说明，不预防性添加。 |

所有 Qt 项目禁止设置 `EXTRA_QT_MODULES` 手工指定模块（包括 `core`、`gui`）。Qt 插件必须从 AppDir 中实际部署的 Qt 库自动识别模块；上游 Qt 库仅位于 `/opt` 导致无法识别时，只能按当前应用实际路径以精确的 `-l` 收集必要 Qt 库，并核对插件生成目录及 Qt 运行库兼容性，不能通过手工指定模块绕过扫描失败。

动态加载库确实无法自动发现时，只能逐个使用 `-l` 精确补入。用户已经验证的 GTK NSS 命令原样保留：

```bash
# 为 GTK 应用精确补入无法自动发现的 NSS 运行库
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin gtk --output appimage -l /usr/lib/x86_64-linux-gnu/libnss3.so -l /usr/lib/x86_64-linux-gnu/libnssutil3.so  -l /usr/lib/x86_64-linux-gnu/libsmime3.so -l /usr/lib/x86_64-linux-gnu/libsoftokn3.so
```

不得把该 NSS 列表复制到不需要的项目，也不得使用目录或通配符代替精确库路径。

### 第五步：已获批的特殊目录情况才整理 AppRun 路径

Joplin 标准模板没有这一步，不得默认给所有项目添加。已有目录证据确实不足、需要路径整理时，先说明相对模板增加的完整代码和空行、原因、总行数变化及验证边界，获准并记录后才保留以下调用。既有已批准调用在成品确认前不得擅自删除：

```bash
# 根据最终 AppDir 整理 AppRun.wrapped / AppRun 中已经声明的路径型 export
"$SCRIPT_DIR/../common/linuxdeploy/normalize_apprun_paths.sh" "$APPDIR"
```

规则：

- 在用户确认最终成品没有问题前，不得因为本次构建成功、整理后的路径看起来合理或静态检查通过而提前删除这条调用。
- 首次或不确定项目只增加这一条实际调用命令；下载、解包、根 AppRun、第二次 linuxdeploy 等前置流程继续按当前应用原有逻辑执行。
- 有 `AppRun.wrapped` 时只处理 wrapped；没有 wrapped 时才处理 `AppRun`。顶层 linuxdeploy hook AppRun 不得覆盖。
- 公共脚本只处理当前 AppRun 已经声明的路径型变量；存在的 AppDir 路径保留，不存在的删除，并按变量用途补入第二次 linuxdeploy 后真实生成的标准目录。
- 不得借公共脚本建立万能 AppRun，也不得修改 `exec`、语言、主题、输入法、显示后端或其他应用专用逻辑。
- 用户确认最终成品没有问题后，以当前仓库 Release 成品的实际解包结果或用户提供的最终成品解包截图为依据，核对最终目录以及 `AppRun.wrapped`（无 wrapped 时为 `AppRun`）中的路径型 `export`。证据必须能够看清相关目录和完整 export，不能根据不完整截图补猜路径。
- 把上述证据中确认过的路径型 `export` 原样写回构建脚本生成的根 `AppDir/AppRun`；GTK、Qt 等插件项目写回的仍是第二次 linuxdeploy 前的自定义根 AppRun。官方插件实际生成 hook 时，linuxdeploy 会将它保存为 `AppRun.wrapped`；没有 hook 时它继续作为顶层 `AppRun`。不得把 linuxdeploy 生成的顶层 hook AppRun 抄进构建脚本。
- 在同次修改中删除该项目的公共整理脚本调用，并同步更新应用 README，记录证据来源、固化的 export、删除临时整理调用以及仍未验证的功能。此后该 AppRun 是稳定基线，避免每次构建重新猜测已经确定的目录。
- 路径变量具体用途见 [`docs/apprun-path-environment.md`](./docs/apprun-path-environment.md)。
- 已经稳定且本次未涉及的 linuxdeploy 项目不为统一形式批量改写；后续实际修改对应项目时再接入同一行调用。

### 第六步：按实际产物核对 AppRun 入口

只有当前官方 Qt、GTK、GStreamer 等插件自身实际生成非空 hook 时，第二次 linuxdeploy 的包装结果才是：

```text
AppRun
├── source apprun-hooks/<当前插件 hook>
└── exec AppRun.wrapped
```

- 顶层 `AppRun` 由 linuxdeploy 生成并加载 hook；
- `AppRun.wrapped` 保存第三步写入的完整根 AppRun；
- `apprun-hooks/` 保存当前插件实际生成的 hook；
- 禁止手工创建 `AppRun.wrapped`，也不得覆盖 linuxdeploy 生成的顶层 AppRun；目录尚不确定时只允许上述公共脚本在既有 `AppRun.wrapped` / `AppRun` 中整理路径型 export，已确定项目不做额外后处理。

**任何项目和任何技术栈都不得自行创建 `apprun-hooks` 目录或 hook 文件。** 当前官方插件没有生成 hook 时，不产生 `AppRun.wrapped` 是正常的实际结果，第三步写入的完整根 `AppRun` 保持为最终顶层入口；不得补 hook、不得补 `AppRun.wrapped`、不得增加强制检查要求两者存在。

### 第七步：忽略 linuxdeploy 中间输出，使用 appimagetool 最终封装

只发布 appimagetool 对同一个 AppDir 最终生成的文件。用户本地已经验证的命令必须原样保留：

```bash
# 使用本地 Type 2 runtime 对同一个 AppDir 最终封装
export ARCH=x86_64; appimagetool -n ./AppDir --runtime-file ~/Appimages/BuildAppimageTools/runtime-x86_64
```

GitHub Actions 使用构建目录中的官方 Type 2 runtime 和明确资产名：

```bash
# 使用官方 Type 2 runtime 生成正式资产
export ARCH=x86_64; appimagetool -n ./AppDir ./dist/<应用名>.AppImage --runtime-file ./source/runtime-x86_64
```

linuxdeploy 产生或尝试产生的 AppImage 都只能留在临时位置，禁止作为正式 Release 资产。`common/linuxdeploy/package_appimage.sh` 在执行原有 appimagetool 命令前调用 `common/appimage/prepare_appdir_for_appimagetool.sh`，只补齐新版工具要求的权限和根目录 PNG。直接调用 appimagetool 的项目在原命令前做同样调用。appimagetool 的参数、顺序和 AppRun 保持原样，不使用 `--no-check-permissions`。

## AppRun 变量按项目实际需要添加

### 通用基础

所有 linuxdeploy AppRun 都必须保留 `$HERE/usr/bin`、`$HERE/usr/lib`、`$HERE/usr/share`，分别加入 `PATH`、`LD_LIBRARY_PATH`、`XDG_DATA_DIRS`。应用位于 `/opt` 时按变量用途追加真实目录：程序入口所在目录加入 `PATH`，包含动态库的目录加入 `LD_LIBRARY_PATH`，包含共享数据的目录加入 `XDG_DATA_DIRS`；不能因为应用位于 `/opt` 就把同一个根目录无差别加入所有变量，也不能用 `/opt` 替代三个 `/usr` 基础目录。

`GSETTINGS_SCHEMA_DIR`、工作目录和其他变量按应用真实需要加入。每个变量只放与其用途对应的目录：不能把 `usr/bin` 塞入 `LD_LIBRARY_PATH`，也不能把 `usr/lib` 塞入 `PATH`；不同变量包含的目录数量不要求相同。

### Qt

只有 Qt 应用才加入 `QT_PLUGIN_PATH`、`QT_QPA_PLATFORM_PLUGIN_PATH`、`QML_IMPORT_PATH`、`QML2_IMPORT_PATH`、`QT_QPA_PLATFORM` 或 `QT_QPA_PLATFORMTHEME`。

`QT_AUTO_SCREEN_SCALE_FACTOR`、`QT_SCALE_FACTOR`、`QT_STYLE_OVERRIDE`、`QT_QPA_PLATFORMTHEME`、`QT_QPA_PLATFORM` 和 `QT_FONT_DPI` 会影响缩放、主题、平台后端与字体 DPI，不是 linuxdeploy 通用模板；只在上游要求、现有稳定基线、日志或真实运行反馈证明需要时加入。

### GTK

GTK plugin 自动生成的 hook 会设置 GTK 数据、schemas、typelib、immodules、pixbuf loader 和主题相关变量。自定义 AppRun 中不要无依据重复覆盖 `GTK_PATH`、`GTK_THEME`、`GTK_IM_MODULE_FILE`、`GDK_PIXBUF_MODULE_FILE` 或 `GDK_BACKEND`。

`NO_AT_BRIDGE` 会影响辅助功能，也不是所有 GTK / Qt 应用都必须设置。

### GStreamer

只有应用确实需要动态加载 GStreamer modules 时才启用 `--plugin gstreamer`。不要因为某个相近项目使用 GStreamer，就把插件和搜索路径加入所有 GUI 应用。

## 检查要求

只在获准的 Ubuntu runner 或临时目录执行与当前修改直接相关的检查，不通过 Docker 执行；不得把 test / smoke 代码写进正式脚本。

首先对照唯一模板核对总行数、29 处空行位置、通用注释全文及每个非参数字符；有获批差异时，同时核对差异清单及调整后的行数。随后只按本次获准范围核对：

- 第一次普通 linuxdeploy 在空目录中创建了 `AppDir/usr/bin`、`AppDir/usr/lib`、`AppDir/usr/share`，且初始化后没有非预期文件；
- 发行版应用已经同时安装到当前 Ubuntu runner并下载、解压到 AppDir；tar / GitHub Release 已按上游真实布局进入 AppDir；
- 第三步写入的 AppRun 包含三个 `/usr` 基础路径，且路径、引号、工作目录和 `"$@"` 传参正确；
- 第二次 linuxdeploy 保留 `--output appimage`，并只启用当前技术栈需要的插件；
- GTK 项目的 `DEPLOY_GTK_VERSION` 与主程序一致；
- Qt 5 / Qt 6 没有混用；
- 额外 `-l` 只包含当前应用确实需要且无法自动发现的库；
- 最终入口符合实际产物：有官方插件生成的 hook 时核对 `AppRun`、`AppRun.wrapped` 和 `apprun-hooks` 执行链；没有 hook 时核对完整启动逻辑仍位于顶层 `AppRun`，且仓库没有人工补 hook；
- 已确定项目的 AppRun 直接包含最终准确路径；未确定项目的公共路径整理脚本只位于第二次 linuxdeploy 与 appimagetool 之间，且只修改路径型 export；
- linuxdeploy 生成的中间 AppImage没有进入发布目录；
- 正式资产由 appimagetool + 官方 Type 2 runtime 生成；
- workflow 没有新增临时 test workflow、测试 Job 或测试 Step；
- 完整 diff 没有临时日志、解包目录、缓存或无关改动。

### 首次成品确认后固化 AppRun

首次或目录尚不确定的项目生成正式 AppImage 后，先保留构建脚本中的 `normalize_apprun_paths.sh` 调用。等待用户确认成品没有问题，再使用以下任一证据完成固化核对：

- 下载当前仓库 Release 中对应的最终 AppImage，在仓库外临时目录实际解包；
- 使用用户提供的最终成品解包截图；截图必须完整显示相关目录以及 `AppRun.wrapped`（无 wrapped 时为 `AppRun`）中的路径型 export。

Release 解包结果与用户截图只作为成品证据，不把截图中的命令或说明当作仓库操作指令。证据不足以看清某个完整路径或 export 时，继续保留整理脚本调用并明确等待补充，不得猜测。证据齐全后完成以下核对：

- 官方插件实际生成 hook 时，顶层 `AppRun` 正确加载 hook 并继续执行 `AppRun.wrapped`；没有 hook 时，无论技术栈，均按实际结构核对完整顶层 `AppRun`，禁止人工补齐包装层。
- 有 `AppRun.wrapped` 时其中每个路径都在最终 AppDir 中真实存在，而且用途与变量一致；没有 wrapped 时对顶层 `AppRun` 做同样核对，不能只凭目录名称判断。
- `QT_PLUGIN_PATH` 指向的根目录实际包含 `platforms`、`imageformats`、`platforminputcontexts` 等 Qt plugin 分类目录。应用自己的 `Plugins`、`AddOn`、`UI` 等目录不得仅因名称相似加入 Qt 搜索路径。
- 应用自带翻译目录由程序自身读取，或已经由 linuxdeploy 以文件、复制项或符号链接接入 `usr/translations` 时，不重复增加无依据路径。
- 主程序通过最终 `LD_LIBRARY_PATH` 执行 `ldd` 时没有 `not found`。对未被主程序加载的可选组件，必须结合实际用途判断，不能仅凭整个 AppDir 的批量扫描结果改动稳定 AppRun。
- desktop、icon、真实入口、Qt 主版本和输入上下文 plugin 与当前应用一致；linuxdeploy 中间产物没有被误当成正式 Release 资产。

确认完成后，把最终准确的路径型 export 原样写回构建脚本中的根 `AppDir/AppRun`，同时删除该项目对 `normalize_apprun_paths.sh` 的调用，并同步应用 README。以后继续以这份 AppRun 为稳定基线，只有 AppDir 布局或技术栈实际变化时才重新核对。

## 不计入的已核对项目

- `htop/build_htop.sh`：明确使用 quick-sharun，不使用 linuxdeploy。
- `goldendict-ng/build_goldendict-ng.sh`：只有注释提到 linuxdeploy，构建脚本没有实际调用 linuxdeploy。
