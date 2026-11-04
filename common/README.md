# common

应用构建脚本只单行调用这里的公共入口。某个软件的修复记录不要写到这里，写回该软件目录。

## 公共代码与公共函数

- `common/` 当前包含 `apt/`、`archive/`、`aur/`、`build/`、`config/`、`desktop/`、`download/`、`github/`、`gui/`、`linuxdeploy/` 等目录。本项只是标记为**需要后续重新完整审计**，不是认定这些公共实现当前一定有错误。
- 后续 AI 需要从调用方和公共实现两端一起检查，不能只看某一个 helper：确认职责边界是否正确、是否存在重复通用逻辑、参数语义是否一致、错误处理与返回码是否可靠、下载 / 校验 / DEB 元数据 / 解包 / linuxdeploy 初始化与最终封装是否由正确层负责。
- 重点检查近期从 PeaZip 等项目下沉到公共函数的逻辑，确认没有把应用专用规则错误公共化，也没有让应用脚本重复做公共入口已经负责的检查。
- 已经由用户明确确认有效的命令、调用顺序、AppRun 行为和打包基线必须逐字保留；公共化不能成为顺手重写这些稳定内容的理由。
- 必须同时检查所有受影响调用方，避免只修公共函数后才逐个发现调用参数、路径、返回值或行为不兼容。
- `archive/check_deb_metadata.sh <DEB 文件> <预期版本或空字符串> <预期包名或空字符串> <预期架构或空字符串>` 独立核对本地 DEB 的 `Version`、`Package`、`Architecture`，成功时无 stdout 输出；空的预期值跳过对应字段，至少指定一项。JSON、签名 APT、GitHub 资产和 HTML DEB 安装入口内部复用它，原参数、版本返回和各自校验范围保持不变。完整使用边界见下文。
- `archive/extract_archive.sh` 统一支持 DEB、Snap、tar 系列归档、Brotli 压缩的 `.distro` tar 包、ZIP 和 NSIS 安装包；应用脚本只传入归档文件与输出目录，应用专用的文件定位和目录调整仍留在应用脚本。ZIP 由 `unzip` 解包，`.exe` 安装包由 `7z` 提取内容，不执行安装程序；调用方提前提供所需工具，原有格式及两个参数的接口保持不变。
- `apt/extract_installed_package.sh <主软件包名> <AppDir> [附加软件包名 ...]` 先读取各包的已安装版本，再逐包下载同一版本并按原布局解包；成功后仅向 stdout 返回主软件包去掉 epoch / revision 的版本号。安装由调用方提前完成，本入口不重新安装软件。原有两个参数的调用保持兼容。
- `source linuxdeploy/prepare_build_workspace.sh <构建根目录> <产物名> --temporary-source` 显式使用独立临时源目录，退出时清理。构建根目录下重建 `AppDir` 和 `dist`，保留已有 `source`。该模式需要由公共入口设置 EXIT trap。原两参数模式继续使用构建根目录下的 `source`。
- `linuxdeploy/prepare_linuxdeploy_tools.sh` 独立执行时接收工具目录和可选的插件参数；通过 `source` 调用时依次接收工具目录、插件参数、中间 AppImage 路径和 runtime 路径，下载成功后加载通用环境。插件参数支持空字符串、`gtk`、`qt`、`gstreamer`、`gtk,gstreamer` 和 `qt,gstreamer`。GTK / GStreamer 脚本从官方默认分支动态取得并核对 Git blob SHA，Qt 插件继续使用官方 continuous Release。该入口只准备工具，linuxdeploy 的 `--plugin` 参数决定实际启用哪些插件。 直接 appimagetool 封装使用独立执行的 `--appimagetool <appimagetool 输出路径> <runtime 输出路径>`，一次完成两项官方下载、SHA-256 校验和执行权限设置，不下载 linuxdeploy 或插件；原有独立执行和四参数 source 调用保持不变。 直接封装可额外传入 `--release-ref latest`，从两个工具仓库各自的 `/releases/latest` 获取资产，校验摘要后只给 appimagetool 设置执行权限。未传此选项时直接封装继续读取 `continuous`。
- `linuxdeploy/copy_nss_runtime.sh <目标 lib 目录> [--with-nspr]` 默认继续复制同一 Debian / Ubuntu 环境的 13 个 NSS 核心库、动态加载模块及校验文件，原单参数调用和复制清单保持不变。只有显式传入 `--with-nspr` 时才额外复制 `libnspr4.so`、`libplc4.so`、`libplds4.so`，形成完整 16 文件集合；不安装依赖、不改启动环境、不替调用方执行符号版本检查。`libnssckbi.so`、`libnssdbm3.so`、`libsoftokn3.so` 及后两者的 `.chk` 优先从完整的 `/usr/lib/<multiarch>/nss/` 取得；该组不完整时，整组改用 `/usr/lib/<multiarch>/`，不跨目录拼接。调用方须提前安装对应运行库及提供 `dpkg-architecture` 的工具，源文件缺失时直接失败。
- `linuxdeploy/prepare_locale.sh <locale 源名称> <字符集> <完整输出目录>` 只创建输出父目录并执行 `localedef --no-archive`，把 locale 数据写入调用方指定的位置；不安装软件、不修改宿主 locale、不创建 `.env`，也不改写 AppRun。调用方先安装提供 `localedef`、locale 源与字符集数据的 `locales` 包，在应用解包后、正式 linuxdeploy 部署前单行调用；运行时由 AppRun 设置语言变量及 `LOCPATH`。生成失败直接退出，不回退到宿主 locale。 仅为已判定需要的区域环境生成数据；有中文翻译且明确采用中文界面的 GUI 可使用中文参数，CLI 或没有中文翻译的 GUI 不因此强制中文。locale 不包含软件翻译或输入法模块，语言选择与输入支持分别由应用处理，具体边界见 [linuxdeploy 中文配置](../linuxdeploy_projects.md#中文环境与输入法的适用范围)。
- `linuxdeploy/linuxdeploy-plugin-appimage.sh` 是构建时的输出包装入口。工具准备脚本动态下载并校验官方 `linuxdeploy-plugin-appimage`，从资产中只提取原始插件程序为 `appimage-output`，使其从同一目录找到本次下载的 appimagetool；将包装入口安装为工具目录中的 `linuxdeploy-plugin-appimage`，并链接现有图标与权限准备脚本。linuxdeploy 按官方优先级选中外部入口；根 desktop 和图标部署完成后先准备 AppDir，再原样转交参数和 LDAI 环境给官方输出插件。插件类型、API 与帮助查询直接转交官方，不提前处理空 AppDir；直接 `--appimagetool` 模式不下载或安装这些输出文件。说明见 [linuxdeploy 更新兼容](../docs/linuxdeploy-update-compatibility.md)。
- `aur/resolve_deb_source.sh` 接收 AUR 包名、架构、工作目录、元数据输出文件和依赖输出文件；默认仅接受同名单包 `.SRCINFO` 中唯一的架构专用 HTTPS DEB 及对应的完整摘要。优先沿用 SHA-256，仅在当前架构没有 SHA-256 时读取 SHA-512；无效或 `SKIP` 的 SHA-256 不会因存在 SHA-512 而被跳过。输出可供 Bash 加载的版本、pkgrel、来源、带算法前缀的 `SOURCE_CHECKSUM`，以及去版本约束后的运行依赖。SHA-256 来源继续输出原有 `EXPECTED_SHA256` 字段；SHA-512 来源不输出空的同名字段，新调用统一读取 `SOURCE_CHECKSUM`。不执行 PKGBUILD，不把其他架构或通用 source 的摘要配给当前 DEB。浅克隆和解析只在公共入口完成。 显式传入 `--with-source-filename` 时才输出 `SOURCE_FILENAME`；按同次 source 的 `名称::URL` 别名或 URL 末段取名，并拒绝空名、路径和换行。原五参数调用不新增字段。可显式传入 `--source-filename <DEB 文件名>`，在通用与当前架构来源中按缓存文件名唯一匹配，并按该组的原索引读取摘要。文件名可用 `{version}` 代表同次快照的 `pkgver`。
- `aur/download_deb_source.sh` 接收 AUR 包名、架构和 DEB 输出文件三个参数。复用上述解析入口，在独立临时目录中读取当前来源和 `SOURCE_CHECKSUM`，再调用 `download/download_file.sh` 按指定算法校验并下载；成功或失败后均清理本次临时元数据。原有三个参数保持不变，不安装应用、不解包、不替调用方选择版本元数据，也不写死应用名或下载地址。 可在三个位置参数后显式启用 `--user-agent`、`--downloader`、`--wayback`、`--deb`、`--version-file`、`--package-version-file`、`--makepkg-source-dir` 和 `--source-filename`；不传选项的调用保持原行为，详见下文。
- `aur/install_and_extract_deb_source.sh` 接收 AUR 包名、AUR 架构、来源工作目录、DEB 路径、解包目录、预期 DEB 包名和 DEB 架构。组合现有来源解析、摘要下载、版本读取、元数据校验、APT 安装和归档解包入口；全部成功后仅向 stdout 返回一行实际版本。保留同次 AUR 快照、来源元数据和依赖清单，不执行 PKGBUILD，也不改旧入口。参数与使用边界见下文。
- `aur/download_tar_source.sh <AUR 包名> <架构> <输出.tar.gz> <元数据输出文件>` 从同次 `.SRCINFO` 读取唯一的架构专用 HTTPS tar.gz 来源和 BLAKE2b-512 摘要。摘要缺失、无效或为 `SKIP` 时拒绝下载；校验通过后写入归档及可由 Bash 读取的版本、pkgrel 和来源元数据。现有 DEB 入口继续使用原调用方式。
- `download/download_file.sh <HTTPS URL> <输出文件> [摘要] [User-Agent] [curl|wget|aria2c]` 保留原下载、重试、超时和原子替换行为。不传摘要时保持原行为；无前缀的 64 位十六进制摘要和 `sha256:<摘要>` 使用 SHA-256，新增的 `sha512:<128 位十六进制摘要>` 使用 SHA-512，`blake2b:<128 位十六进制摘要>` 使用 GNU `b2sum` 校验 BLAKE2b-512。摘要格式错误或校验失败时不替换已有输出文件。该扩展不改变其他专用下载入口各自的摘要格式。 第四个可选参数指定客户端标识，显式值优先；省略或传空字符串时，curl / wget 保留原默认标识，aria2c 使用仓库公共配置中的标识；不校验摘要而指定客户端标识时，第三个参数传空字符串。客户端标识包含回车或换行时拒绝下载。第五个可选参数显式选择下载器，默认仍为 `curl`；`wget` 共用原摘要校验、失败清理和原子替换，只用于直达 HTTPS 文件，不跟随重定向。该模式需要已有 `wget` 和 GNU `timeout`，总时限 900 秒，保留证书校验并使用 TLS 1.2；不读取 wget 配置或 netrc，不写 HSTS 文件。 `aria2c` 显式读取 [公共 HTTP 下载配置](./config/download/aria2.conf)，单服务器连接上限和分段数均为 16，最小分段和分块大小均为 1M；配置包含公开的模拟浏览器标识、IPv4 和 gzip 请求设置。它不读取个人 aria2 配置或 netrc；总时限仍为 900 秒，默认 TLS、证书校验、临时输出、原摘要校验、原子替换和失败清理保持不变，不自动跟随 Torrent / Metalink。公共配置按用途归类，规则见 [配置目录](./config/README.md)。
- `download/download_apt_repository_deb.sh` 从调用方指定的 HTTPS APT 仓库读取签名索引，使用指定的官方密钥验证 `InRelease`，核对索引与 DEB 的 SHA-256、大小，以及 DEB 的包名、架构和版本；按 Debian 版本规则选择最高版本，成功后写入 DEB 与来源版本文件，stdout 只返回版本。不安装应用、不配置系统 APT 源；现有下载、版本读取和归档接口保持不变。完整参数与支持范围见下文。
- `download/download_omaha_package.sh` 查询 Omaha 3.0 XML 更新服务，按调用方提供的应用 ID、渠道、平台、架构、下载源、路径前缀和文件名规则选择完整安装包，复用 `download_file.sh` 校验 SHA-256，并核对响应中的文件大小。成功后写入指定的安装包和版本文件，stdout 只返回版本；不安装或执行软件。完整参数、约束及调用方式见下文。
- `download/download_verified_with_wayback.sh` 接收官方 HTTPS URL、目标文件、原 SHA-256 或显式带 `sha512:` 前缀的 SHA-512 和可选的 `--deb`、`--user-agent <客户端标识>`、`--downloader curl|wget|aria2c`；先调用 `download_file.sh`，未取得匹配摘要的文件时才查同一 URL 的 Internet Archive 快照，所有候选文件仍须通过原摘要，`--deb` 还核对 DEB 文件类型。 这些选项可以组合使用；`--downloader` 只选择官方文件的下载器，CDX 与归档请求继续使用原 curl 入口。指定的客户端标识统一传给官方文件、快照列表和归档文件请求；未指定时，官方文件使用所选下载器的默认或公共配置标识，CDX 与归档文件使用 curl 默认标识。客户端标识为空、包含回车或换行、选项重复或参数缺失时退出。
- `download/download_html_checksum_asset.sh` 可选接收前置参数 `--json-html <HTML 字段路径>`，随后接收 HTML 校验表或 JSON API 的 URL、完整资产名的 Python 正则、资产目录 URL 和输出文件四个参数。只配对同一表格行中的文件名与 SHA-256，按文件名里的点分数字版本选择最高版本；匹配缺失、摘要冲突或最高版本不唯一时退出。指定 JSON 模式时只读取该字段的非空 HTML 字符串，再执行同一套表格解析；不自动猜测字段。来源和资产均通过 `download_file.sh` 下载，stdout 只返回版本，不安装应用或解包。
- `github/install_and_extract_latest_stable_release_deb.sh` 保留原 GitHub 与 `--checksum` 接口，提供 `--html-checksum [--json-html <HTML 字段路径>] <校验来源 URL> '<完整资产名的 Python 正则>' <资产目录 URL> <下载 DEB 路径> <解包目录> [DEB 包名] [DEB 架构]`。新模式调用上述 HTML 下载入口，在安装前核对 DEB 实际版本及可选的包名、架构；随后复用公共 APT 和归档入口安装并解包同一份 DEB，全部成功后才返回版本。
- `github/download_latest_stable_named_asset.sh` 接收仓库、固定资产名、目标文件及可选的 DEB 包名和架构。只选择最新正式版本中的唯一资产，核对 GitHub SHA-256；直链失败时用同一资产 ID 和现有认证令牌回退，stdout 仅返回版本。带 `{version}` 的资产仍使用原有模板入口。
- `github/resolve_latest_stable_release_asset.sh [--tag-prefix <标签前缀>] <owner/repo> '<固定资产名或含 {version} 的资产名模板>'` 保留原正式版本、唯一资产和 GitHub SHA-256 选择规则。只有显式传入前置的 `--tag-prefix` 时，才按字面值匹配并移除该非空前缀，再解析余下的可选 `v` 与点分数字版本；前缀不得含空白字符。`github/download_latest_stable_release_asset.sh` 同样在仓库名之前接受该选项，随后仍传入仓库、资产名模板、输出文件和可选的成对 DEB 包名、架构。下载、摘要校验、DEB 身份检查及只向 stdout 返回版本的行为不变；不传选项的旧调用保持原规则。前缀模式不能与 `--latest-with-checksum` 混用。 资产名可以是固定文件名，也可以包含 `{version}`；两者共用同一正式版本筛选、唯一资产匹配和 GitHub SHA-256 校验，固定名不另设应用特判。
- `github/download_latest_stable_release_asset.sh <owner/repo> '<包含 {version} 的资产名模板>' <输出文件> --latest-with-checksum <校验清单资产名> <commit 文件>` 从同一个 `/releases/latest` 响应定位主资产和校验清单，验证两者的 GitHub SHA-256，再用清单中唯一对应的 SHA-256 校验主资产。校验通过并解析 tag 对应的 Git commit 后，写出资产和 commit，stdout 仅返回版本。原资产模板及可选 DEB 参数调用保持原有语义。
- `build/prepare_x86_64_workspace.sh` 接收项目根目录、`--skip-create`、一个清理后不创建的一级目录名，以及其余清理后重建的一级目录名。先检查 x86_64 和全部目录名，再只处理这个项目下明确传入的目录；应用自行决定哪些工作目录需要重建。
- `arch/install_packages.sh` 保留 `--base` 和普通包名调用。只有显式指定 `--aur-deb <AUR 包名> <架构> [--user-agent <客户端标识>] [--downloader curl|wget|aria2c] [--wayback] [--source-filename <DEB 文件名>] -- [额外软件包...]` 时，才先安装额外软件包、复用公共 AUR 下载入口准备已校验 DEB，再交由 yay / makepkg 按原 PKGBUILD 校验和安装；使用独立来源缓存及构建目录，详见下文。
- `arch/get_package_version.sh` 接收一个已安装的 Arch 软件包名，从 `pacman -Q` 读取版本并去掉 epoch 和发行版 `pkgrel`，只向 stdout 输出非空的上游版本。需要保留发行版修订号的应用不要调用该入口。
- `build/read_app_version.sh` 统一读取构建版本。`package-json <文件路径>` 用 `jq` 读取根对象的字符串 `version`；`pacman <包名>` 复用 `arch/get_package_version.sh`，保留去掉 epoch 和 pkgrel 的规则。默认只向 stdout 返回非空、无空白字符的版本；可选 `--version-file <路径>` 同步写入构建版本文件，可选 `--desktop <路径>` 仅在该 desktop 缺少 `X-AppImage-Version` 时追加版本。应用在原有版本读取位置保留单行调用；新增来源时扩展公共脚本的来源分支，并补充对应说明和验证。 新增 `command <程序> --field <版本字段编号> -- <程序参数...>` 来源：按指定字段读取程序首行输出，在公共入口校验版本；元数据参数放在 `--` 之前，原三种来源和原参数保持兼容。

- `desktop/write_scheme_hook.sh` 写出 AppImage 启动 hook。hook 把本次实际的 AppImage 路径写成用户级 desktop，`Exec` 使用 `%U`，并且只把调用方传入的协议设为默认程序，不改其它协议的现有默认程序。原因和禁止事项见 [AppImage 自定义协议](../docs/appimage-scheme-handler.md)。

### AUR 来源的独立 DEB 下载

入口为 `aur/download_deb_source.sh`，前三个位置参数继续是 AUR 包名、架构和 DEB 输出文件。默认仍只解析当前唯一来源、按原算法校验下载并清理临时元数据；不自动启用归档、不改变 curl 默认标识、不新增版本检查或版本输出，也不安装或解包应用。旧调用的 stdout 和返回状态保持原有语义。

| 可选参数 | 行为 |
| --- | --- |
| `--user-agent <客户端标识>` | 透传给公共下载入口；归档模式同时用于官方文件、CDX 列表和归档文件。空值、重复参数、回车或换行会被拒绝。 |
| `--downloader <下载器>` | 显式选择官方文件下载器，省略时仍为 curl；可显式选择 wget 或 aria2c。wget 适用于直达 HTTPS 文件，aria2c 读取仓库公共 HTTP 下载配置。摘要校验和来源缓存不变，CDX 与归档请求保持原 curl 行为；重复、空值或未知值在联网前拒绝。 |
| `--source-filename <DEB 文件名>` | 在通用 `source` 和当前架构 `source_<arch>` 中按 makepkg 缓存文件名精确选择一项。支持 `名称::URL` 别名及 `{version}` 占位符。只读取匹配来源组同索引的摘要，来源重复、数组长度不符或选中摘要无效时失败。 |
| `--wayback` | 官方文件未通过原摘要时，复用既有归档入口查同一 URL；SHA-256 和显式 SHA-512 均保持原摘要，不改来源或降低版本。 |
| `--deb` | 下载后通过公共 DEB 元数据入口核对实际完整 Version 与同次 AUR pkgver 相同；不校验调用方未提供的包名或 DEB 架构。 |
| `--version-file <文件>` | 在上述版本核对通过后写入 pkgver，供公共版本读取入口使用。 |
| `--package-version-file <文件>` | 同样核对实际 DEB 版本后，写入同次 AUR 的 `pkgver-pkgrel`，供应用判断程序副本是否需要刷新。 |
| `--makepkg-source-dir <目录>` | 在所有请求的摘要与元数据校验通过后，以同次来源的原文件名或 source 别名原子写入 makepkg 来源缓存，权限 0644；不执行 makepkg、不安装应用。目录不能是根目录或已有普通文件，缓存文件不能与版本输出重合。 |

以下为需要归档和版本文件的组合示例；尖括号参数均按实际来源替换。架构仍由调用方明确提供，客户端标识不在公共代码中固定：

```bash
# 从同次 AUR 来源下载并校验 DEB，按需启用客户端标识、归档和版本输出。
"$SCRIPT_DIR/../common/aur/download_deb_source.sh" "<AUR 包名>" "<AUR 架构>" "<DEB 输出文件>" --user-agent "<客户端标识>" --wayback --deb --version-file "<来源版本文件>" --package-version-file "<完整包版本文件>"
```

请求任意版本输出时都会校验实际 DEB Version 与 AUR pkgver 完全一致；epoch、预发布或版本改写不做自动裁剪，不能满足该规则的来源不能直接启用这些选项。pkgrel 只写入完整包版本文件，不拼到 DEB Version 上比较。摘要或元数据校验失败时保留已有版本文件；两个版本目标分别通过同目录临时文件替换，不能与 DEB 输出或彼此重合。stdout 仍沿用下载入口的日志，不改成只返回版本。

归档和实际 DEB 检查依赖对应公共入口原有工具；调用方提前准备依赖。本入口继续不执行 PKGBUILD、不安装应用、不新增软件源，也不影响下述 APT 组合入口。

### Arch 安装时复用已校验的 AUR DEB

入口为 `arch/install_packages.sh` 的显式 `--aur-deb` 模式。默认读取唯一的架构专用 DEB。配方包含通用来源或多个文件时，可以显式传入 `--source-filename` 选择主 DEB。其他来源由原配方下载和校验。安装阶段也可按需传入 `--downloader curl|wget|aria2c`，以及公共下载的客户端标识或同 URL 归档能力。其他 AUR 包可继续使用原包名接口。

```bash
# 安装阶段先校验官方来源，再按原 AUR PKGBUILD 安装应用及依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --aur-deb "<AUR 包名>" "<架构>" --user-agent "<客户端标识>" --wayback -- "<额外软件包>"
```

`--` 必须提供，用于分隔下载选项和额外包名；额外包名可以为空。先用原 yay 参数安装额外软件包，再调用 `aur/download_deb_source.sh --makepkg-source-dir`，不复制来源解析、摘要或归档实现。下载选项只在显式传入时启用。应用仍通过 `yay -S --noconfirm --needed` 安装，原 PKGBUILD、所有来源摘要及依赖处理保持生效；没有跳过 makepkg 校验，也不改 AUR 文件。

本次 yay 通过 `SRCDEST` 读取已校验文件，并用 `--builddir` 指向新的独立构建目录。两者需要同时使用：makepkg 优先读取 PKGBUILD 所在目录中的同名源文件，旧目录中的错误响应会盖过正确的来源缓存。临时根目录权限为 0711，两个子目录为带粘滞位的 01777，仅限本次缓存和构建目录，供构建环境的非 root 用户使用；不固定用户名，不改 yay 全局配置。构建环境的 yay 包装器须保留传入环境，当前共享 Action 的 `sudo -HE` 满足此条件。

额外包安装、下载或应用安装失败时直接返回失败；退出时只删除本次创建的临时目录。该入口不写应用版本文件、不代替后续独立下载，也不改 AppDir 或封装流程。原 `--base` 包清单、普通包名调用和下述 APT 组合入口保持原行为。

依据：[makepkg 的来源缓存](https://man.archlinux.org/man/makepkg.conf.5.en#OPTIONS)、[makepkg 环境与来源校验](https://man.archlinux.org/man/makepkg.8.en#ENVIRONMENT_VARIABLES)、[yay 的 builddir](https://github.com/Jguer/yay/blob/0938a75e98e63648ebf6e22ece6b4a30ec11a907/doc/yay.8)。官方定义了缓存与构建目录的用途；这里的预下载衔接属于本仓库兼容处理。

### AUR 来源中的官方 DEB

入口为 `aur/install_and_extract_deb_source.sh`。在应用 build 的“下载并准备应用”阶段单行调用，依次传入 AUR 包名、AUR 架构、来源工作目录、下载 DEB 路径、解包目录、预期 DEB 包名和 DEB 架构，共七项。所有参数均由调用方明确提供；AUR 与 DEB 的架构名称分别传入，不在公共代码中猜测映射关系或固定应用。

```bash
# 下载并校验官方安装包，将其安装到构建环境并解包到 AppDir，成功后返回版本号。
VERSION="$("$SCRIPT_DIR/../common/aur/install_and_extract_deb_source.sh" "<AUR 包名>" "<AUR 架构>" "$SOURCE_DIR" "$SOURCE_DIR/<软件名>.deb" "$APPDIR" "<DEB 包名>" "<DEB 架构>")"
```

示例中的 `<…>` 须按本次实际来源替换。调用方先通过现有工作区入口准备来源目录，再通过公共 APT 入口安装构建依赖并更新索引；本入口安装本地 DEB 时使用 `--no-update`。依赖沿用现有子入口所需的 Bash、git、curl、dpkg-deb、APT 及基础工具，不另外安装 Arch 环境。

来源选择继续由 `resolve_deb_source.sh` 负责：仅接受同名单包、唯一的架构专用 HTTPS DEB 和对应的有效摘要；沿用 SHA-256 优先及 SHA-512 兼容规则，不执行 PKGBUILD 或 makepkg。下载继续复用 `download_file.sh`；版本读取和包身份核对分别复用 `build/read_app_version.sh`、`archive/check_deb_metadata.sh`。本入口要求 DEB 完整 Version 与 AUR `pkgver` 精确一致，且实际包名、架构与传入值一致；AUR `pkgrel` 不作为 DEB 版本的修订号。版本改写或与此规则不符的 AUR 包不能直接套用该入口。

元数据校验通过后，使用同一份 DEB 依次完成系统安装和原布局解包。只在全部步骤成功后返回一行版本；下载、摘要、版本、包名、架构、安装或解包失败时直接退出，不返回成功版本、不继续后续步骤。日志写入 stderr，应用不再重复解析来源、读取版本、校验、安装或解包。系统安装失败可能留下包管理器的中间状态，解包失败可能留下已写出的文件；本入口不自动回滚这些操作。

来源目录会保留 `<来源工作目录>/<AUR 包名>/`、`source.env` 和 `dependencies.txt`，供应用专属补丁使用同次桌面资源与依赖清单；再次调用时沿用解析入口的规则，重新取得该 AUR 包目录并更新两份元数据。解包目录须与来源工作目录分开；应用的目录布局调整、桌面资源修复及运行库处理仍放在自身 `patches/`。这里的版本返回不写最终 `dist/version.txt`，最终版本保存继续由原封装入口负责。

旧 `aur/resolve_deb_source.sh` 和三参数 `aur/download_deb_source.sh` 的参数、输出、清理与下载行为保持不变；既有应用不会自动转用新入口。本次只补公共组合能力，不变更应用 build、AppRun 或 workflow。

### 本地 DEB 元数据校验

入口为 `archive/check_deb_metadata.sh`，依赖 Bash 和 `dpkg-deb`。四个位置参数依次是 DEB 文件、预期完整版本、预期包名、预期架构；不检查的字段传空字符串，至少指定一项。只读取指定字段并逐字比较，保留版本的 epoch、预发布标记和 Debian 修订号，不把 Release tag 或文件名猜作 DEB 版本。

来源入口已核对这些字段时，应用不要再次校验。仅当当前下载入口不负责 DEB 身份检查时，在安装或解包前单行调用；所有预期值由调用方根据已核实的本次来源传入，不在公共脚本中固定应用名称或架构。

```bash
# 安装前核对本次来源对应的 DEB 完整版本、包名和架构。
"$SCRIPT_DIR/../common/archive/check_deb_metadata.sh" "<DEB 文件>" "<预期完整版本>" "<预期包名>" "<预期架构>"
```

成功时返回 0 且不输出内容；参数数量错误或三个预期值全空时返回 2，文件无法读取、字段不符或工具失败时返回非零状态，诊断写入 stderr。本入口不下载、安装、解包、修改文件或执行包内维护脚本；元数据相符也不能代替官方来源和摘要校验。

兼容范围：JSON 下载入口仍核对三个字段；签名 APT 下载入口仍核对签名索引对应的三个字段，全部成功后才替换输出。GitHub 固定资产名与版本模板入口仍仅在显式提供包名和架构时核对这两项，不强求 DEB Version 与 Release tag 一致，也保留未指定检查时下载其他资产的能力。HTML DEB 安装入口仍核对版本及调用方传入的可选包名、架构，失败时不会进入安装与解包；原 GitHub、`--checksum` 和 `--json-html` 调用参数及版本 stdout 均保持原样。

### 签名 APT 仓库中的官方 DEB

入口为 `download/download_apt_repository_deb.sh`，依赖 Bash、Python 3、curl、GnuPG（`gpg`、`gpgv`）、`dpkg` 和 `dpkg-deb`。调用方提前准备依赖；脚本只查询和下载，不安装应用、不执行维护脚本、不添加系统软件源，也不读写宿主机的 GnuPG 密钥目录。

参数依次为：HTTPS 仓库根地址、suite、component、DEB 包名、架构、HTTPS 官方公钥地址、DEB 输出文件和来源版本文件，共八项。应用名称、仓库、密钥、渠道、架构和输出路径均由调用方指定；不存在内置应用或固定版本。下面的调用放在应用 build 中，所有 `<…>` 均须按当前官方来源替换。

```bash
# 下载并校验官方 APT 仓库中的当前 DEB，同时记录来源版本。
"$SCRIPT_DIR/../common/download/download_apt_repository_deb.sh" "<HTTPS 仓库根地址>" "<suite>" "<component>" "<DEB 包名>" "<架构>" "<HTTPS 官方公钥地址>" "<DEB 输出文件>" "<来源版本文件>"
```

支持常规 `dists/<suite>/` 布局中的 `InRelease`，以及所选 component、架构对应的 Packages、Packages.xz、Packages.gz；优先使用明文索引，缺少该记录时才选择 XZ 或 gzip。索引中的 DEB 路径须位于仓库根目录下的 `pool/`。不支持 flat 仓库、未签名仓库或仅提供 `Release` 与独立签名的来源，不自动切换其他仓库。

公钥地址须来自调用方核实的官方来源，可提供二进制或 ASCII armored 公钥。先验证签名，再核对 suite、component 和架构；存在 `Valid-Until` 时同时检查有效期。Packages 的摘要与大小取自已验证的 Release；仓库声明 `Acquire-By-Hash: yes` 时使用相应摘要地址，避免索引更新时混入其他快照。签名、索引摘要或下载失败时直接退出，不关闭校验，也不退回其他格式或旧版本。

只匹配传入的包名和精确架构，不自动改用其他架构或 `all` 包；版本通过 `dpkg` 校验并比较，保留 epoch、预发布标记和 Debian 修订号。同一版本的路径、摘要或大小冲突，以及最高版本存在多种等价写法时直接失败。最终 DEB 必须同时符合签名索引中的 SHA-256、大小、Package、Architecture 和 Version。

全部校验通过后才替换两个输出文件。参数、元数据、签名、下载或校验失败时保留已有 DEB 和来源版本文件，并清理本次临时目录；下载仍复用原有 `download_file.sh` 的重试、超时及摘要处理。成功时 stdout 只有一行版本，诊断和摘要日志写入 stderr。

来源版本文件只描述本次实际下载的 DEB，可在打包元数据阶段用原有 `build/read_app_version.sh text "<来源版本文件>"` 读取；不能代替最终 AppImage 生成后才写入的 `dist/version.txt`。安装和解包继续由调用方分别使用已有公共入口完成。本次新增入口不改变旧接口和既有应用调用。

### Omaha 更新服务中的完整安装包

适用于 Omaha 3.0 XML 更新服务提供完整安装动作、包名、大小和 SHA-256 的来源。入口依赖 Bash、Python 3 和 curl；应用 ID、渠道、系统信息、来源限制及输出位置全部由调用方传入，不在公共代码中写死应用名称或下载域名。它只查询和下载，不运行安装动作中的程序或参数。

参数依次为：服务 URL、应用 ID、渠道、平台、系统版本、架构、允许的 HTTPS 源、解码后的目录前缀、安装包文件名正则、安装包输出文件、版本输出文件。所有参数均须非空。版本文件是下载阶段的来源元数据，不能代替最终 AppImage 成功后生成的 `dist/version.txt`。

在应用 build 中单行调用；将所有 `<…>` 替换为当前来源的实际参数。文件名使用 Python 正则，必须包含 `{version}`，该占位符以响应版本的字面值替换后匹配完整文件名。其他正则量词不变，不接受路径、差分包或与安装动作不匹配的包。

```bash
# 查询当前版本，校验并下载完整安装包，同时记录来源版本。
VERSION="$("$SCRIPT_DIR/../common/download/download_omaha_package.sh" "<服务 URL>" "<应用 ID>" "<渠道>" "<平台>" "<系统版本>" "<架构>" "<允许的 HTTPS 源>" "<解码后的目录前缀>" '<文件名正则，包含 {version}>' "<安装包输出文件>" "<版本输出文件>")"
```

允许的 HTTPS 源只包含协议、主机和可选端口；目录前缀必须是解码后以 `/` 开始并结束的规范目录。响应须包含唯一匹配所请求应用 ID 的条目和唯一完整安装动作，并且只能有一个地址同时符合下载源和目录限制；不选择不确定的包或自动切换其他来源。

SHA-256 接受 64 位十六进制或解码后恰为 32 字节的标准 / URL 安全 Base64；大小必须为正整数，版本须为一至四段点分数字。无更新、状态错误、匹配不唯一、元数据缺失、摘要无效、下载失败或大小不符均直接失败；协议、下载或校验失败时不覆盖已有安装包与版本文件。下载使用隔离临时目录，退出时清理本次临时文件。

### HTML 校验表中的官方 DEB

适用于官网用 HTML 表格列出文件名与完整 SHA-256、安装包位于独立下载目录的来源。需要 Bash、Python 3 和 `dpkg-deb`；构建依赖及 APT 索引仍由调用方提前准备。表格列顺序不限，文件名和摘要必须分别位于同一行的完整单元格内，可以包含 `code` 或链接等标签。

在应用 build 中使用下面的单行公共调用；将所有 `<…>` 替换为当前来源的实际参数。正则采用 Python 语法，必须包含 `^` 和 `$`，明确软件、稳定版本文件名、平台和架构；不匹配其他组件或预发布包。资产目录是没有查询参数或片段的 HTTPS 目录地址。

```bash
# 下载并校验官方安装包，将其安装到构建环境并解包到 AppDir，成功后返回版本号。
VERSION="$("$SCRIPT_DIR/../common/github/install_and_extract_latest_stable_release_deb.sh" --html-checksum "<官方 HTML 校验表 URL>" '<完整资产名的 Python 正则>' "<官方资产目录 URL>" "$SOURCE_DIR/<软件名>.deb" "$APPDIR" "<DEB 包名>" "<DEB 架构>")"
```

版本来自匹配文件名中的首个点分数字版本，并在安装前与 DEB 的 `Version` 严格核对。匹配的每一行均须有唯一摘要，同一文件重复列出时摘要必须一致；最高数字版本必须只对应一个文件。下载或校验失败不会回退到较旧版本，不会转用页面中的其他链接。包名和架构可以同时省略；传入时必须成对提供。

若官网公开 API 将同一校验表放在 JSON 字段中，在 `--html-checksum` 后添加 `--json-html "<HTML 字段路径>"`，并将来源 URL 替换为官方 API 地址。字段路径由点分隔的对象键组成；字段缺失、JSON 无效、值不是非空字符串或表格无有效匹配时直接失败，不回退网页、不猜测字段，也不关闭 SHA-256 校验。原来的普通 HTML、GitHub 和 `--checksum` 调用保持兼容。

页面 URL、JSON 字段、下载目录、程序名称和版本均不写死在公共脚本内。仅当全部下载、元数据检查、系统安装和解包成功时，stdout 才返回一行版本；调用方不再另写来源解析脚本，也不重复安装、解包或读取版本。

### 可选的最终产物检查与收尾

- `build/check_appimage_artifact.sh` 接收最终 AppImage 路径和 SHA-256 文件路径，确认产物非空且可执行，再以原 `sha256sum | tee` 方式生成校验文件。应用在生成正式产物后自行决定何时调用；图形检查仍独立按需调用。
- `gui/check_appimage_gui.sh` 仅由确有需要的应用显式调用，不是所有 AppImage 的默认步骤。参数依次是最终 AppImage 路径、1～20 秒上限、隔离工作目录、会话顺序（`timeout-dbus-xvfb`、`xvfb-dbus-timeout` 或 `timeout-xvfb`）、成功规则（`timeout-only` 或 `timeout-or-zero`）、调用方的致命日志正则、可选窗口标题正则，以及 `--` 后的应用参数。空窗口标题只检查进程存活和日志，不声称确认了可见窗口；非空标题还要求 Xvfb 中找到存活的可见窗口。调用方可在命令前设置应用专属环境变量，公共入口不添加 `--disable-gpu` 等应用参数。该检查不验证登录、代理、中文输入或实机功能。
- `linuxdeploy/package_appimage.sh` 可在显式传入版本号与版本文件路径后，将 `--no-appstream` 作为第七个参数传入。该模式保持 `--no-appstream --runtime-file <runtime> <AppDir> <输出文件>` 的参数顺序，供需要保留该封装方式的应用调用。
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
