# Modern CSV 模板差异

## 分类与两项来源核实

本项目按仓库的[专用打包流程](../../Docs/packaging-classification.md#专用打包流程)维护。构建沿用 [quick-sharun 固定注释标准](../../Docs/quick-sharun-comments.md)，下载、验签、解包及版本记录使用仓库 `Common/` 脚本。

1. **`pkgforge-dev` 官方打包**。经检索 `moderncsv` 和 `modern-csv`，未发现对应的应用打包仓库。采用 pkgforge-dev 通用流程，先用 `quick-sharun` 部署程序及依赖，再调用 `quick-sharun --make-appimage`。[官方流程](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/HOW-TO-MAKE-THESE.md#L55-L66)
2. **官方包与运行时**。官方旧版下载页提供 2.x Linux `tar.gz`，其发布目录列有 `ModernCSV-Linux-v2.4.5.tar.gz`。2.x 兼容方案来自此前 2.4.3 产物的 Qt、TLS 和输入法故障记录。替换成 Arch 系统 Qt 6 会触发受保护符号直接引用错误，保留官方 Qt 6.4.3 后，由 Debian Bookworm 的 Qt 6.4.2 同代组件补齐所需插件。[官方旧版下载](https://www.moderncsv.com/download-older-versions/) · [官方发布目录](https://www.moderncsv.com/release/) · [修复记录](../README.md#修复记录)
   AUR `moderncsv-bin` 的 2.4.5 配方使用同一官方 TAR，其 SHA-256 与归档资产一致。构建按本应用的专用流程读取归档，应用版本由归档资产决定。[AUR 来源记录](https://github.com/wjdp/moderncsv-bin/blob/d56e5f1f66858982726e9827bdea8ea943244901/.SRCINFO)

最接近的 [`qt-deb.sh`](../../Templates/quick-sharun/qt-deb.sh) 固定从 AUR 配方下载 DEB 并复制程序目录至 `AppDir/bin`。[`qt-installed.sh`](../../Templates/quick-sharun/qt-installed.sh) 固定使用已安装的 Arch Qt 程序和系统 Qt 组件。当前实际输入是经归档校验的官方 2.x tarball，需要保留包内 Qt 和 `libqxcb.so`，重建同代插件目录并指定 `QT_LOCATION`。固定模板现有参数无法表达这些步骤。

## 公共阶段对齐

| 阶段 | 当前处理 | 依据与影响 |
| --- | --- | --- |
| 初始化 | 严格模式，定位并切换至 `moderncsv/`。 | 相对路径和产物均落在应用目录内。 |
| 依赖安装 | `Common/arch/install_packages.sh --base` 加一行非 Qt 运行依赖。 | 安装配套系统库和 Debian DEB 解包工具，保留官方 Qt 运行时。 |
| 工作区 | `Common/build/prepare_x86_64_workspace.sh`。 | 统一准备 `AppDir`、`dist` 和 `work`。 |
| 版本读取与保存 | `Common/build/read_app_version.sh text work/source-version.txt` 与 `Common/build/save_appimage_version.sh`。 | 使用同次校验下载返回的 tarball 版本生成 `dist/version.txt`。 |
| 中文环境 | 收集依赖后生成 `AppDir/lib/locale/zh_CN.utf8` 并写入 `AppDir/.env`。 | 应用自带中文 locale，宿主输入法环境决定使用 Fcitx5、IBus 或 Compose。[对应代码](../build_moderncsv.sh#L116-L125) |

## 保留与调整的专属处理

| 处理 | 代码位置 | 依据与影响 |
| --- | --- | --- |
| 从归档 Release 下载官方 TAR | [下载与解包](../build_moderncsv.sh#L22-L29) | 按 `ModernCSV-Linux-v{version}.tar.gz` 选取归档中的最高匹配版本，经认证 Release 查询及 SHA-256 校验下载官方原包。2.x 打包依赖归档维持在 2.x。 |
| 保留官方 Qt 6.4.3 和 `libqxcb.so` | [定位程序与重建插件目录](../build_moderncsv.sh#L31-L43) | 沿用上游相对库路径，清理其余原包插件以隔离已知旧版 Qt 5 混杂问题，再按用途补入同代 Qt 6 插件。 |
| 补齐 Bookworm 插件和运行库 | [下载兼容包并选取内容](../build_moderncsv.sh#L45-L77) | 从 Debian 12 签名 APT 仓库提取 Compose、IBus、Fcitx5、TLS 和 Adwaita 样式插件，以及 Fcitx5 和 Adwaita 运行库的完整 SONAME 链。Qt 基础库由官方原包提供。 |
| 整理打包用 desktop | [图标修正](../build_moderncsv.sh#L79-L80) · [资源导出](../build_moderncsv.sh#L90-L93) | 在工作目录中解出的 desktop 副本里将绝对 `Icon=` 路径改为 `moderncsv`，并向 quick-sharun 提供包内官方 PNG。上游工具会生成 `.DirIcon`，desktop 内的图标键须在组装前整理。 |
| 指定插件路径并部署显式依赖 | [Qt 环境](../build_moderncsv.sh#L98-L103) · [依赖收集](../build_moderncsv.sh#L105-L114) | 用 `QT_LOCATION` 指定已整理的程序目录，`DEPLOY_QT=1` 启用 Qt 插件收集，包括 QtGui 对应的 `styles/`。仅构建部署时以 `LD_LIBRARY_PATH` 优先查找官方库，显式传入 Fcitx5、Adwaita 和 TLS 所需的运行库。 |
| 设置 Adwaita 暗色样式 | [应用环境](../build_moderncsv.sh#L119-L125) | 在 `AppDir/.env` 中设置 `QT_STYLE_OVERRIDE=Adwaita-Dark`，由包内 Adwaita Qt 6 样式插件提供。 |

桌面图标及 Qt 样式处理依据见 [quick-sharun 图标代码](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/useful-tools/quick-sharun.sh#L458-L487)、[Qt 插件代码](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/useful-tools/quick-sharun.sh#L1096-L1136)及 [appimagetool 的 desktop 处理](https://github.com/pkgforge-dev/appimagetool/blob/0.7.1/src/desktop.rs#L40-L117)。具体包名、库名和路径见 [固定配置](./hardcoded.md)。
