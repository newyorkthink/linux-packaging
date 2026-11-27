# Modern CSV 固定配置

本页记录 Modern CSV 构建脚本中的固定归档标签、签名密钥、兼容运行库范围及打包路径依据。Modern CSV 自身版本由 `Common/github/download_tagged_release_asset.sh` 从本仓库 `original-package-archive` 中最高版本的 `moderncsv_{version}_amd64.deb` 动态读取，不硬编码应用版本号、Debian 兼容包版本号或打包工具版本；模板差异见 [template-deviations.md](./template-deviations.md)。

## 固定配置清单

| 配置 | 当前取值 | 依据与用途 |
| --- | --- | --- |
| 归档 Release 标签与资产模板 | `newyorkthink/linux-packaging` 标签 `original-package-archive`，模板 `moderncsv_{version}_amd64.deb` | 原始包由 [Archive Original Packages](../../.github/workflows/archive_original_packages.yml) 从官方签名 APT 仓库验签归档（自动保留最新 2 个版本便于回退）；构建通过认证 GitHub API 自动选最高版本并校验 GitHub SHA-256 与 DEB 身份，避免 `www.moderncsv.com` 对 GitHub Actions 出口偶发返回 HTML 挑战页，[构建位置](../build_moderncsv.sh#L18-L19)。 |
| 保留官方 Qt 6.8.3 而不使用 Arch `--qt6` | `QT_LOCATION="$SOURCE_DIR"`，不安装任何 Arch `qt6-*` 包 | 3.0 主程序经 `readelf -rW` 核实仍对受保护 Qt 函数存在 `R_X86_64_64` 直接重定位；Arch 官方 `qt6-base` 启用 `-DFEATURE_no_direct_extern_access=ON`（`GNU_PROPERTY_1_NEEDED_INDIRECT_EXTERN_ACCESS`），替换后必发启动崩溃（见 [README 2026-09-03 故障记录](../README.md#2026-09-03恢复官方-qt-643-runtime修复-gnu_property-启动崩溃)），[构建位置](../build_moderncsv.sh#L24-L25)、[导出位置](../build_moderncsv.sh#L57-L62)。 |
| Fcitx5 Qt 6.8 兼容插件来源 | Debian 13（`trixie`）`main` 签名 APT 仓库，密钥 `https://ftp-master.debian.org/keys/archive-key-13.asc`，包名 `fcitx5-frontend-qt6`、`libfcitx5-qt6-1`、`libfcitx5utils2` | Modern CSV 3.0 DEB 自带 Qt 6.8.3 与全套原生 Qt 6 插件（含 Compose、IBus、TLS、SQLite、CUPS），仅缺 Fcitx5 Qt 6 输入法插件；Debian Trixie 提供同代 Qt 6.8.2 ABI 的 Fcitx5 Qt 6 插件，且经 `Common/download/download_apt_repository_deb.sh` 动态验签下载，不替换任何官方 `libQt6*.so`，[构建位置](../build_moderncsv.sh#L27-L39)。 |
| 构建期 `LD_LIBRARY_PATH` 与显式收集目标 | `LD_LIBRARY_PATH="$SOURCE_DIR/lib..."`；收集 `$SOURCE_DIR/moderncsv`、`libFcitx5Qt6DBusAddons.so.1`、`libFcitx5Utils.so.2`、`/usr/lib/libssl.so.3`、`/usr/lib/libcrypto.so.3` | 仅在构建期让 `quick-sharun` 的 `ldd` 检查解析官方 Qt 6.8.3 库（不写入 AppImage 运行环境）；显式收入 Fcitx5 运行库供插件加载，显式收入 OpenSSL 3 供 `libqopensslbackend.so` 运行时加载，[构建位置](../build_moderncsv.sh#L67-L68)。 |
| 桌面入口、图标与产物路径 | `usr/share/applications/moderncsv.desktop`、`usr/share/pixmaps/moderncsv.png`、`STARTUPWMCLASS=moderncsv`、`dist/moderncsv.AppImage`、`dist/version.txt` | DEB 内 `usr/share/applications/moderncsv.desktop` 为正式 3.0 桌面入口（`opt/moderncsv/moderncsv.desktop` 仍残留 `3.b4` 旧值）；产物与版本键对齐 `.github/appimage-apps.json`，[构建位置](../build_moderncsv.sh#L41-L56)、[保存位置](../build_moderncsv.sh#L83-L84)。 |
