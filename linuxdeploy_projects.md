# linuxdeploy 项目清单与打包规范

本文件是本仓库所有 linuxdeploy 项目的强制规范，适用于聊天拟稿、修改方案和实际文件。

## 三个标准参考

| 类型 | 标准脚本 | 专属差异 |
| --- | --- | --- |
| GTK | [Joplin](./joplin/build_joplin.sh) | [Joplin 专属差异](./joplin/docs/template-deviations.md) |
| Qt | [XnView MP](./xnviewmp/build_xnviewmp.sh) | [XnView MP 专属差异](./xnviewmp/docs/template-deviations.md) |
| CLI / 无框架插件 | [MediaInfo](./mediainfo/build_mediainfo_linuxdeploy.sh) | [MediaInfo 专属差异](./mediainfo/docs/template-deviations.md) |

三个脚本共同确定公共结构；按技术栈选择参考，不从不同项目中任意拼接代码。文档不重复抄写完整脚本，开始修改时读取最新 main 中的对应脚本、应用 README 和实际 workflow。

- 通用部分的命令写法、固定注释、顺序、缩进和空行逐字保留。命令保持单行，禁止反斜杠续行；已确认的 `export ARCH=x86_64; linuxdeploy ...` 整行保留。
- 软件包、依赖、来源、路径、启动参数和 AppRun 配置按当前程序的实际需要确定，不复制参考项目的专属修复。
- Joplin 的 85 行、29 行空行只对应 Joplin；其他项目按各自实际代码核对，不用无关配置或空行凑数。
- 已确认有效的代码和注释保持原样。增删步骤或调整配置前，说明具体改动、原因和依据，取得本次明确同意；不得借标准化批量修改其他项目。

## 禁止使用 Docker

**任何通过 linuxdeploy 打包的项目，一律禁止使用 Docker。** 构建脚本、workflow、公共入口和应用专用脚本均不得直接或间接调用 Docker，不得通过 Dockerfile、Compose、容器 Action 或额外容器包装执行这条打包链路。

实际构建直接使用 GitHub Actions 的 Ubuntu runner。Ubuntu 版本沿用各项目已确认的环境，不为统一参考而更换。

## 公共注释与专属说明

[linuxdeploy 固定注释标准](./docs/linuxdeploy-comments.md) **只收录必须跨项目统一复用的注释**。通用、GTK、Qt 注释按实际用途逐字使用；CLI 使用适用的通用注释，不增加无关框架配置。

软件专属的修复、路径调整、补库及其注释，统一放在该项目自己的 `docs/template-deviations.md`，不加入公共注释表，也不要求先到公共表登记。每项只写处理位置、原因、必要代码或依据；完整代码留在脚本，不重复抄写整份 AppRun 或构建流程。

由应用 README 链接这份差异说明。既有 `hardcoded.md` 和故障历史保留，同一说明不重复扩写；新 linuxdeploy 项目的专属配置也在上述差异文件中简记。其他打包路线的文档要求不变。

## 固定流程

各阶段的标题、注释和空行以参考脚本为准，顺序如下：

| 阶段 | 公共入口或处理 |
| --- | --- |
| 准备构建目录 | `source common/linuxdeploy/prepare_build_workspace.sh`，只处理当前项目的工作区。 |
| 准备构建环境 | 单行调用 `common/apt/install_packages.sh`，传入当前应用需要的精确包名。 |
| 下载打包工具 | `source common/linuxdeploy/prepare_linuxdeploy_tools.sh`，传入工具目录、插件、中间 AppImage 和 runtime。 |
| 初始化 AppDir | 单行调用 `common/linuxdeploy/initialize_appdir.sh`，传入 AppDir 和 linuxdeploy 路径；只在空目录创建基础结构。 |
| 下载并准备应用 | 复用下面的来源入口，保留上游原始目录布局。 |
| 准备桌面资源和运行库 | 只处理当前程序确实需要的资源、动态加载库或 desktop 差异。 |
| 准备 AppRun | 在 AppDir 根目录写入完整启动脚本并赋予执行权限。 |
| 核心打包 | 按技术栈第二次运行 linuxdeploy，保留 `--output appimage`。 |
| 整理产物 | 单行调用 `common/linuxdeploy/package_appimage.sh`，最终封装成功后输出 SHA-256 并保存版本号。 |

第一次 linuxdeploy 创建目录后，因没有 desktop 而在输出阶段返回 1，由初始化公共入口兼容；不得提前塞入应用、desktop、图标或 AppRun。第二次生成的中间 AppImage 不得发布。

### 应用来源

| 来源 | 公共入口 |
| --- | --- |
| GitHub 正式 Release 的 DEB | `common/github/install_and_extract_latest_stable_release_deb.sh`，返回实际版本。 |
| 官网校验清单中的 DEB | 同一入口的 `--checksum` 模式；使用同一份已校验 DEB 安装并解包。 |
| Ubuntu 仓库 | 先通过公共 APT 入口安装，再调用 `common/apt/extract_installed_package.sh <包名> <AppDir>`，下载已安装的同一版本并解包，返回去掉 epoch / revision 的版本号。 |
| 预编译归档 | 通过公共下载入口取得，再调用 `common/archive/extract_archive.sh`；在构建环境安装明确需要的依赖。 |

下载、校验、安装、解包、版本读取和初始化由公共入口负责，应用脚本不重复实现。工具准备入口已加载 `configure_environment.sh`，不再单独调用它。软件和打包工具版本按现有官方动态入口取得，不固定旧版本。

### AppRun 与框架配置

完整启动逻辑写入根 `AppDir/AppRun`，直接执行上游真实程序并保留 `"$@"`。不得为填满 `usr/bin` 制造副本或二次转发入口；上游自带 launcher 按原布局保留。

| 项目 | 要求 |
| --- | --- |
| 基础搜索路径 | `PATH`、`LD_LIBRARY_PATH`、`XDG_DATA_DIRS` 分别保留 `$HERE/usr/bin`、`$HERE/usr/lib`、`$HERE/usr/share`；按变量用途追加真实应用目录。 |
| GTK | 根据真实主版本设置 `DEPLOY_GTK_VERSION`；通过公共工具入口取得 GTK 插件及已有 GIO 修复。schemas、GIO、主题等配置按实际需要保留。 |
| Qt | qmake、运行库、plugins、QML 保持同一主版本；路径按最终 AppDir 确定。禁止用 `EXTRA_QT_MODULES` 绕过模块识别。 |
| 其他插件 | GStreamer 等只在当前应用确实需要时启用，不因其他项目使用就加入。 |
| 图标、主题、NSS | 按实际需要使用已有公共入口，不把 Joplin 的资源清单当作所有程序的依赖。 |

显示、输入法、缩放、字体和多媒体选项按各项目已确认的需要设置，不作为所有 Qt / GTK 程序的默认配置。额外运行库及 Qt 模块识别修复必须有当前应用依据，保留已获准的精确收集方式，不照抄其他项目的整组库。

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

最终封装由 `common/linuxdeploy/package_appimage.sh` 使用官方 appimagetool 和明确的 Type 2 runtime 完成。权限及 PNG 根图标的公共处理见 [appimagetool 图标检查与 SVG 兼容处理](./docs/appimagetool-icon-compatibility.md)。不使用 `--no-check-permissions`，不因下载或封装失败而发布中间包。

## 检查与记录

只做本次获准且直接需要的检查，核对公共调用、依赖与 AppRun 路径、引号、顺序、注释及差异说明。语法检查、构建成功和实际运行分别记录；不把 test / smoke 代码加入正式脚本或 workflow，提交后不等待或监控 Actions。

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

## 不计入的已核对项目

- `htop/build_htop.sh`：明确使用 quick-sharun，不使用 linuxdeploy。
- `goldendict-ng/build_goldendict-ng.sh`：只有注释提到 linuxdeploy，构建脚本没有实际调用 linuxdeploy。
