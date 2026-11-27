# Modern CSV 固定配置

本页记录 Modern CSV 2.x 构建中的固定归档标签、签名密钥、兼容运行库范围及打包路径。应用版本由 `Common/github/download_tagged_release_asset.sh` 选取归档中的最高版本后生成，Debian 兼容包版本由签名 APT 仓库解析。模板差异见 [template-deviations.md](./template-deviations.md)。

## 固定配置清单

| 配置 | 当前取值 | 依据与用途 |
| --- | --- | --- |
| 归档 Release 标签与资产模板 | `newyorkthink/linux-packaging` 标签 `original-package-archive`，模板 `ModernCSV-Linux-v{version}.tar.gz` | [Archive Original Packages](../../.github/workflows/archive_original_packages.yml) 从官网 `https://www.moderncsv.com/release/ModernCSV-Linux-v{version}.tar.gz` 取得指定的 2.x 原始包。构建经认证查询选取最高版本并校验该资产的 GitHub SHA-256。[构建位置](../build_moderncsv.sh#L22-L29) |
| 官方 Qt 运行时和 XCB 插件 | 官方 `lib/`、`plugins/platforms/libqxcb.so`、`QT_LOCATION="$SOURCE_DIR"` | 自带 Qt 6.4.3 是 2.x 兼容基线。此前替换为带 `GNU_PROPERTY_1_NEEDED_INDIRECT_EXTERN_ACCESS` 的 Arch Qt 6 曾造成启动崩溃。保留官方 XCB 插件，避免一并载入旧版原包的 Qt 5 插件。[程序与插件位置](../build_moderncsv.sh#L31-L43) · [Qt 环境](../build_moderncsv.sh#L98-L103) · [故障记录](../README.md#修复记录) |
| Qt 6.4 兼容插件来源 | Debian 12（`bookworm`）`main`、`amd64`，签名密钥 `https://ftp-master.debian.org/keys/archive-key-12.asc` | `libqt6gui6` 提供 Compose 和 IBus 插件，`libqt6network6` 提供证书和 OpenSSL TLS 后端，`fcitx5-frontend-qt6`、`libfcitx5-qt6-1`、`libfcitx5utils2` 提供 Fcitx5 插件和运行库，`adwaita-qt6`、`libadwaitaqt6-1`、`libadwaitaqt6priv1` 提供 Adwaita 样式和运行库。仅提取所需文件，完整复制 SONAME 链。[下载和复制位置](../build_moderncsv.sh#L45-L77) |
| 构建期库查找与显式收集 | `LD_LIBRARY_PATH="$SOURCE_DIR/lib..."`。收集 `moderncsv`、`libFcitx5Qt6DBusAddons.so.1`、`libFcitx5Utils.so.2`、`libadwaitaqt6.so.1`、`libadwaitaqt6priv.so.1`、`/usr/lib/libssl.so.3`、`/usr/lib/libcrypto.so.3` | 让 quick-sharun 前置依赖检查从原包解析 Qt，并将输入法、主题和 TLS 插件所需的独立库部署到 AppDir。库查找变量仅用于该次构建调用。[收集位置](../build_moderncsv.sh#L108-L114) |
| 桌面入口、图标与产物路径 | 包内 `moderncsv.desktop`、`moderncsv.png`、`STARTUPWMCLASS=moderncsv`、`dist/moderncsv.AppImage`、`dist/version.txt` | 将解包所得 desktop 副本的 `Icon=/opt/moderncsv/moderncsv.png` 改成 `Icon=moderncsv`，避免将宿主安装目录用作图标来源。产物与版本键对齐 `.github/appimage-apps.json`。[图标修正](../build_moderncsv.sh#L79-L80) · [资源导出](../build_moderncsv.sh#L86-L97) · [保存位置](../build_moderncsv.sh#L127-L131) |
| 包内中文 locale 与 Qt 样式 | `AppDir/lib/locale/zh_CN.utf8`、`AppDir/.env`、`QT_STYLE_OVERRIDE=Adwaita-Dark` | 由包内 locale 提供中文运行环境，Qt 默认使用包内 Adwaita 暗色样式。[应用环境](../build_moderncsv.sh#L116-L125) |
