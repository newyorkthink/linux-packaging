# Parsec 模板差异

Parsec 为闭源原生 X11 桌面客户端，未使用 Qt 或 GTK 框架，也没有纳入固定 13 份模板清单。构建流程沿用仓库“先安装 AUR 配方与运行依赖、再独立下载解包官方 DEB”的两阶段标准结构，并通过仓库公共入口实现，不新增第 14 份模板。

| 构建阶段 | 专属处理与依据 |
| --- | --- |
| 安装与来源 | 公共 Arch 安装入口先安装基础工具，再以 `--aur-deb "parsec-bin" "$(uname -m)" --wayback --source-filename 'parsec-bin-{version}.deb'` 安装 `parsec-bin`、`dpkg`、`ffmpeg4.4`、`libjpeg-turbo` 与 `libva`；随后调用 `Common/aur/download_deb_source.sh`（带 `--wayback --source-filename 'parsec-bin-{version}.deb'`，不传 `--version-file` 因 `.SRCINFO` 的 `pkgver=150_104a` 含下划线）独立下载官方 DEB 并解包。 [构建位置](../build_parsec.sh#L11-L24) |
| 程序与资源校验 | 从解包目录复制 `usr/bin/parsecd` 至 `AppDir/bin/`，并在继续打包前显式检查 `usr/share/parsec/skel/appdata.json` 与 `parsecd-*.so` 存在，随后将该目录完整复制到 `AppDir/share/parsec/`。 [程序与校验](../build_parsec.sh#L27-L35) · [资源复制](../build_parsec.sh#L67-L68) |
| 桌面、图标与版本 | 结合实测 DEB 布局固定使用 `/usr/share/icons/hicolor/256x256/apps/parsecd.png` 与 `/usr/share/applications/parsecd.desktop`；版本通过 `read_app_version.sh pacman "parsec-bin"` 读取并由 `save_appimage_version.sh` 写入 `dist/version.txt`。 [图标与桌面](../build_parsec.sh#L46-L48) · [版本读写](../build_parsec.sh#L61-L85) |
| 运行依赖与封装 | 设置 `DEPLOY_OPENGL=1`、`DEPLOY_PIPEWIRE=1`、`DEPLOY_LOCALE=1`、`NO_STRIP=1` 与 `PATH_MAPPING='/usr/share/parsec:${SHARUN_DIR}/share/parsec'`；在 `quick-sharun` 收集 `parsecd`、`parsecd-*.so`、`libavcodec.so.58`、`libavutil.so.56`、`libswresample.so.3`、`libjpeg.so.8` 与通用 `libva` loader（依据 2026-09-14 启动黑屏回归记录，不打包厂商 GPU 解码 backend）。生成 `zh_CN.UTF-8` locale 并写入 `LC_CTYPE` 等环境变量后封装成品。 [部署与收集](../build_parsec.sh#L54-L64) · [locale 与封装](../build_parsec.sh#L71-L85) |

上游取舍见 [上游差异](./pkgforge-differences.md)，固定参数见 [固定配置](./hardcoded.md)，故障与验证历史见 [README](../README.md#修复与变更记录)。
