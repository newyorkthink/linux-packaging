# AppDir / appimagetool 打包规范（含 linuxdeploy）

本文件统一 AppDir / 官方 appimagetool 体系的风格。下面保留 linuxdeploy 项目的强制规范；直接 appimagetool 项目遵循文末的直接封装补充。两种模式均适用于聊天拟稿、修改方案和实际文件。

## 唯一标准模板

| 模板 | 适用条件 |
| --- | --- |
| [linuxdeploy-gtk-deb.sh](./templates/appimage/linuxdeploy-gtk-deb.sh) | GTK3，GitHub 正式 Release DEB 或官网 HTTPS DEB 直链 |
| [linuxdeploy-gtk-apt.sh](./templates/appimage/linuxdeploy-gtk-apt.sh) | GTK3，Ubuntu 仓库包 |
| [linuxdeploy-gtk-gstreamer-apt.sh](./templates/appimage/linuxdeploy-gtk-gstreamer-apt.sh) | GTK3 + GStreamer，Ubuntu 仓库包 |
| [linuxdeploy-qt-deb.sh](./templates/appimage/linuxdeploy-qt-deb.sh) | Qt，官网校验清单中的 DEB |
| [linuxdeploy-cli-apt.sh](./templates/appimage/linuxdeploy-cli-apt.sh) | CLI / 无框架插件，Ubuntu 仓库包或指定标签的官方归档 DEB |
| [appimagetool-direct.sh](./templates/appimage/appimagetool-direct.sh) | 已有完整 AppDir，直接封装 |

无框架插件模板默认保留 Ubuntu APT 来源。使用固定归档 DEB 时，提供 `RELEASE_TAG`、`GITHUB_REPOSITORY`、`DEB_FILENAME` 和真实程序入口，公共下载入口核对 GitHub SHA-256，版本取自 DEB 元数据；如需调整 desktop 副本，再提供 `DESKTOP_FILE`、`ICON_FILE`、`DESKTOP_EXEC` 和 `DESKTOP_ICON`。原 APT 模式保持不变。

按标准重写时，先从本表选择一份完整模板，通过 [统一生成脚本](./scripts/build/generate_build_script.md) 生成应用一级目录下的构建脚本。模板中的 `../common/` 相对于应用目录，不能在 `templates/appimage/` 内直接运行。linuxdeploy 模板会重建该应用的 `source`、`AppDir` 和 `dist`，应用所需的持久输入应保存在这些目录之外。直接封装模板使用公共工作区入口的 `--prepared-appdir` 模式，只创建缺少的 `source/tools` 和 `dist` 目录，保留现有目录及内容。

除下表中的占位参数外，代码、注释、分区、命令及参数顺序、缩进、空格和空行逐字保留。禁止从其他模板或现有应用脚本拼接代码。模板选用还须符合实际包格式、构建系统、插件、入口和资源布局。

| 占位参数 | 替换内容 |
| --- | --- |
| `__APP_NAME__` | 产物名主体，使用不带目录和扩展名的应用名称。 |
| `__APT_PACKAGES__` | 构建工具和实际依赖的 APT 包名，逐个作为参数填写。Ubuntu 仓库模板须包括主包和各附加包。 |
| `__APT_MAIN_PACKAGE__`、`__APT_EXTRA_PACKAGES__` | 用于解包的主包名和附加包参数。无附加包时，把后者替换为空文本，保留模板原有分隔空格。 |
| `__GITHUB_REPOSITORY__`、`__RELEASE_ASSET_PATTERN__` | 官方仓库的 `owner/repo` 和正式 Release 的 DEB 资产名模板，保留公共入口所需的 `{version}`。 |
| `__CHECKSUM_URL__`、`__DEB_ASSET_REGEX__` | 官方校验清单 URL 和完整 DEB 资产名的正则，保持模板的引号和转义。 |
| `__DEB_FILENAME__` | 下载到 `source` 的本地 DEB 文件名。 |
| `DEB_URL`、`DEB_PACKAGE`、`DEB_ARCH`、`DEB_SHA256` | GTK DEB 模板的官网来源参数；前三项必填，官方 SHA-256 按来源可选，与 GitHub 来源参数互斥。生成器据此展开固定下载调用。 |
| `__MAIN_EXECUTABLE__`、`__APP_BIN_DIR__`、`__APP_LIB_DIR__` | 相对 AppDir 的真实程序入口及程序、运行库目录。 |
| `__GIO_MODULE_DIR__` | 相对 AppDir 的实际 GIO 模块目录。GTK 模板使用包内 GSettings schema 与 GIO 模块。 |
| `__QT_PLUGIN_DIR__`、`__QML_DIR__`、`__QT_TRANSLATIONS_DIR__` | 相对 AppDir 的 Qt 插件、QML 和翻译目录。 |
| `__QMAKE__` | 与实际打包 Qt 主版本一致的 qmake 可执行文件名或路径。 |
| `__PREPARED_APPDIR__` | 相对于应用目录的已准备 AppDir 路径，解析后必须位于该应用目录内。该目录须已有可用的 AppRun、桌面入口、图标及依赖。 |
| `__VERSION_FIELD__`、`__VERSION_OPTION__` | 直接封装模板的版本输出字段编号与已核实的单个查询参数。 |

linuxdeploy 模板适用于应用包已提供可部署的桌面入口和图标、且所选模板的运行目录设置适用的情况。只允许使用 [固定模板清单](./templates/README.md) 中的现有模板。来源、插件组合、资源布局或必要步骤存在冲突时，先说明具体冲突，授权前保留已有构建脚本。专用流程按 [AGENTS.md](./AGENTS.md) 逐次取得用户授权。禁止提出、新增或登记清单外模板。现有模板不作临时拼接，也不为单个应用擅自修改。

## 四个通用标准参考

| 类型 | 标准脚本 | 专属差异 |
| --- | --- | --- |
| GTK | [Joplin](./joplin/build_joplin.sh) | [Joplin 专属差异](./joplin/docs/template-deviations.md) |
| Qt | [XnView MP](./xnviewmp/build_xnviewmp.sh) | [XnView MP 专属差异](./xnviewmp/docs/template-deviations.md) |
| CLI / 无框架插件 | [MediaInfo](./mediainfo/build_mediainfo_linuxdeploy.sh) | [MediaInfo 专属差异](./mediainfo/docs/template-deviations.md) |
| 直接 appimagetool | [Kitty](./kitty/build_kitty.sh) | [Kitty 专属差异](./kitty/docs/template-deviations.md) |

下列现有应用用于查阅既有实现和历史技术依据。按标准重写的底稿统一从上面的模板表选取。开始拟稿或修改时，读取最新 `main` 中所选模板、应用 README 和实际 workflow。

- 通用部分的命令写法、固定注释、顺序、缩进和空行逐字保留。命令保持单行，禁止反斜杠续行；已确认的 `export ARCH=x86_64; linuxdeploy ...` 整行保留。
- 软件包、依赖、来源、路径、启动参数和 AppRun 配置按当前程序的实际需要确定，不复制参考项目的专属修复。
- 行数和空行以选定标准模板为准，参数占位替换按本页规定执行。
- 已确认有效的代码和注释保持原样。增删步骤或调整配置前，说明具体改动、原因和依据，取得本次明确同意；不得借标准化批量修改其他项目。

## 禁止使用 Docker

**任何通过 linuxdeploy 打包的项目，一律禁止使用 Docker。** 构建脚本、workflow、公共入口和应用专用脚本均不得直接或间接调用 Docker，不得通过 Dockerfile、Compose、容器 Action 或额外容器包装执行这条打包链路。

实际构建直接使用 GitHub Actions 的 Ubuntu runner。Ubuntu 版本沿用各项目已确认的环境，不为统一参考而更换。

## 公共注释与专属说明

[linuxdeploy 固定注释标准](./docs/linuxdeploy-comments.md) **只收录必须跨项目统一复用的注释**。通用、GTK、Qt 注释按实际用途逐字使用；CLI 使用适用的通用注释，不增加无关框架配置。

脚本中说明程序专属操作的注释必须以 `# 本程序专属处理：` 开头，冒号后直接说明具体操作。固定注释和已有来源标注必须逐字保留。软件专属修复、路径调整和补库的依据记录在项目自己的 `docs/template-deviations.md`。每项只写处理位置、原因、必要代码或依据。完整代码留在脚本，不重复抄写整份 AppRun 或构建流程。

由应用 README 链接这份差异说明。既有 `hardcoded.md` 和故障历史保留，同一说明不重复扩写；新 linuxdeploy 项目的专属配置也在上述差异文件中简记。其他打包路线的文档要求不变。

## 固定流程

各阶段的标题、注释和空行以选定的标准模板为准；分区标题逐字复用 [固定分区标题](./docs/linuxdeploy-comments.md#固定分区标题)，不自行增减两侧的 `#`。顺序如下：

| 阶段 | 公共入口或处理 |
| --- | --- |
| 初始化脚本 | 在 shebang 下方使用固定分区标题，启用严格模式并定位脚本目录。两种封装路线均适用。 |
| 准备构建目录 | `source common/linuxdeploy/prepare_build_workspace.sh`，只处理当前项目的工作区。 |
| 准备构建环境 | 单行调用 `common/apt/install_packages.sh`，传入当前应用需要的精确包名。 |
| 下载打包工具 | `source common/linuxdeploy/prepare_linuxdeploy_tools.sh`，传入工具目录、插件、中间 AppImage 和 runtime。 |
| 初始化 AppDir | 单行调用 `common/linuxdeploy/initialize_appdir.sh`，传入 AppDir 和 linuxdeploy 路径；只在空目录创建基础结构。 |
| 下载并准备应用 | 复用下面的来源入口，保留上游原始目录布局。 |
| 准备桌面资源和运行库 | 只处理当前程序确实需要的资源、动态加载库或 desktop 差异。 |
| 准备 AppRun | 在 `build_*.sh` 内联完整启动脚本，写入 `AppDir/AppRun` 并赋予执行权限。经批准的长脚本按 AppRun 规则处理。 |
| 核心打包 | 按技术栈第二次运行 linuxdeploy，保留 `--output appimage`。 |
| 整理产物 | 单行调用 `common/linuxdeploy/package_appimage.sh`，最终封装成功后输出 SHA-256 并保存版本号。 |

第一次 linuxdeploy 创建目录后，因没有 desktop 而在输出阶段返回 1，由初始化公共入口兼容；不得提前塞入应用、desktop、图标或 AppRun。第二次生成的中间 AppImage 不得发布。

`source common/linuxdeploy/prepare_build_workspace.sh` 已在当前 Shell 中切换到传入的构建根目录。后续独立 helper 或子 Shell 中的 `cd` 不改变调用方目录；只有后续代码确实改变了当前 Shell 的工作目录时，才需要再切回。不得为了增加一个阶段而重复添加 `cd "$SCRIPT_DIR"`。

### 程序专属代码的位置

程序专属代码必须按实际用途放入对应分区，并遵循执行依赖和先后顺序，不得任意插入或集中放到核心打包。

依赖安装放在准备构建环境；图标、桌面入口及运行库收集放在准备桌面资源和运行库；应用运行环境和启动逻辑写入 AppRun；打包工具的必要配置及 linuxdeploy 调用放在核心打包。

各项目的差异文档简要写明专属代码所在分区及原因。

例如，复制随包发布的运行库属于准备桌面资源和运行库，应在第二次 linuxdeploy 前完成，不得移入核心打包。

### 程序专属补丁与修复脚本

程序专属的补丁和修复脚本统一放在本项目的 `patches/`。源码或文本补丁使用 `.patch`；资源准备、文件整理和二进制路径修复按任务使用 `.sh` 或 `.py`。公共机制仍由 `common/` 提供，不要求每个项目创建相同的脚本。

主 build 按实际阶段单行调用：源码补丁在下载并准备应用时应用，资源准备放在准备桌面资源和运行库，依赖部署后的修复放在整理产物且先于最终封装。完整 AppRun 仍在主 build 中生成，不拆成额外启动入口。各脚本的用途、调用位置和原因简记于本项目的 `docs/template-deviations.md`。

旧修复入口在调用方获准迁移后再移除；新脚本尚未接入时须明确记录，不同时执行新旧修复。

### 应用来源

| 来源 | 公共入口 |
| --- | --- |
| GitHub 正式 Release 的 DEB | `common/github/install_and_extract_latest_stable_release_deb.sh`，返回实际版本。 |
| 官网 HTTPS DEB 直链 | 同一入口的 `--url` 模式；调用方提供 URL、官方 SHA-256 或空字符串、下载路径、解包目录及可选包身份，安装并解包同一份 DEB，版本读取其完整元数据。 |
| 官网校验清单中的 DEB | 同一入口的 `--checksum` 模式；使用同一份已校验 DEB 安装并解包。 |
| 官网 HTML 校验表中的 DEB | 同一入口的 `--html-checksum` 模式，依次传入校验表 URL、完整资产名 Python 正则、资产目录 URL、下载 DEB 路径、AppDir，以及可选的包名与架构；解析、校验、安装、解包和版本返回均由公共入口完成，具体参数见 [公共入口说明](./common/README.md#html-校验表中的官方-deb)。 |
| AUR 指向的官方 DEB | `common/aur/install_and_extract_deb_source.sh`；单行完成来源解析、摘要和包身份校验、安装、原布局解包及实际版本返回，保留同次 AUR 桌面资源。七项参数和版本适用范围见 [公共入口说明](./common/README.md#aur-来源中的官方-deb)。 |
| Ubuntu 仓库 | 先通过公共 APT 入口安装，再调用 `common/apt/extract_installed_package.sh <主软件包名> <AppDir> [附加软件包名 ...]`，逐包下载已安装的同一版本并解包，仅返回主软件包去掉 epoch / revision 的版本号。 |
| 预编译归档 | 通过公共下载入口取得，再调用 `common/archive/extract_archive.sh`；在构建环境安装明确需要的依赖。 |

下载、校验、安装、解包、版本读取和初始化由公共入口负责，应用脚本不重复实现。工具准备入口已加载 `configure_environment.sh`，不再单独调用它。软件和打包工具版本按现有官方动态入口取得，不固定旧版本。

已确认需要在元数据中保留完整 Debian 版本的既有项目，不能用去掉 epoch / revision 的返回值替代原版本。保留该项目已验证的完整版本读取命令，并由 `common/apt/download_and_extract_packages.sh` 按明确的 `<包名>=<完整版本>` 下载同版本 DEB；在应用专属差异中说明原因，不复制下载、校验或解包实现。最终 `version.txt` 仍由公共封装入口写入。

工具准备入口的插件参数支持空字符串、`gtk`、`qt`、`gstreamer`、`gtk,gstreamer` 和 `qt,gstreamer`，只选择当前应用需要的组合；该参数负责下载插件，实际启用仍由 linuxdeploy 命令的 `--plugin` 参数指定。

### AppRun 与框架配置

**自定义 AppRun 必须完整内联在 `build_*.sh`，由构建脚本写入 `AppDir/AppRun`。只有正文过长、确有必要独立维护时，才允许拆成单独文件。拆分前必须说明依据、取得用户明确同意，并记录到应用的 `docs/template-deviations.md`。禁止为了套模板、统一风格或缩短主脚本而拆分。** 两种 appimagetool 封装路线都适用。

完整启动逻辑写入根 `AppDir/AppRun`，直接执行上游真实程序并保留 `"$@"`。不得为填满 `usr/bin` 制造副本或二次转发入口；上游自带 launcher 按原布局保留。

| 项目 | 要求 |
| --- | --- |
| 基础搜索路径 | `PATH`、`LD_LIBRARY_PATH`、`XDG_DATA_DIRS` 分别保留 `$HERE/usr/bin`、`$HERE/usr/lib`、`$HERE/usr/share`；按变量用途追加真实应用目录。 |
| GTK | 根据真实主版本设置 `DEPLOY_GTK_VERSION`；通过公共工具入口取得 GTK 插件及已有 GIO 修复。schemas、GIO、主题等配置按实际需要保留。 |
| Qt | qmake、运行库、plugins、QML 保持同一主版本；路径按最终 AppDir 确定。禁止用 `EXTRA_QT_MODULES` 绕过模块识别。 |
| 其他插件 | GStreamer 等只在当前应用确实需要时启用，不因其他项目使用就加入。 |
| 图标、主题、NSS | 按实际需要使用已有公共入口，不把 Joplin 的资源清单当作所有程序的依赖。 |

显示、输入法、缩放、字体和多媒体选项按各项目已确认的需要设置，不作为所有 Qt / GTK 程序的默认配置。额外运行库及 Qt 模块识别修复必须有当前应用依据，保留已获准的精确收集方式，不照抄其他项目的整组库。

Qt 工具选择按实际调用方式核对。已明确指定对应 Qt 主版本的原生 `QMAKE`，且 Qt 插件能从该 qmake 查询的目录找到 `qmlimportscanner` 时，不额外添加 `QT_SELECT`；只有实际调用 qtchooser 且确需显式选择安装时才使用它。`QMAKE`、扫描工具依赖与 Qt5 / Qt6 运行库匹配仍须保留，不能把“不设置 QT_SELECT”误解成不需要扫描工具。已有项目的具体依据保存在其专属差异文档。

### 中文环境与输入法的适用范围

先判断程序类型、可用翻译和实际语言需求，再选择下面的处理；是否使用 GTK / Qt 插件不决定程序能否显示中文界面。

| 程序情况 | locale 与语言配置 |
| --- | --- |
| 命令行工具 | 保留原有语言环境，不为汉化新增中文 locale 或修改 `LANG`；已有明确例外按该应用记录保留。 |
| 有可用中文翻译，并明确采用中文界面的 GUI | 复用所需的官方翻译资源，按需生成包内中文 locale，并在 AppRun 设置包内数据路径和中文语言。 |
| 没有中文翻译或本次未选择中文界面的 GUI | 保留上游语言和用户选择，不套用中文环境块。单独生成 locale 不能翻译程序；如另需中文区域格式，应说明具体原因。 |

包内 locale 数据提供字符分类、编码和区域格式；界面翻译来自软件自带资源、发行版语言包或已确认的翻译文件；中文输入依赖匹配框架版本的模块及宿主会话。三者分别核对，不能把 locale 文件存在写成中文界面或中文输入已验证。英文界面同样可能需要中文输入，输入支持不随界面语言一并删除。

适用的 linuxdeploy 项目在应用解包后的“准备桌面资源和运行库”阶段，单行调用 `common/linuxdeploy/prepare_locale.sh <locale 源名称> <字符集> <完整输出目录>`，随后才执行正式依赖部署。该入口只生成调用方指定的数据，不选择界面语言，不改写 AppRun，也不创建 `.env`。输出父目录由公共入口创建；主脚本不为同一次 locale 生成重复创建该目录，其他字体、翻译和输入模块目录仍由实际资源准备步骤负责。

采用简体中文界面且使用包内 locale 的 AppRun，在 `HERE` 定位后使用与 Joplin 等标准项目一致的中文环境块：

```bash
# 设置简体中文界面环境。
export LOCPATH="$HERE/usr/lib/locale${LOCPATH:+:$LOCPATH}"
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
```

`LOCPATH` 将包内目录放在前面，并保留原搜索目录；已确认的输入法、翻译目录、启动参数及其他兼容配置保持原样。不把 `LC_ALL`、`LC_MESSAGES` 或某一组语言变量作为所有程序必须复制的配置。固定注释仍只在确实执行对应操作时逐字使用，quick-sharun 的现有脚本不随本次接入修改。

### linuxdeploy 命令

```bash
# 再次运行 linuxdeploy，部署运行资源并生成中间 AppImage。
export ARCH=x86_64; linuxdeploy --appdir AppDir --output appimage
```

```bash
# 再次运行 linuxdeploy，部署运行资源并生成中间 AppImage。
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin gtk --output appimage
```

```bash
# 再次运行 linuxdeploy，部署运行资源并生成中间 AppImage。
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin qt --output appimage
```

`--desktop-file`、`--icon-file`、精确的 `-l <库路径>` 仅在说明必要性并获准后使用。已有命令保持原样，禁止添加 `--executable`。

### 入口与最终封装

hook 只能由当前官方插件实际生成。存在 hook 时由 linuxdeploy 自动处理 `AppRun → AppRun.wrapped`；没有 hook 时保留完整顶层 AppRun。**禁止手工创建、复制或注入 hook，禁止伪造 AppRun.wrapped，也不得把缺少它判为构建失败。**

`normalize_apprun_paths.sh` 只用于已说明并获准的路径整理，不是默认步骤。已有临时调用在成品确认前保留；确认实际目录和 export 后，原样固化到构建脚本的 AppRun，再移除临时调用。已确定的路径不在每次构建时重新整理。

公共工具准备会安装外部 AppImage 输出入口，并按官方优先级接管中间封装：linuxdeploy 部署完依赖及根 desktop / 图标后，包装入口先复用公共权限和 PNG 准备，再将原始参数与 LDAI 环境交给动态下载并校验的官方输出插件。插件探测和第一次空 AppDir 初始化保持原接口；应用无需另加准备命令，不更改既有 `linuxdeploy ... --output appimage` 整行。详细机制与证据见 [linuxdeploy 更新与中间封装兼容](./docs/linuxdeploy-update-compatibility.md)。

最终封装由 `common/linuxdeploy/package_appimage.sh` 使用官方 appimagetool 和明确的 Type 2 runtime 完成。权限及 PNG 根图标的公共处理见 [appimagetool 图标检查与 SVG 兼容处理](./docs/appimagetool-icon-compatibility.md)。不使用 `--no-check-permissions`，不因下载或封装失败而发布中间包。

## 检查与记录

只做本次获准且直接需要的检查，核对公共调用、依赖与 AppRun 路径、引号、顺序、注释及差异说明。语法检查、构建成功和实际运行分别记录；不把 test / smoke 代码加入正式脚本或 workflow，提交后不等待或监控 Actions。

## 当前项目清单

| 项目 | 构建脚本 | 使用方式 |
| --- | --- | --- |
| GoldenDict | `goldendict/build_goldendict.sh` | Ubuntu 24.04 官方 DEB，Qt5 / GStreamer；完整包版本、固定启动路径与发音处理见 [专属差异](./goldendict/docs/template-deviations.md) |
| Alacritty | `alacritty/build_alacritty.sh` | LinuxDeploy 专用源码构建、X11 IME 补丁和公共封装；具体依据见[专属差异](./alacritty/docs/template-deviations.md)。 |
| MediaInfo | `mediainfo/build_mediainfo_linuxdeploy.sh` | linuxdeploy |
| PeaZip | `peazip/build_peazip.sh` | linuxdeploy + Qt 插件 |
| Joplin | `joplin/build_joplin.sh` | linuxdeploy + GTK 插件 |
| Discord | `discord/build_discord.sh` | Ubuntu 22.04，官方稳定版 DEB；LinuxDeploy GTK3 标准生成，旧 quick 备份不参与构建；见[生成参数](./discord/docs/template-deviations.md)。 |
| Binance | `binance/build_binance.sh` | linuxdeploy + GTK 插件 |
| XnView MP | `xnviewmp/build_xnviewmp.sh` | linuxdeploy + Qt 插件 |
| Poppler Utils | `poppler-utils/build_poppler-utils.sh` | linuxdeploy |
| Remmina | `remmina/build_remmina.sh` | linuxdeploy + GTK / GStreamer 插件 |
| dconf Editor | `dconf-editor/build_dconf-editor.sh` | linuxdeploy |
| Rainlendar2 | `rainlendar2/build_rainlendar2.sh` | linuxdeploy + GTK 插件 |
| rvncconnect | `rvncconnect/build_rvncconnect.sh` | linuxdeploy + GTK 插件 |
| RealVNC Viewer 7.15.1 | `vncviewer/build_vncviewer.sh` | 从 `original-package-archive` 获取官方 x64 DEB，使用 linuxdeploy 无框架插件模式与独立 appimagetool；桌面入口处理见 [README](./vncviewer/README.md)。 |
| 腾讯会议 | `wemeet/build_wemeet.sh` | linuxdeploy + Qt 插件 |

仅在 README、注释或说明文字中出现 linuxdeploy，但构建脚本没有实际调用的项目，不计入本清单。清单只表示实际使用这条路线，不表示所有既有脚本已经完成模板对齐；本次规范更新不授权批量修改其他应用。

## 既有工具行为与产物证据

本规范基于以下证据整理：

- 当前仓库全部 linuxdeploy 构建脚本；
- 用户本地已经实际使用的两阶段命令；
- 用户提供的 PeaZip 与 File Roller AppImage 解包结果；
- linuxdeploy、linuxdeploy-plugin-qt、linuxdeploy-plugin-gtk 和 Type 2 runtime 的实际行为。

历史样本解包后都确认存在顶层 `AppRun`、`AppRun.wrapped` 和 `apprun-hooks/`：当时的 PeaZip 顶层 AppRun 自动加载 `linuxdeploy-plugin-qt-hook.sh`，File Roller 顶层 AppRun 自动加载 `linuxdeploy-plugin-gtk.sh`，随后执行 `AppRun.wrapped`。这些样本证明第二次 linuxdeploy 必须保留 `--output appimage`，但不证明当前每个插件版本都会生成 hook；例如当前官方 Qt 插件会跳过 Qt6 hook。最终结构必须以当前官方工具实际产物为准，禁止为了复刻历史样本手工补 hook。

## 不计入的已核对项目

- `htop/build_htop.sh`：明确使用 quick-sharun，不使用 linuxdeploy。
- `goldendict-ng/build_goldendict-ng.sh`：只有注释提到 linuxdeploy，构建脚本没有实际调用 linuxdeploy。

## 直接 appimagetool 模式：同一体系的精简流程

直接 appimagetool 和 linuxdeploy 属于同一套 AppDir / 官方 appimagetool 打包体系，按相同的分区、通用注释、单行公共调用和空行风格维护；quick-sharun / sharun 继续使用另一套规范。直接模式不执行 linuxdeploy，也不下载它的插件，不增加空 AppDir 初始化、第二次部署或中间 AppImage。

直接封装使用 [appimagetool-direct.sh](./templates/appimage/appimagetool-direct.sh) 作为唯一底稿。Kitty 保留为既有实现参考。

| 阶段 | 直接模式的处理 |
| --- | --- |
| 初始化脚本 | 复用固定分区标题和初始化注释。 |
| 准备构建目录和环境 | 标准模板调用公共工作区入口的 `--prepared-appdir` 模式；安装依赖仍按当前系统选择公共入口，不混用 Arch 与 Ubuntu。 |
| 下载并准备应用 | 使用官方预编译包和公共下载 / 解包入口，保留程序真实布局。 |
| 准备桌面资源和运行库 | 只保留有当前应用依据的资源、补库及专属修复。 |
| 准备 AppRun | 在 `build_*.sh` 内联完整启动脚本并写入 `AppDir/AppRun`。经批准的长 AppRun 可原样复制到该位置。 |
| 下载打包工具 | 一次调用工具准备入口的 `--appimagetool` 模式，下载并校验 appimagetool 和 Type 2 runtime，在公共入口设置权限。 |
| 整理产物 | 一次调用公共封装入口，完成 PNG / 权限准备、封装、有效产物检查、SHA-256 和版本保存。 |

上表只说明适用阶段，不授权改变已验证命令的必要顺序或批量重写其他项目。Ubuntu runner、禁止 Docker 和插件要求按前文适用于 linuxdeploy 路线。两条路线共用 AppRun 内联规则。

### 与 linuxdeploy 标准尽量对齐

直接 appimagetool 是同一标准的精简分支，适用的分区、固定注释、单行公共调用、缩进和空行尽量与 linuxdeploy 标准对齐，不另写一套风格。“尽量”用于判断步骤是否适用，不放宽同用途固定注释必须逐字一致的要求。

- **分区和注释：** 从现有固定表选择真实需要的标题与原文，标点和两侧 `#` 保持一致；没有对应操作的分区直接省略，不补空段，也不使用同义改写。严格模式、脚本定位、依赖安装、版本读取、工具准备、执行权限和最终封装等相同用途，应复用同一原文。
- **公共调用和排版：** 已有公共入口能完成的操作继续单行调用，按同一体系的规则安排缩进和空行；具体参数依照当前来源、环境和真实布局填写，不复制其他应用的专属配置。
- **顺序与稳定基线：** 在满足实际执行依赖的前提下，阶段顺序尽量与共同流程一致；现有已验证命令、参数和必要顺序保持原样，不为套用分区移动代码。确需保留的阶段差异在本项目 `docs/template-deviations.md` 说明处理位置、原因及影响，不能只以“直接模式”为由任意偏离。
- **只保留真实差异：** 省略 linuxdeploy 的初始化、依赖部署、插件和中间包步骤，直接模式自行准备完整 AppDir 及其所需依赖和资源；保留项目已经确认的构建环境及启动逻辑。独立 AppRun 仅用于已获批准的长脚本，并按实际操作使用对应注释，保留已有正确的专属说明。

本节明确对齐边界，不授权批量重写已有项目；修改范围仍以当前用户要求为准。

### 公共调用示例

在项目的 build 脚本中使用以下公共调用，变量由当前程序的实际路径和版本输出确定：

~~~bash
# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" command "$MAIN_BIN" --field "$VERSION_FIELD" -- "$VERSION_OPTION")"
~~~

`MAIN_BIN` 是真实程序，`VERSION_FIELD` 是首行输出中从 1 开始的版本字段编号，`VERSION_OPTION` 是该程序已核实的查询参数。需要多个查询参数时在 `--` 后逐个传入；原 `package-json`、`pacman` 和 `text` 来源继续按实际来源使用。

~~~bash
# 下载并校验最终封装工具及运行时，并设置执行权限。
"$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" --appimagetool "$APPIMAGETOOL" "$RUNTIME_FILE"
~~~

两个参数分别是 appimagetool 和 runtime 的输出文件路径，必须不同。该模式只独立执行，不使用 source；保留原官方 continuous 来源和摘要校验，不下载或执行 linuxdeploy，也不加载它的环境配置。

~~~bash
# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
~~~

最终产物目录的 `version.txt` 由公共封装入口写入。调用方不重复准备 PNG、保存版本或追加仅表示成功的 `echo`；程序实际需要的运行输出继续保留。直接模式的通用注释登记在 [固定注释标准](./docs/linuxdeploy-comments.md)，kitty 的既有目录和启动差异见其专属说明。
