# linuxdeploy 项目清单与打包规范

本文件记录当前仓库实际调用 `linuxdeploy` 的项目，并规定以后新增、迁移或重做 linuxdeploy 项目的统一流程。

本规范基于以下证据整理：

- 当前仓库全部 linuxdeploy 构建脚本；
- 用户本地已经实际使用的两阶段命令；
- 用户提供的 PeaZip 与 File Roller AppImage 解包结果；
- linuxdeploy、linuxdeploy-plugin-qt、linuxdeploy-plugin-gtk 和 Type 2 runtime 的实际行为。

历史样本解包后都确认存在顶层 `AppRun`、`AppRun.wrapped` 和 `apprun-hooks/`：当时的 PeaZip 顶层 AppRun 自动加载 `linuxdeploy-plugin-qt-hook.sh`，File Roller 顶层 AppRun 自动加载 `linuxdeploy-plugin-gtk.sh`，随后执行 `AppRun.wrapped`。这些样本证明第二次 linuxdeploy 必须保留 `--output appimage`，但不证明当前每个插件版本都会生成 hook；例如当前官方 Qt 插件会跳过 Qt6 hook。最终结构必须以当前官方工具实际产物为准，禁止为了复刻历史样本手工补 hook。

已经验证稳定的现有项目继续以自身 README 和脚本为稳定基线；不得为了套用本文模板而顺手重写稳定项目。

## 当前项目清单

| 项目 | 构建脚本 | 使用方式 |
| --- | --- | --- |
| Alacritty | `alacritty/build_alacritty_linuxdeploy.sh` | linuxdeploy |
| MediaInfo | `mediainfo/build_mediainfo_linuxdeploy.sh` | linuxdeploy |
| PeaZip | `peazip/build_peazip.sh` | linuxdeploy + Qt 插件 |
| XnConvert | `xnconvert/build_xnconvert.sh` | linuxdeploy + Qt 插件 |
| Joplin | `joplin/build_joplin.sh` | linuxdeploy + GTK 插件 |
| XnView MP | `xnviewmp/build_xnviewmp.sh` | linuxdeploy + Qt 插件 |
| Poppler Utils | `poppler-utils/build_poppler-utils.sh` | linuxdeploy |
| Remmina | `remmina/build_remmina.sh` | linuxdeploy + GTK / GStreamer 插件 |
| dconf Editor | `dconf-editor/build_dconf-editor.sh` | linuxdeploy |
| 百度网盘 | `baidunetdisk/build_baidunetdisk.sh` | linuxdeploy + GTK 插件 |
| Rainlendar2 | `rainlendar2/build_rainlendar2.sh` | linuxdeploy + GTK 插件 |
| RealVNC RVNC Connect | `realvnc-rvnc-connect/build_realvnc-rvnc-connect.sh` | linuxdeploy + GTK 插件 |

仅在 README、注释或说明文字中出现 linuxdeploy，但构建脚本没有实际调用的项目，不计入本清单。

## 新项目必须先横向参考现有实现

开始新增、迁移或重做 linuxdeploy 项目前，必须先完整阅读根目录 `AGENTS.md`、本文件、目标应用 README、构建脚本和对应 workflow，再从本仓库选择至少 2～3 个技术栈与上游包布局最接近的项目横向核对。

| 当前项目类型 | 优先参考 |
| --- | --- |
| 普通 ELF / CLI | MediaInfo、Poppler Utils、Alacritty |
| Qt 应用 | PeaZip、XnConvert、XnView MP |
| GTK 应用 | Joplin、百度网盘、Rainlendar2、RealVNC RVNC Connect |
| GTK + GStreamer / 多插件应用 | Remmina，并同时参考一个普通 GTK 项目 |
| GSettings、dconf、locale 或多入口应用 | dconf Editor、Poppler Utils，并结合相同技术栈项目 |

横向参考只用于比较上游来源、AppDir 布局、AppRun、desktop / icon、插件和动态加载依赖。不得复制另一个项目的整段 Qt、GTK、GStreamer、主题、输入法、多媒体或特殊兼容逻辑。

## 唯一标准流程：先初始化目录，再放入应用，最后由 appimagetool 封装

### 公共下载、初始化与打包工具准备

仓库内可复用公共入口如下：

```bash
# 下载普通 HTTPS 文件；上游提供摘要时把 SHA-256 作为第三个参数传入
"$SCRIPT_DIR/../common/download/download_file.sh" "<下载地址>" "<输出文件>" "<SHA-256>"

# 从官方 SHA-256 清单选择、校验并下载最新匹配资产，同时写入版本文件
"$SCRIPT_DIR/../common/download/download_latest_checksum_asset.sh" "<官方校验清单 URL>" '<完整资产名正则>' "<输出文件>" "<版本文件>"

# 从 GitHub 正式 semver Release 选择、校验并下载唯一的 {version} 资产；stdout 返回实际版本
VERSION="$("$SCRIPT_DIR/../common/github/download_latest_stable_release_asset.sh" "<owner/repo>" '<资产名-{version}.扩展名>' "<输出文件>")"

# 统一更新 APT 索引并安装当前应用明确需要的软件包
"$SCRIPT_DIR/../common/apt/install_packages.sh" <软件包名或本地 DEB> [...]

# 只下载指定 APT 包并按各自原始布局解包进目标目录
"$SCRIPT_DIR/../common/apt/download_and_extract_packages.sh" "<解包目标目录>" <软件包名> [...]

# 统一把 DEB 或 tar 系列归档解包到指定目录
"$SCRIPT_DIR/../common/archive/extract_archive.sh" "<归档文件>" "<输出目录>"

# 动态下载 linuxdeploy、appimagetool、Type 2 runtime；GTK 项目追加 gtk 参数
"$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "<工具目录>" gtk

# Qt 项目追加 qt 参数
"$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "<工具目录>" qt

# 设置标准 source / AppDir / dist / tools 路径、检查 x86_64，并清理、重建工作目录
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" "<资产基础名>"

# 复制同一 Debian / Ubuntu 运行环境的 NSS 核心库与 dlopen 模块
"$SCRIPT_DIR/../common/linuxdeploy/copy_nss_runtime.sh" "$APPDIR/usr/lib"

# 设置技术栈无关的 linuxdeploy 环境；Qt / GTK 变量由项目另行追加
source "$SCRIPT_DIR/../common/linuxdeploy/configure_environment.sh" "<工具目录>" "<中间 AppImage>" "<runtime>"

# 第一次普通 linuxdeploy：在空目录创建 AppDir 基础结构
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR"

# 使用官方 appimagetool 和 Type 2 runtime 最终封装，并输出 SHA-256；已取得软件版本时追加第五参数
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" "<appimagetool>" "$APPDIR" "<输出 AppImage>" "<runtime>" "<软件版本>"
```

项目尚未把工具目录加入 `PATH` 时，可把 linuxdeploy 可执行文件作为第二个参数传入；调用仍只保留一行。

`download_file.sh` 统一处理 HTTPS、失败退出、重试、超时、临时文件和可选 SHA-256 校验；`download_latest_checksum_asset.sh` 统一处理官方清单下载、最新版选择、摘要校验、资产下载和版本文件；`download_latest_stable_release_asset.sh` 复用 GitHub Release 解析与公共下载入口，把“正式 semver + `{version}` 资产模板 + GitHub digest”的解析、拆分、下载和校验收进一处，并只把实际版本写到 stdout；`install_packages.sh` 统一处理 APT 索引、root / sudo、非交互安装以及公共下载与解析入口所需的基础命令，项目只传应用专用依赖；`download_and_extract_packages.sh` 统一处理“只下载指定 APT 包并解包到目标目录”的场景；`extract_archive.sh` 统一处理 DEB 与 tar 系列归档的格式判断和解包命令；`prepare_build_workspace.sh` 统一检查当前 x86_64 linuxdeploy 架构、设置标准工作路径并清理、重建目录；`copy_nss_runtime.sh` 统一维护当前已验证的 Debian / Ubuntu NSS 核心库和 dlopen 模块复制清单；`configure_environment.sh` 只设置技术栈无关的 linuxdeploy 环境；`initialize_appdir.sh` 统一执行第一次普通 linuxdeploy；`package_appimage.sh` 统一使用官方 appimagetool 和 Type 2 runtime 最终封装、确认正式资产非空并输出 SHA-256；调用方已取得软件版本时可追加第五参数，由该公共入口在最终资产成功生成后写入同目录 `version.txt`。`prepare_linuxdeploy_tools.sh` 每次构建都从各自官方 continuous Release 动态解析当前最新 x86_64 资产与 GitHub 官方 digest，应用脚本和 AI 都不记录或人工更新工具版本；GTK 插件没有 Release 资产，因此从官方仓库默认分支动态解析当前文件并核对 Git blob SHA。官方 GTK 插件当前缺少 GIO modules 复制逻辑，公共脚本只在下载文件仍没有 `gio_moduledir` 时应用已验证的最小修复；上游将来加入后自动跳过。以上文件再交给公共下载脚本取得，不固定工具版本。

新增项目或当前修改触及对应代码时，项目脚本对每一次下载、安装、解包或空 AppDir 初始化只能保留一条公共脚本调用命令，并把当前应用的 URL、完整资产名正则、输出路径、版本文件、依赖名称、归档文件或 AppDir 路径作为参数传入。禁止在项目脚本中自行使用 `curl`、`wget`、Release / API 查询、校验清单解析、最新版选择、摘要拼装、`apt-get update`、`apt-get install`、`dpkg-deb -x`、`tar -x`、root / sudo 判断，或重复第一次 linuxdeploy 命令。需要修复通用行为时只修改 `common/` 公共实现；下载后的应用专用文件定位和 AppDir 布局调整仍由项目脚本处理。本规则不授权批量改写本次任务未触及的稳定项目。

GIO dynamic modules 与 GI typelibs、GTK input modules 不是同一类资源。官方插件已经处理 typelibs 和 GTK immodules，但这不能替代 `gio-2.0` modules。新增、迁移或重做 GTK linuxdeploy 项目时不得直接下载未修补的官方 `linuxdeploy-plugin-gtk.sh`；必须给公共工具准备脚本传入 `gtk`，并在第二次 linuxdeploy 后确认最终 AppDir 中存在构建环境实际 `giomoduledir` 对应的模块目录。项目若明确设置 `GIO_MODULE_DIR`，必须指向该 AppDir 内的实际目录，不能指向宿主机。

以上占位符只用于说明接口，正式脚本必须换成当前项目的真实变量。公共脚本属于本仓库自身实现，不得在代码或说明中依赖、调用或提及其他仓库。

### linuxdeploy 命令形式固定

linuxdeploy 统一只使用下面三种基础命令，不因应用来自 DEB、tar、GitHub Release，也不因主程序位于 `/opt`、`/usr/bin` 或其他目录而改变：

```bash
# 普通应用统一使用此命令
export ARCH=x86_64; linuxdeploy --appdir AppDir --output appimage

# GTK 应用统一使用此命令
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin gtk --output appimage

# Qt 应用统一使用此命令
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin qt --output appimage
```

项目确有需要时，只允许追加 `--desktop-file`、`--icon-file` 和精确的 `-l <库路径>`。禁止追加 `--executable`，也禁止擅自增加其他未经本规范确认的 linuxdeploy 参数。

### 第一步：在空目录运行普通 linuxdeploy，只创建 AppDir 基础目录

应用文件进入 AppDir 之前，项目构建脚本只调用一次公共入口：

```bash
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR"
```

公共入口内部逐字保留已经验证的 `export ARCH=x86_64; linuxdeploy --appdir AppDir --output appimage`。项目脚本不得复制这段实现，只保留上面一行调用；应用各自的 Qt、GTK、QMAKE、NO_STRIP 等环境仍按项目需要在调用前设置。

这一步只用于让 linuxdeploy 创建 AppDir 目录结构，不应提前放入应用、desktop、icon、AppRun 或自制入口。当前 linuxdeploy 在创建目录后，会因为空 AppDir 尚无 desktop 而在 `--output appimage` 阶段返回 1；公共入口直接兼容该结果，不添加其他检查。

第一次命令不会产生正式资产，也不把它的输出放入发布目录。

### 第二步：下载应用，同时安装到构建环境并解压到 AppDir

第一次目录初始化完成后，再取得应用文件。不得只安装到构建环境而不解压 AppDir，也不得只解压 AppDir 却遗漏构建环境中用于依赖解析的对应软件包和依赖。

#### Debian / Ubuntu 软件源中的应用

```bash
# 下载当前软件源实际提供的 DEB
apt download <软件包名>

# 在隔离构建环境安装同一应用及其依赖
sudo apt-get install -y <软件包名>

# 通过公共入口把下载得到的同一 DEB 内容解压到 AppDir
"$SCRIPT_DIR/../common/archive/extract_archive.sh" "./<软件包文件>.deb" "$APPDIR"
```

正式脚本应使用当前环境实际需要的 root / sudo 调用方式；不能把示例占位符直接提交。

#### 网上直接下载的 DEB

先校验来源与摘要，再把同一 DEB 安装到隔离构建环境，并调用 `common/archive/extract_archive.sh` 解压到 AppDir。安装和解压必须对应同一个文件，禁止拿不同版本混用。

#### tar、压缩包或 GitHub Release

通过 `common/archive/extract_archive.sh` 按上游真实目录结构解压到 AppDir：上游在 `/opt/<应用>` 就保持 `AppDir/opt/<应用>`，在 `/usr/bin`、`/usr/lib`、`/usr/share` 就保持对应 AppDir 路径。构建环境同时安装该应用明确需要的运行依赖；不得为了填充空的 `AppDir/usr/bin` 而复制主程序、创建 wrapper 或使用 `--executable`。

### 第三步：写入完整根 AppDir/AppRun

所有 linuxdeploy 项目的自定义启动逻辑都必须直接写入根 `AppDir/AppRun`。禁止把启动逻辑写入新建的 `AppDir/usr/bin/<程序名>`，再让根 AppRun 二次转发。

无论应用实际位于 `/opt` 还是 `/usr/bin`，完整根 AppRun 都必须保留以下三项基础路径：

```bash
# 让 AppImage 优先找到 AppDir/usr/bin 中的程序
export PATH="$HERE/usr/bin${PATH:+:$PATH}"

# 让 AppImage 优先找到 AppDir/usr/lib 中的运行库
export LD_LIBRARY_PATH="$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# 让应用找到 AppDir/usr/share 中的数据、desktop、locale 和 schemas
export XDG_DATA_DIRS="$HERE/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
```

应用位于 `/opt` 时，只按每个变量的用途追加真实目录，不能删掉 `usr/bin`、`usr/lib`、`usr/share`：

```bash
#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"

# 保留 /usr/bin 基础路径，并加入 /opt 中的真实程序目录
export PATH="$HERE/opt/<应用>:$HERE/usr/bin${PATH:+:$PATH}"

# 保留 /usr/lib 基础路径，并只加入 /opt 中真实存在的库目录
export LD_LIBRARY_PATH="$HERE/opt/<应用>/lib:$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# 所有布局都保留 /usr/share
export XDG_DATA_DIRS="$HERE/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

exec "$HERE/opt/<应用>/<真实主程序>" "$@"
```

Qt 应用再按最终 AppDir 的真实内容加入 `usr/plugins`、`usr/qml`、`usr/translations` 及对应的上游 `/opt` 目录；GTK hook 会处理 GTK 专用目录，但不能因此删除上述三个 `/usr` 基础路径。各变量只加入与自身用途对应的目录，不要求每行目录数量相同。

`AppDir/usr/bin` 可以为空；只要上游没有真实入口，就不得为了填满目录制造 `usr/bin/<程序名>`。完整根 AppRun 应直接执行上游真实主程序。

### 第四步：按技术栈执行第二次 linuxdeploy

> [!IMPORTANT]
> **禁止项目脚本、workflow、公共 helper 或 AI 手工创建、复制、下载、修改或注入任何 linuxdeploy hook。禁止空 hook、`true` hook、兼容 hook和占位 hook；当前官方插件没有生成 hook 时，禁止为了得到 `AppRun.wrapped` 无中生有补 hook，也禁止把缺少 `AppRun.wrapped` 当作构建失败。完整根 `AppDir/AppRun` 在无 hook 时就是最终顶层入口。**

普通应用继续执行：

```bash
# 部署普通应用并处理根 AppRun
export ARCH=x86_64; linuxdeploy --appdir AppDir --output appimage
```

GTK 3 应用执行：

```bash
# 明确要求 GTK 插件部署 GTK 3
export DEPLOY_GTK_VERSION=3

# 部署 GTK 资源并生成中间 AppImage；仅使用官方插件实际生成的 hook
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin gtk --output appimage
```

只有主程序真实使用 GTK 2 或 GTK 4 时，才把 `DEPLOY_GTK_VERSION` 改为 `2` 或 `4`。

Qt 应用先确认 Qt 5 / Qt 6，再把大写 `QMAKE` 指向对应 qmake 的真实命令或完整路径：

```bash
# 指定 Qt 6 qmake
export QMAKE=qmake6

# 部署 Qt 6 资源并生成中间 AppImage；不得手工补 hook
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin qt --output appimage
```

```bash
# 指定 Qt 5 qmake
export QMAKE=qmake

# 部署 Qt 5 资源并生成中间 AppImage；不得手工补 hook
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin qt --output appimage
```

Qt 运行库、qmake、plugins、输入上下文和 QML 必须保持同一主版本。能够唯一、正确自动识别 qmake 时可以不设置 `QMAKE`；否则必须使用 `command -v qmake6` 或 `command -v qmake` 核实真实路径。

动态加载库确实无法自动发现时，只能逐个使用 `-l` 精确补入。用户已经验证的 GTK NSS 命令原样保留：

```bash
# 为 GTK 应用精确补入无法自动发现的 NSS 运行库
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin gtk --output appimage -l /usr/lib/x86_64-linux-gnu/libnss3.so -l /usr/lib/x86_64-linux-gnu/libnssutil3.so  -l /usr/lib/x86_64-linux-gnu/libsmime3.so -l /usr/lib/x86_64-linux-gnu/libsoftokn3.so
```

不得把该 NSS 列表复制到不需要的项目，也不得使用目录或通配符代替精确库路径。

### 第五步：目录尚不确定时才整理 AppRun 路径

首次打包，或第二次 linuxdeploy 可能新增、删除目录且最终成品尚未由用户确认时，必须在 appimagetool 最终封装之前保留以下调用：

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

linuxdeploy 产生或尝试产生的 AppImage 都只能留在临时位置，禁止作为正式 Release 资产。

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

可以在本地、容器或临时目录执行与当前修改直接相关的检查，但不得把 test / smoke 代码写进正式脚本。

至少核对：

- 第一次普通 linuxdeploy 在空目录中创建了 `AppDir/usr/bin`、`AppDir/usr/lib`、`AppDir/usr/share`，且初始化后没有非预期文件；
- 发行版应用已经同时安装到隔离构建环境并下载、解压到 AppDir；tar / GitHub Release 已按上游真实布局进入 AppDir；
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
