# Modern CSV AppImage

## 用途

本目录将 Modern CSV 官方 Linux 2.x 稳定版重新封装为 AppImage，产物名固定为：

```text
moderncsv.AppImage
```

现有许可证仅覆盖 Modern CSV 2.x，因此本仓库继续打包 2.x，暂缓升级到 3.0.0。

上游与打包参考：

- Modern CSV：`https://www.moderncsv.com/`
- [Modern CSV 官方旧版下载](https://www.moderncsv.com/download-older-versions/)提供 2.x 的 Linux `tar.gz`。通过 [Archive Original Packages](../.github/workflows/archive_original_packages.yml) 手动维护 [`original-package-archive`](https://github.com/newyorkthink/linux-packaging/releases/tag/original-package-archive) 中的原包。当前归档维持在 2.x，构建默认取匹配文件名模板的最高版本。
- pkgforge-dev `quick-sharun`：`https://github.com/pkgforge-dev/Anylinux-AppImages`
- 官方说明：`https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/HOW-TO-MAKE-THESE.md`
- 模板差异与固定配置：[template-deviations.md](./docs/template-deviations.md) · [hardcoded.md](./docs/hardcoded.md)

## 打包环境

Modern CSV 使用仓库统一的 Arch Linux / AnyLinux quick-sharun 构建环境，归类于[用 quick-sharun 打包的 Qt 程序 → 直接下载安装包](../Docs/packaging-classification.md#用-quick-sharun-打包的-qt-程序)。

`.github/workflows/build.yml` 中的 Modern CSV Job 通过统一矩阵调度复用：

```text
ghcr.io/pkgforge-dev/archlinux:latest
pkgforge-dev/anylinux-setup-action
.github/actions/build-anylinux
```

应用脚本本身不再启动额外 Docker / chroot，也不重复下载 quick-sharun。

2.x 流程沿用官方 Qt 6.4.3 运行时和同包的 `libqxcb.so`，其余插件按用途从 Debian 12（Bookworm）的 Qt 6.4.2 同代组件中选取。旧版 AppImage 替换成 Arch 系统 Qt 6 后曾发生 `GNU_PROPERTY_1_NEEDED_INDIRECT_EXTERN_ACCESS` 启动崩溃，故构建依赖只安装所需的非 Qt 软件包。故障经过见下文修复记录。

## 打包流程

`build_moderncsv.sh` 通过仓库 `Common/` 公共入口下载、验签、解包和保存版本。依赖安装、下载和 `quick-sharun` 收集的参数直接写在各自的调用行。

1. 调用 `Common/arch/install_packages.sh --base` 安装基础工具，另起一行安装 `dpkg`、`fontconfig`、`libglvnd`、`libunwind`、`libx11`、`libxcb`、`libxkbcommon-x11`、`mesa` 及 `xcb-util*` 等非 Qt 运行依赖。
2. 调用 `Common/build/prepare_x86_64_workspace.sh` 准备 `AppDir`、`dist`、`work`。通过 `Common/github/download_tagged_release_asset.sh` 从 `original-package-archive` 选取最高版本的 `ModernCSV-Linux-v{version}.tar.gz`，使用公共入口的认证查询、Release 下载回退和 SHA-256 校验，并保留同次下载的版本记录。
3. 调用 `Common/archive/extract_archive.sh` 解包。保留主程序、官方 Qt 6.4.3 库及 `libqxcb.so`，其余原包插件由同代兼容组件按需补齐。
4. 通过 `Common/download/download_apt_repository_deb.sh` 从 Debian Bookworm 签名 APT 仓库下载八个兼容包。仅提取 Compose、IBus、Fcitx5 输入插件、TLS 后端、Adwaita Qt 6 样式插件及其配套运行库，完整保留所需的库符号链接链。Qt 库继续使用官方原包内容。
5. 以解包目录为 `QT_LOCATION`，使用包内官方图标和 desktop。将工作目录中解出的 desktop 副本里的绝对 `Icon=` 路径改为 `moderncsv`，由 AppImage 提供对应图标。
6. 仅在部署依赖时为 `quick-sharun` 设置 `LD_LIBRARY_PATH` 指向官方运行库，并显式传入主程序、Fcitx5 和 Adwaita 运行库及 OpenSSL 3 库。随后生成包内中文 locale 并由 `AppDir/.env` 加载。
7. 执行 `quick-sharun --make-appimage`，最后调用 `Common/build/save_appimage_version.sh` 校验产物并写入 `dist/version.txt`。

## AppDir 结构说明

解包后的程序目录保留官方 `lib/` 布局，按需整理 `plugins/` 后交给 `quick-sharun` 收集。工具将真实程序和依赖放入 AppDir 自身目录，并生成 sharun 启动入口。Fcitx5 和 Adwaita 运行库以精确 SONAME 路径加入收集清单。

## Qt 与中文输入

包内生成 `AppDir/lib/locale/zh_CN.utf8`，在 `AppDir/.env` 中设置 `LANG`、`LANGUAGE`、`LC_MESSAGES` 和 `LOCPATH`。Fcitx5、IBus 或 Compose 由宿主输入法环境选择，脚本不强制设置 `QT_IM_MODULE`。中文 locale 和输入法支持不涉及界面翻译。

## 特殊处理原则

CopyQ 中 `lib/copyq/plugins` 的符号链接修复属于 CopyQ 自身插件搜索行为，不复制到 Modern CSV。

保留 `QT_LOCATION`、Qt 运行库隔离方式和兼容插件清单的依据，见 [template-deviations.md](./docs/template-deviations.md) 与 [hardcoded.md](./docs/hardcoded.md)。

## 修复记录

### 2026-09-02：改为直接复用官方 tar 包内 desktop / icon

- 官方 tar 本身已经包含完整的 `moderncsv.desktop`、`moderncsv.png`、主程序、`lib/`、`plugins/` 和 `qt.conf`。
- 直接复用官方 desktop、icon 和真实主程序，不额外生成替代文件。

### 2026-09-02：隔离官方 Qt6 runtime，修复 GNU_PROPERTY 启动错误

- 不再安装 Arch 当前 `qt6-base`、`qt6-5compat`、`fcitx5-qt` 后与官方 Qt runtime 混装。
- 只保留官方 Qt runtime 所需的非 Qt 系统依赖。

### 2026-09-03：简化为 AppDir/bin 直接打包

- 删除 `/usr/lib/moderncsv`、`$PWD/moderncsv-source` 等额外 staging 路径。
- 官方 tar 去掉最外层目录后直接完整解压到 `AppDir/bin/`。
- 删除 `QT_LOCATION`，直接执行 `quick-sharun ./AppDir/bin/moderncsv`。

### 2026-09-03：移除测试代码

- 删除构建脚本中的 `xvfb-run`、`timeout`、`SMOKE_RC` 和 smoke log 判断代码。
- Modern CSV 构建脚本只保留实际打包所需步骤，最后直接执行 `quick-sharun --make-appimage`。

### 2026-09-03：修正官方 tar staging 到 AppDir/shared/bin

- 实际运行旧产物时，Qt 从 `bin/plugins/` 加载 plugin，出现 `Plugin uses incompatible Qt library (5.12.0)`，并伴随 `No functional TLS backend was found`。
- 根因是完整官方目录被直接放入 `AppDir/bin/`，与 quick-sharun 将 `AppDir/bin/` 用作 sharun 启动入口、将真实程序放入 `AppDir/shared/bin/` 的布局发生冲突。
- `build_moderncsv.sh` 现将官方 tar 完整解压到 `AppDir/shared/bin/`，并改为执行 `quick-sharun ./AppDir/shared/bin/moderncsv`；官方 `lib/`、`plugins/`、`qt.conf` 与真实程序继续保持同级相对关系。
- 当前已完成脚本与目录结构修正；新产物的实际运行结果以本次构建完成后的实机反馈为准。

### 2026-09-03：校准 quick-sharun 通用基础环境

- `build_moderncsv.sh` 将原先拆分的最小依赖改为仓库 quick-sharun 通用基础依赖集合，并保持单条 `yay -S --noconfirm ...` 安装命令。
- 基础环境补齐 Qt6、GTK3/GTK4、Fcitx5/IBus、Fcitx5 Rime、IBus Rime、TLS/OpenSSL、X11/XCB、Wayland、OpenGL、字体、图标、SVG/QML/Multimedia、打印和主题插件相关包。
- 官方 Modern CSV 的 `lib/`、`plugins/`、`qt.conf` 目录布局不改；本次只校准构建期依赖环境，不新增测试代码。

### 2026-09-03：固定通用基线与项目额外依赖分离

- `build_moderncsv.sh` 的 Qt6 通用基础命令改为仓库统一基线，并按约每 10 个包换行，避免依赖列表挤成单行。
- 通用基线补齐 `glycin`、`libheif`、`ca-certificates-utils`、`egl-wayland`、`libice`、`libsm`、`libinput`、`qt6-translations`、`fcitx5-gtk` 等组件，并移除 `ibus` / `ibus-rime`。
- 当前 Modern CSV 没有基线之外的额外软件包；后续项目特有依赖必须单独使用独立 `yay` 命令，不得改写或混入通用基础命令。
- 官方 Modern CSV 的 `lib/`、`plugins/`、`qt.conf` 布局和现有 quick-sharun 打包主线保持不变。

### 2026-09-03：精简 Qt6 通用基线

- 按当前基线调整，先从 quick-sharun Qt6 通用基础环境中删除 `qca-qt6`、`qt6-5compat`、`qt6-tools`；其他依赖暂不调整。

### 2026-09-03：统一 Qt6 runtime，修复 TLS 与中文输入链路

- 故障现象：当前 Release AppImage 能启动，但持续输出 `No functional TLS backend was found` / `TLS initialization failed`，并且 Qt GUI 无法使用中文输入法。
- 根因核实：官方 `ModernCSV-Linux-v2.4.3.tar.gz` 的 `moderncsv` 主程序链接 Qt6，随包 `libQt6Core.so.6` 为 Qt 6.4.3；但官方 `plugins/` 中的 Compose / IBus input context、GTK3 platform theme、SVG / imageformat、XCB GL integration 等多项 plugin 实际仍链接 Qt5，且官方包没有 `plugins/tls/`，也没有 Fcitx5 Qt6 input context。
- 修改文件：`moderncsv/build_moderncsv.sh`、`moderncsv/README.md`。
- 修复内容：官方 tar 只提取应用本体、desktop 和 icon；不再带入官方 `lib/`、`plugins/`、`qt.conf`。原有非 Qt 依赖命令逐字保留，另起独立 `yay` 命令补回 `qt6-base`、`qt6-5compat`、`qt6-svg`、`qt6-imageformats`、`fcitx5-qt`，由 quick-sharun 从同一套 Arch Qt6 环境部署 Qt6 runtime、TLS backend、Compose / IBus / Fcitx5 input context 和其他 Qt6 plugin。
- 已知结果：已完成上游 tar、ELF `NEEDED`、Qt plugin 依赖及 quick-sharun Qt plugin 收集逻辑的静态核对；本次不新增任何测试代码，最终运行结果以正常 GitHub Actions 构建和后续真实 Linux 运行反馈为准。

### 2026-09-03：恢复官方 Qt 6.4.3 runtime，修复 GNU_PROPERTY 启动崩溃

- 故障现象：最新 Release AppImage 在真实 Linux 环境启动时，`libQt6Widgets.so.6` 报 `direct reference to protected function`，随后因 `GNU_PROPERTY_1_NEEDED_INDIRECT_EXTERN_ACCESS` 直接终止。
- 根因核实：故障 AppImage 内的 `libQt6Widgets.so.6` 已被替换为 Arch Qt 6.11.2，并带有 `1_needed: indirect external access` GNU property；Modern CSV 主程序对 `QStyledItemDelegate::initStyleOption` 存在直接符号引用。官方 tar 自带的 Qt 6.4.3 `libQt6Widgets.so.6` 不带该 property，因此将官方 Qt 6.4.3 runtime 整体替换为 Arch Qt 6.11.2 是本次启动崩溃的直接原因。
- 修改文件：`moderncsv/build_moderncsv.sh`、`moderncsv/README.md`。
- 修复内容：删除 Arch Qt6 runtime/plugin 安装命令，恢复完整官方 Qt 6.4.3 runtime，并重新启用 `QT_LOCATION="$SOURCE_DIR"`；官方 plugin 树只保留同包 Qt6 `libqxcb.so`，其余 Qt5 plugin 删除。TLS、Compose / IBus 和 Fcitx5 Qt6 input context 改为只补入 Debian Bookworm Qt 6.4.2 同代 plugin，同时补入对应 Fcitx5 运行库，且不复制 Debian 的任何 `libQt6*.so`。
- 已知结果：已对故障 AppImage 与官方 `ModernCSV-Linux-v2.4.3.tar.gz` 的 ELF 属性、QtWidgets 符号和 plugin Qt 主版本完成静态核对；构建脚本已通过 `bash -n` 静态语法检查，未加入 smoke test 或其他测试代码。最终运行结果以本次 GitHub Actions 正常构建后的实机反馈为准。

### 2026-09-03：显式部署 Fcitx5 Qt6 运行库，修复中文输入

- 故障现象：恢复官方 Qt 6.4.3 runtime 后，程序可以正常启动，TLS backend 也已恢复，但真实 Linux 环境仍无法通过 Fcitx5 输入中文。
- 根因核实：新产物已经包含 `libfcitx5platforminputcontextplugin.so`，但最终 AppImage 中缺少其 `NEEDED` 运行库 `libFcitx5Qt6DBusAddons.so.1`；旧的可中文输入产物同时包含 `libFcitx5Qt6DBusAddons.so.1` 和 `libFcitx5Utils.so.2`。构建脚本虽然把这两个库复制到了 `moderncsv-source/lib/`，但之前只把 `moderncsv` 主程序交给 quick-sharun，因此这两个 Fcitx5 运行库没有进入最终 AppImage。
- 修改文件：`moderncsv/build_moderncsv.sh`、`moderncsv/README.md`。
- 修复内容：保持官方 Qt 6.4.3、Debian Qt 6.4.2 输入插件和现有 TLS 处理不变；调用 quick-sharun 时除主程序外，显式传入 `libFcitx5Qt6DBusAddons.so.1*` 和 `libFcitx5Utils.so.2*`，使其进入标准 AppDir library 目录并由最终 AppImage 提供。
- 已知结果：已对比新旧真实 AppImage 的 Fcitx5 plugin `NEEDED` 与打包内容，确认缺失的是 Fcitx5 Qt6 运行库；本次仅调整实际打包输入和 README，不新增任何测试代码或 workflow。

### 2026-09-03：补齐 Fcitx5 运行库 SONAME 链，修复构建失败

- 故障现象：Actions Run `33721724921` 在 quick-sharun 开始部署时直接报 `moderncsv-source/lib/libFcitx5Qt6DBusAddons.so.1 is NOT present` 并退出。
- 根因核实：之前使用 `libFcitx5Qt6DBusAddons.so.1*` / `libFcitx5Utils.so.2*` 复制 Debian 运行库，只覆盖了 SONAME symlink 的命名范围；真实版本文件使用 VERSION 文件名，不一定以 `.so.1` / `.so.2` 开头，导致复制到 `moderncsv-source/lib/` 的 SONAME symlink 变成断链。quick-sharun 对显式输入执行文件存在性检查时因此判断为不存在。
- 修改文件：`moderncsv/build_moderncsv.sh`、`moderncsv/README.md`。
- 修复内容：复制模式扩大为 `libFcitx5Qt6DBusAddons.so.*` 和 `libFcitx5Utils.so.*`，完整保留 SONAME symlink 与真实版本文件；quick-sharun 显式输入改为准确的 `libFcitx5Qt6DBusAddons.so.1` 和 `libFcitx5Utils.so.2`。
- 已知结果：已读取失败 Job `100542108333` 的完整日志，确认失败点发生在 quick-sharun 的输入文件存在性检查；构建脚本已通过 `bash -n` 静态语法检查，本次不新增测试代码或 workflow。

### 2026-09-03：为 Fcitx5 显式输入补充官方 Qt 依赖解析路径

- 故障现象：Actions Run `33722567482` 的 Job `100544635972` 已能找到 `libFcitx5Qt6DBusAddons.so.1`，但 quick-sharun 在前置依赖检查阶段报 `libQt6DBus.so.6 => not found`、`libQt6Core.so.6 => not found`，随后以 `is missing libraries! Aborting` 退出。
- 根因核实：`libQt6DBus.so.6` 和 `libQt6Core.so.6` 实际位于官方 `moderncsv-source/lib/`；quick-sharun 对显式输入直接执行 `ldd` 检查，而构建机动态链接器默认搜索路径不包含该 staging 目录，因此误判 Fcitx5 Qt6 运行库缺失 Qt 依赖。
- 修改文件：`moderncsv/build_moderncsv.sh`、`moderncsv/README.md`。
- 修复内容：保持官方 Qt 6.4.3、Debian Qt 6.4.2 输入/TLS plugin 和 Fcitx5 SONAME 链不变；仅在 quick-sharun 主部署调用期间设置 `LD_LIBRARY_PATH="$SOURCE_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"`，让 `ldd` 和依赖收集从官方 Qt runtime 解析 Qt6 Core / DBus。该变量不写入最终 AppImage 运行环境。
- 已知结果：已读取失败 Job 的完整日志，并核对 quick-sharun 当前实现确实在部署前直接通过 `ldd "$bin" | grep "not found"` 判断显式输入是否缺库；构建脚本已通过 `bash -n` 静态语法检查，本次不新增测试代码或 workflow。

### 2026-09-03：同步最小通用基础包

- `build_moderncsv.sh` 的通用 quick-sharun 基础包统一为 23 个：`base-devel git wget curl jq binutils patchelf file coreutils findutils grep sed gawk tar gzip xz unzip rsync util-linux appstream-glib desktop-file-utils zsync ca-certificates`，按 10 + 10 + 3 使用 `\` 分行。
- Modern CSV 已确认需要的 `openssl`、`mesa`、XCB 相关组件、`xdg-utils`、`fontconfig` 继续使用独立应用级 `yay` 命令，不回填到通用基础包；`patchelf` 已由通用基础包提供，因此从应用级依赖中移除重复项。
- 官方 Qt 6.4.3 runtime、Debian Qt 6.4.2 plugin、Fcitx5 运行库和现有 quick-sharun 打包逻辑均保持不变，本次只同步构建期基础包分层。

## 2026-09-16：接入统一软件版本元数据

- 当前稳定基线仍固定为官方 Modern CSV 2.4.3 与既有 Qt 6.4.3 / Debian Bookworm Qt 6.4.2 兼容组合。
- 构建脚本将原本散落在官方下载 URL 中的 `2.4.3` 收敛为 `MODERNCSV_VERSION`，下载来源与版本本身不变，并在构建完成后写入 `dist/version.txt`。
- workflow 使用 `SOFTWARE_KEY=moderncsv` 接入统一 `software_versions.json`；本次不调整任何 Qt、Fcitx5、TLS 或 quick-sharun 兼容逻辑。

### 2026-09-17：官方 tar.gz 下载到 Cloudflare HTML

- 故障现象：wget 得到 HTTP 200、`text/html` 约 12KB，随后 `gzip: stdin: not in gzip format`。
- 根因核实：下载 URL 本身有效（约 28MB gzip），GitHub Actions 出口偶发被 Cloudflare 返回挑战页。
- 修改：补浏览器 User-Agent，下载后 `gzip -t` 校验，失败则重试；不解压 HTML。
- 不改版本、Qt runtime 和打包步骤。

## 2026-11-27：切至官方签名 APT 源（3.x）并按 Qt 直接下载标准整理

- 故障现象：下载旧版硬编码 `ModernCSV-Linux-v2.4.3.tar.gz` 时，连续五次收到 HTTP 200 和 `text/html` 响应，均未通过 `gzip -t` 校验并报 `无法下载有效的 ModernCSV-Linux-v2.4.3.tar.gz。` 退出。[GitHub Actions 失败日志](https://github.com/newyorkthink/linux-packaging/actions/runs/45948744673/job/140339442640)
- 实包核对：官方签名 APT 仓库提供的 3.0 `amd64.deb` 已自带完整 **Qt 6.8.3** 与全部 13 个原生 Qt 6 插件目录（含 Compose、IBus、OpenSSL/证书 TLS、SQLite、CUPS、XCB、Wayland），不再混有 Qt 5 插件；但 `readelf -rW` 核实主程序仍对受保护 Qt 函数存在 `R_X86_64_64` 直接重定位，不能替换为启用了 `GNU_PROPERTY_1_NEEDED_INDIRECT_EXTERN_ACCESS` 的 Arch 系统 Qt 6。
- 调整内容：`build_moderncsv.sh` 全面接入 `Common/` 公共入口，从官方签名 APT 仓库动态获取最新 3.x DEB，完整保留官方 Qt 6.8.3 运行时和全部原生插件，改由 Debian 13（`trixie`，同代 Qt 6.8.2 ABI）签名 APT 仓库仅补入 `fcitx5-frontend-qt6`、`libfcitx5-qt6-1`、`libfcitx5utils2`，并补齐包内中文 locale 与 `libssl.so.3`/`libcrypto.so.3` 显式收集；同步新增 [template-deviations.md](./docs/template-deviations.md) 与 [hardcoded.md](./docs/hardcoded.md) 并归类至[用 quick-sharun 打包的 Qt 程序 → 直接下载安装包](../Docs/packaging-classification.md#用-quick-sharun-打包的-qt-程序)。

### 2026-11-27：扩展公共 APT 验签兼容多密钥 InRelease 并补入 `libunwind`

- 故障现象：Modern CSV 3.0 官方签名 APT 源下载与验签已通过，但在下载 Debian 13（`trixie`）Fcitx5 兼容包时，`trixie/InRelease` 同时带有三把官方密钥签名；`archive-key-13.asc` 验签输出 `Good signature` 后，因另外两把未提供公钥的签名触发 `Can't check signature: No public key`，`gpgv` 返回退出码 `2` 中断构建。[GitHub Actions 失败日志](https://github.com/newyorkthink/linux-packaging/actions/runs/45968518173/job/140406790465)
- 调整内容：在 `Common/download/download_apt_repository_deb.sh` 接入 RFC 4880 单一明文签名块严格拆分与 `gpgv --status-fd 1` 状态验签，要求调用方指定官方公钥至少产出一条有效 `GOODSIG`/`VALIDSIG` 且无损坏、过期、吊销或非缺公钥错误；同步在 `moderncsv/build_moderncsv.sh` 依赖行补入 `libunwind`（供 Debian Trixie `libfcitx5utils2` 依赖的 `libunwind.so.8`）。

### 2026-11-27：构建来源切至本仓库 `original-package-archive`（保留最新 2 个版本）

- 故障现象：GitHub Actions 出口访问 `www.moderncsv.com/release/apt/` 时仍会偶发收到约 12 KB 的 HTML 挑战页，导致 `gpg --dearmor` 报 `gpg: no valid OpenPGP data found.` 退出。[GitHub Actions 失败日志](https://github.com/newyorkthink/linux-packaging/actions/runs/45972050809/job/140414653877)
- 调整内容：在 [archive_original_packages.yml](../.github/workflows/archive_original_packages.yml) 将 `moderncsv` 手动归档升级为同时归档官方签名 APT 最新 3.x DEB 与同版本 `tar.gz` 并自动保留最新 2 个版本（便于新版本注册异常时回退上一版本）；`build_moderncsv.sh` 改用公共入口 `Common/github/download_tagged_release_asset.sh` 从本仓库 `original-package-archive` 自动选择最高版本 `moderncsv_{version}_amd64.deb` 并校验官方 SHA-256 与 DEB 元数据，日常、定时与按需构建不再直接访问 `moderncsv.com`。

### 2026-11-27：恢复 2.x 稳定版打包

- 官方提供 [2.x Linux 旧版下载](https://www.moderncsv.com/download-older-versions/)，适用于继续使用现有 2.x 许可证的用户。手动归档和日常打包分别从官方旧版原包与本仓库 `original-package-archive` 取包，构建自动读取本次下载对应的实际版本。
- 恢复官方 Qt 6.4.3 和 Debian Bookworm Qt 6.4.2 的插件组合。补齐中文输入和 TLS 插件，继续使用包内中文 locale，加入 Adwaita 深色样式，并修正打包用 desktop 副本的图标字段。
