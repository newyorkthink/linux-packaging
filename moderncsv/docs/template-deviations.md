# Modern CSV 模板差异

## 分类与两项来源核实

本项目归类于[用 quick-sharun 打包的 Qt 程序 → 直接下载安装包](../../Docs/packaging-classification.md#用-quick-sharun-打包的-qt-程序)，不新增第 14 份标准模板。本次按仓库本地工作区直接交付最终版的授权，对齐 [quick-sharun 固定注释标准](../../Docs/quick-sharun-comments.md) 及仓库 `Common/` 公共入口，并保留下列经核实的本应用专属处理。

两项前置核实结果：

1. **`pkgforge-dev` 官方打包**：在 `pkgforge-dev` 检索 `moderncsv` 与 `modern-csv`，未查到对应上游打包仓库。
2. **官方包与 Qt 运行时核实**：
   - 官方从 3.0 起提供签名 APT 仓库 `https://www.moderncsv.com/release/apt`（`stable main moderncsv amd64`，GPG 公钥 `https://www.moderncsv.com/release/apt/public.key`）及同版本官方 Linux `tar.gz`；由于 `www.moderncsv.com` 对 GitHub Actions 出口偶发返回 HTML 挑战页，现由 [Archive Original Packages](../../.github/workflows/archive_original_packages.yml) 手动归档至本仓库 `original-package-archive`（保留最新 2 个版本），构建脚本通过 `Common/github/download_tagged_release_asset.sh` 自动选择最高版本 `moderncsv_{version}_amd64.deb` 并校验 GitHub SHA-256 与 DEB 元数据，日常/定时构建不再直接访问 `moderncsv.com`。
   - 实查 3.0 官方 DEB 解包目录（`opt/moderncsv/`）：
     - `lib/` 自带完整 **Qt 6.8.3**（含 ICU 73、OpenSSL 3、XCB、Wayland），主程序 `DT_RUNPATH=$ORIGIN/lib`，所有插件 `DT_RUNPATH=$ORIGIN/../../lib`。
     - `plugins/` 下全部 13 个插件目录均为纯 Qt 6.8.3（旧版 2.4.3 的 Qt 5 混杂插件问题已在上游解决），已自带 `tls/`（`libqcertonlybackend.so`、`libqopensslbackend.so`）、`platforminputcontexts/`（`compose`、`ibus`）、`platforms/`、`platformthemes/`、`printsupport/`、`sqldrivers/`、`imageformats/`、`iconengines/`、`wayland-*`、`xcbglintegrations/`。
     - `readelf -rW` 核实 3.0 主程序仍对 `QGroupBox::initStyleOption`、`QTabWidget::initStyleOption`、`QFrame::initStyleOption` 等受保护 Qt 函数存在 `R_X86_64_64` 直接符号引用；而 Arch 官方 `qt6-base` 启用了 `-DFEATURE_no_direct_extern_access=ON`（`GNU_PROPERTY_1_NEEDED_INDIRECT_EXTERN_ACCESS`），因此**不能使用 Arch `--qt6` 替换官方 Qt 6.8.3 运行时**（2026-09-03 已实机复现该启动崩溃）。
     - 官方 3.0 DEB 仅缺少 Fcitx5 Qt 6 输入法插件；由同代 Qt 6.8 系列（Qt 6.8.2）的 **Debian 13（Trixie）** 签名 APT 仓库按需补入 `fcitx5-frontend-qt6`、`libfcitx5-qt6-1`、`libfcitx5utils2` 三个包即可，不替换任何官方 `libQt6*.so`。

现有 `Templates/quick-sharun/qt-deb.sh` 面向 AUR DEB 源；本应用未安装同源 AUR 应用包，改由本仓库 `original-package-archive` 归档标签自动选取最高版本 3.x DEB、保留上游 Qt 6.8.3 目录（`QT_LOCATION`）并从 Debian Trixie 签名仓库补齐同代 Qt 6.8 Fcitx5 插件，这些步骤作为本应用在该分类下的已核实专属处理保留。

## 公共阶段对齐

| 阶段 | 当前处理 | 依据与影响 |
| --- | --- | --- |
| 初始化 | 严格模式，定位并切换至 `moderncsv/` 目录。 | 相对路径和产物均落在应用目录内。 |
| 依赖安装 | `Common/arch/install_packages.sh --base` 加一行非 Qt 运行依赖。 | 不调用 `--qt6`，避免 Arch Qt 6.12 混入或覆盖官方 Qt 6.8.3；显式安装 `dpkg`、`fontconfig`、`gtk3`（供 `libqgtk3.so`）、`libcups`（供 `libcupsprintersupport.so`）、`libunwind`（供 Debian Trixie `libfcitx5utils2` 依赖的 `libunwind.so.8`）、`wayland`（供 `libqwayland-*.so`）、`mesa`、`libglvnd`、`libx11`、`libxcb`、`xcb-util*`、`libxkbcommon-x11`。 |
| 工作区 | `Common/build/prepare_x86_64_workspace.sh "$SCRIPT_DIR" --skip-create AppDir dist work`。 | 替代手工 `rm -rf` 和 `/tmp` 临时目录。 |
| 版本读取与保存 | `Common/build/read_app_version.sh text work/source-version.txt` 与 `Common/build/save_appimage_version.sh`。 | 从 `original-package-archive` 同次校验下载的 DEB 读取实际版本，不再硬编码 `2.4.3`。 |
| 中文环境 | 收集依赖后生成 `AppDir/lib/locale/zh_CN.utf8` 并写入 `AppDir/.env`。 | 按 `anylinux_projects.md` 补齐 GUI 包内中文 locale；不强制覆盖 `QT_IM_MODULE`，由宿主输入法决定。 |

## 保留与调整的专属处理

以下处理均对应 [build_moderncsv.sh](../build_moderncsv.sh) 中的具体阶段（模板外新增步骤紧贴对应命令以 `# 本程序专属处理：` 标注，沿用公共语义的步骤保留固定标准注释）：

| 处理 | 代码位置 | 保留/调整原因与影响 |
| --- | --- | --- |
| 从归档 Release 下载最高版本 DEB | [build_moderncsv.sh](../build_moderncsv.sh#L18-L22) | 通过 `Common/github/download_tagged_release_asset.sh` 经认证 GitHub API 从本仓库 `original-package-archive` 自动选取最高版本 `moderncsv_{version}_amd64.deb`，核对 GitHub SHA-256 及 DEB 身份与版本，避免日常/定时构建受 `moderncsv.com` 出口挑战页影响。 |
| 保留官方 Qt 6.8.3 与全部原生插件 | [build_moderncsv.sh](../build_moderncsv.sh#L24-L25) | 不再清空 `plugins/`，也不再下载 `libqt6gui6` / `libqt6network6`；完整保留 3.0 官方自带的 Qt 6.8.3 库与 13 个原生 Qt 6 插件目录。 |
| 补入 Debian 13 (Trixie) Fcitx5 Qt6 插件 | [build_moderncsv.sh](../build_moderncsv.sh#L27-L39) | 通过 `Common/download/download_apt_repository_deb.sh` 从 Debian Trixie 签名 APT 仓库动态下载 `fcitx5-frontend-qt6`、`libfcitx5-qt6-1`、`libfcitx5utils2`，仅复制 Fcitx5 输入法插件与完整 SONAME 运行库链，不再使用硬编码 `wget` 与 Debian Bookworm Qt 6.4.2 包；依据见 [hardcoded.md](./hardcoded.md)。 |
| 指定 `QT_LOCATION` 与 OpenSSL 3 显式收集 | [build_moderncsv.sh](../build_moderncsv.sh#L57-L68) | 设置 `DEPLOY_QT=1`、`DEPLOY_OPENGL=1`、`QT_LOCATION="$SOURCE_DIR"`，让 `quick-sharun` 从官方 6.8.3 目录部署全部插件；构建期临时设置 `LD_LIBRARY_PATH="$SOURCE_DIR/lib..."` 让 `ldd` 解析官方 Qt 6.8.3 依赖，并显式收入 `libFcitx5Qt6DBusAddons.so.1`、`libFcitx5Utils.so.2` 与 `/usr/lib/libssl.so.3`、`/usr/lib/libcrypto.so.3` 供 `libqopensslbackend.so` 使用。 |
