# common

应用构建脚本只单行调用这里的公共入口。某个软件的修复记录不要写到这里，写回该软件目录。

## 公共代码与公共函数

- `common/` 当前包含 `apt/`、`archive/`、`aur/`、`build/`、`desktop/`、`download/`、`github/`、`gui/`、`linuxdeploy/` 等目录。本项只是标记为**需要后续重新完整审计**，不是认定这些公共实现当前一定有错误。
- 后续 AI 需要从调用方和公共实现两端一起检查，不能只看某一个 helper：确认职责边界是否正确、是否存在重复通用逻辑、参数语义是否一致、错误处理与返回码是否可靠、下载 / 校验 / DEB 元数据 / 解包 / linuxdeploy 初始化与最终封装是否由正确层负责。
- 重点检查近期从 PeaZip 等项目下沉到公共函数的逻辑，确认没有把应用专用规则错误公共化，也没有让应用脚本重复做公共入口已经负责的检查。
- 已经由用户明确确认有效的命令、调用顺序、AppRun 行为和打包基线必须逐字保留；公共化不能成为顺手重写这些稳定内容的理由。
- 必须同时检查所有受影响调用方，避免只修公共函数后才逐个发现调用参数、路径、返回值或行为不兼容。
- `archive/extract_archive.sh` 统一支持 DEB、Snap、tar 系列归档和 Brotli 压缩的 `.distro` tar 包；应用脚本只传入归档文件与输出目录，应用专用的文件定位和目录调整仍留在应用脚本。
- `apt/extract_installed_package.sh <主软件包名> <AppDir> [附加软件包名 ...]` 先读取各包的已安装版本，再逐包下载同一版本并按原布局解包；成功后仅向 stdout 返回主软件包去掉 epoch / revision 的版本号。安装由调用方提前完成，本入口不重新安装软件。原有两个参数的调用保持兼容。
- `linuxdeploy/prepare_linuxdeploy_tools.sh` 独立执行时接收工具目录和可选的插件参数；通过 `source` 调用时依次接收工具目录、插件参数、中间 AppImage 路径和 runtime 路径，下载成功后加载通用环境。插件参数支持空字符串、`gtk`、`qt`、`gstreamer`、`gtk,gstreamer` 和 `qt,gstreamer`。GTK / GStreamer 脚本从官方默认分支动态取得并核对 Git blob SHA，Qt 插件继续使用官方 continuous Release。该入口只准备工具，linuxdeploy 的 `--plugin` 参数决定实际启用哪些插件。 直接 appimagetool 封装使用独立执行的 `--appimagetool <appimagetool 输出路径> <runtime 输出路径>`，一次完成两项官方下载、SHA-256 校验和执行权限设置，不下载 linuxdeploy 或插件；原有独立执行和四参数 source 调用保持不变。
- `linuxdeploy/prepare_locale.sh <locale 源名称> <字符集> <完整输出目录>` 只创建输出父目录并执行 `localedef --no-archive`，把 locale 数据写入调用方指定的位置；不安装软件、不修改宿主 locale、不创建 `.env`，也不改写 AppRun。调用方先安装提供 `localedef`、locale 源与字符集数据的 `locales` 包，在应用解包后、正式 linuxdeploy 部署前单行调用；运行时由 AppRun 设置语言变量及 `LOCPATH`。生成失败直接退出，不回退到宿主 locale。 仅为已判定需要的区域环境生成数据；有中文翻译且明确采用中文界面的 GUI 可使用中文参数，CLI 或没有中文翻译的 GUI 不因此强制中文。locale 不包含软件翻译或输入法模块，语言选择与输入支持分别由应用处理，具体边界见 [linuxdeploy 中文配置](../linuxdeploy_projects.md#中文环境与输入法的适用范围)。
- `linuxdeploy/linuxdeploy-plugin-appimage.sh` 是构建时的输出包装入口。工具准备脚本动态下载并校验官方 `linuxdeploy-plugin-appimage`，从资产中只提取原始插件程序为 `appimage-output`，使其从同一目录找到本次下载的 appimagetool；将包装入口安装为工具目录中的 `linuxdeploy-plugin-appimage`，并链接现有图标与权限准备脚本。linuxdeploy 按官方优先级选中外部入口；根 desktop 和图标部署完成后先准备 AppDir，再原样转交参数和 LDAI 环境给官方输出插件。插件类型、API 与帮助查询直接转交官方，不提前处理空 AppDir；直接 `--appimagetool` 模式不下载或安装这些输出文件。说明见 [linuxdeploy 更新兼容](../docs/linuxdeploy-update-compatibility.md)。
- `aur/resolve_deb_source.sh` 接收 AUR 包名、架构、工作目录、元数据输出文件和依赖输出文件；仅接受同名单包 `.SRCINFO` 中唯一的架构专用 HTTPS DEB 与 SHA-256，输出可供 Bash 加载的版本、pkgrel、来源和摘要，以及去版本约束后的运行依赖。浅克隆和解析只在公共入口完成。
- `aur/download_deb_source.sh` 接收 AUR 包名、架构和 DEB 输出文件三个参数。复用上述解析入口，在独立临时目录中读取当前来源与 SHA-256，再调用 `download/download_file.sh` 校验并下载；成功或失败后均清理本次临时元数据。不安装应用、不解包、不替调用方选择版本元数据，也不写死应用名或下载地址。
- `download/download_verified_with_wayback.sh` 接收官方 HTTPS URL、目标文件、原 SHA-256 和可选的 `--deb`；先调用 `download_file.sh`，未取得匹配摘要的文件时才查同一 URL 的 Internet Archive 快照，所有候选文件仍须通过原摘要，`--deb` 还核对 DEB 文件类型。
- `download/download_html_checksum_asset.sh` 接收 HTML 校验表 URL、完整资产名的 Python 正则、资产目录 URL 和输出文件四个参数。只配对同一表格行中的文件名与 SHA-256，按文件名里的点分数字版本选择最高版本；匹配缺失、摘要冲突或最高版本不唯一时退出。页面和资产均通过 `download_file.sh` 下载，stdout 只返回版本，不安装应用或解包。
- `github/install_and_extract_latest_stable_release_deb.sh` 保留原 GitHub 与 `--checksum` 接口，新增 `--html-checksum <HTML 校验表 URL> '<完整资产名的 Python 正则>' <资产目录 URL> <下载 DEB 路径> <解包目录> [DEB 包名] [DEB 架构]`。新模式调用上述 HTML 下载入口，在安装前核对 DEB 实际版本及可选的包名、架构；随后复用公共 APT 和归档入口安装并解包同一份 DEB，全部成功后才返回版本。
- `github/download_latest_stable_named_asset.sh` 接收仓库、固定资产名、目标文件及可选的 DEB 包名和架构。只选择最新正式版本中的唯一资产，核对 GitHub SHA-256；直链失败时用同一资产 ID 和现有认证令牌回退，stdout 仅返回版本。带 `{version}` 的资产仍使用原有模板入口。
- `build/prepare_x86_64_workspace.sh` 接收项目根目录、`--skip-create`、一个清理后不创建的一级目录名，以及其余清理后重建的一级目录名。先检查 x86_64 和全部目录名，再只处理这个项目下明确传入的目录；应用自行决定哪些工作目录需要重建。
- `arch/get_package_version.sh` 接收一个已安装的 Arch 软件包名，从 `pacman -Q` 读取版本并去掉 epoch 和发行版 `pkgrel`，只向 stdout 输出非空的上游版本。需要保留发行版修订号的应用不要调用该入口。
- `build/read_app_version.sh` 统一读取构建版本。`package-json <文件路径>` 用 `jq` 读取根对象的字符串 `version`；`pacman <包名>` 复用 `arch/get_package_version.sh`，保留去掉 epoch 和 pkgrel 的规则。默认只向 stdout 返回非空、无空白字符的版本；可选 `--version-file <路径>` 同步写入构建版本文件，可选 `--desktop <路径>` 仅在该 desktop 缺少 `X-AppImage-Version` 时追加版本。应用在原有版本读取位置保留单行调用；新增来源时扩展公共脚本的来源分支，并补充对应说明和验证。 新增 `command <程序> --field <版本字段编号> -- <程序参数...>` 来源：按指定字段读取程序首行输出，在公共入口校验版本；元数据参数放在 `--` 之前，原三种来源和原参数保持兼容。

- `desktop/write_scheme_hook.sh` 写出 AppImage 启动 hook。hook 把本次实际的 AppImage 路径写成用户级 desktop，`Exec` 使用 `%U`，并且只把调用方传入的协议设为默认程序，不改其它协议的现有默认程序。原因和禁止事项见 [AppImage 自定义协议](../docs/appimage-scheme-handler.md)。

### HTML 校验表中的官方 DEB

适用于官网用 HTML 表格列出文件名与完整 SHA-256、安装包位于独立下载目录的来源。需要 Bash、Python 3 和 `dpkg-deb`；构建依赖及 APT 索引仍由调用方提前准备。表格列顺序不限，文件名和摘要必须分别位于同一行的完整单元格内，可以包含 `code` 或链接等标签。

在应用 build 中使用下面的单行公共调用；将所有 `<…>` 替换为当前来源的实际参数。正则采用 Python 语法，必须包含 `^` 和 `$`，明确软件、稳定版本文件名、平台和架构；不匹配其他组件或预发布包。资产目录是没有查询参数或片段的 HTTPS 目录地址。

```bash
# 下载并校验官方安装包，将其安装到构建环境并解包到 AppDir，成功后返回版本号。
VERSION="$("$SCRIPT_DIR/../common/github/install_and_extract_latest_stable_release_deb.sh" --html-checksum "<官方 HTML 校验表 URL>" '<完整资产名的 Python 正则>' "<官方资产目录 URL>" "$SOURCE_DIR/<软件名>.deb" "$APPDIR" "<DEB 包名>" "<DEB 架构>")"
```

版本来自匹配文件名中的首个点分数字版本，并在安装前与 DEB 的 `Version` 严格核对。匹配的每一行均须有唯一摘要，同一文件重复列出时摘要必须一致；最高数字版本必须只对应一个文件。下载或校验失败不会回退到较旧版本，不会转用页面中的其他链接。包名和架构可以同时省略；传入时必须成对提供。

页面 URL、下载目录、程序名称和版本均不写死在公共脚本内。仅当全部下载、元数据检查、系统安装和解包成功时，stdout 才返回一行版本；调用方不再另写来源解析脚本，也不重复安装、解包或读取版本。

### 可选的最终产物检查与收尾

- `build/check_appimage_artifact.sh` 接收最终 AppImage 路径和 SHA-256 文件路径，确认产物非空且可执行，再以原 `sha256sum | tee` 方式生成校验文件。应用在生成正式产物后自行决定何时调用；图形检查仍独立按需调用。
- `gui/check_appimage_gui.sh` 仅由确有需要的应用显式调用，不是所有 AppImage 的默认步骤。参数依次是最终 AppImage 路径、1～20 秒上限、隔离工作目录、会话顺序（`timeout-dbus-xvfb`、`xvfb-dbus-timeout` 或 `timeout-xvfb`）、成功规则（`timeout-only` 或 `timeout-or-zero`）、调用方的致命日志正则、可选窗口标题正则，以及 `--` 后的应用参数。空窗口标题只检查进程存活和日志，不声称确认了可见窗口；非空标题还要求 Xvfb 中找到存活的可见窗口。调用方可在命令前设置应用专属环境变量，公共入口不添加 `--disable-gpu` 等应用参数。该检查不验证登录、代理、中文输入或实机功能。
- `build/finish_appimage_build.sh` 在调用方完成所有检查后接收版本号、`version.txt` 路径和原成功提示，按顺序写入版本文件并输出提示；不负责打包、图形检查或发布。已有 `common/linuxdeploy/package_appimage.sh` 同时承担封装和版本写入，使用该入口的应用不需要重复调用收尾函数。
- `appimage/prepare_appdir_for_appimagetool.sh` 接收一个 AppDir。拒绝空路径、根目录和无效目录。只对该目录执行 `chmod -R a-s,a+rX`，不沿软链接改包外文件。根目录已有与主 desktop 的 `Icon` 同名的 PNG / XPM 时不覆盖；否则先复制包内同名 PNG，没有 PNG 时再把对应 SVG 转成 256 × 256 的 PNG，并保留原 SVG。转换工具按 `rsvg-convert`、`magick`、`convert` 的顺序选择，Ubuntu 项目可在应用依赖中安装 `librsvg2-bin`；只有实际转换时才需要，不修改统一基础包，也不在本入口安装软件。工具不可用或转换失败则立即退出。`linuxdeploy/package_appimage.sh` 在原封装命令前调用它。不添加 `--no-check-permissions`。上游变更、已有 `.DirIcon` 的回退边界及用途见 [appimagetool 图标检查与 SVG 兼容处理](../docs/appimagetool-icon-compatibility.md)。
- `build/save_appimage_version.sh` 接收最终 AppImage 路径、版本号和 `version.txt` 路径。先确认产物存在且非空，再写入版本。不写 SHA-256，也不打印成功提示。已经分开做产物校验和成功提示的应用不要改成这个入口。

## 2026-09-23 自根目录原样迁入

以下原文来自当时根目录 `PENDING_AI_TASKS.md` 的「后续处理原则」，未改写。

1. 等 AI 有足够额度后再统一继续，不在额度不足或上下文不完整时逐项试错。
2. 开始修改前先一次性读完整相关代码、README、workflow、公共函数和历史问题记录，确认稳定基线、未验证项和禁止重复的失败方向。
3. Wine 的后续修复必须以真实构建产物和实机功能验证为准；构建成功、静态检查通过或代码看起来合理都不能替代实机结论。详见 [wine/README.md](../wine/README.md)。
4. JRiver AppImage 已归档到 [archive/jriver](../archive/jriver/README.md)，不再构建。两条旧路线的修复记录仍留在该目录，没有新证据不重复已经失败的包装实验。
5. 公共函数审计应一次覆盖公共实现和所有相关调用方；确认完整 diff 后再修改，避免反复小提交和依赖 GitHub Actions 失败结果试错。
