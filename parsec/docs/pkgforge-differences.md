# Parsec 官方处理取舍

## 来源

参考的 pkgforge-dev 上游仓库快照为 `312e92ecd1dea7948a9e331f6ae31bb2e88df882`（对应索引见 [上游打包参考索引](../../Docs/upstream-packaging-index.md)）：[依赖脚本](https://github.com/pkgforge-dev/parsec-AppImage/blob/312e92ecd1dea7948a9e331f6ae31bb2e88df882/get-dependencies.sh)、[封装脚本](https://github.com/pkgforge-dev/parsec-AppImage/blob/312e92ecd1dea7948a9e331f6ae31bb2e88df882/make-appimage.sh) 与 [workflow](https://github.com/pkgforge-dev/parsec-AppImage/blob/312e92ecd1dea7948a9e331f6ae31bb2e88df882/.github/workflows/appimage.yml)。

| 处理项 | 本仓库当前决定 | 对应位置 | 说明与依据 |
| --- | --- | --- | --- |
| 软件安装与 DEB 下载 | 改用本仓库统一的两阶段公共入口（`--aur-deb` + `download_deb_source.sh`），显式开启 `--wayback` 与 `--source-filename 'parsec-bin-{version}.deb'`。 | [安装阶段](../build_parsec.sh#L11-L13)、[独立下载](../build_parsec.sh#L21-L24) | 统一纳入公共 AUR DEB 校验与缓存控制，不直接在应用脚本中调用 `yay` 或写死下载命令。 |
| 版本读取与导出 | 通过 `read_app_version.sh pacman "parsec-bin"` 读取去除 epoch/pkgrel 后的上游版本，并用 `save_appimage_version.sh` 写入 `dist/version.txt`。 | [版本读取](../build_parsec.sh#L61)、[版本保存](../build_parsec.sh#L85) | 对齐本仓库 `.github/workflows/build.yml` 标准矩阵发布的版本清单机制，不启用上游自更新 `UPINFO` / hook。 |
| 桌面入口与图标路径 | 直接使用实测官方 DEB 确认的 `/usr/share/icons/hicolor/256x256/apps/parsecd.png` 与 `/usr/share/applications/parsecd.desktop`。 | [桌面与图标](../build_parsec.sh#L46-L48) | 避免脚本内调用 `pacman -Ql` 探测，参数简洁明确。 |
| 解码库、skel 与图形后端 | 显式收集 `parsecd`、`parsecd-*.so`、FFmpeg 4.4（`.58`/`.56`/`.3`）、`libjpeg.so.8` 与通用 `libva*.so.2`；保留 `/usr/share/parsec` 与 `PATH_MAPPING`、`DEPLOY_OPENGL=1`、`DEPLOY_PIPEWIRE=1`、`DEPLOY_LOCALE=1`、`NO_STRIP=1`。 | [收集与映射](../build_parsec.sh#L54-L68) | 依据本仓库 [2026-09-14 回归记录](../README.md#修复与变更记录)，保留已验证解决 `Decoder` 空白和 `libjpeg8` 缺失的运行库基线，不捆绑厂商 GPU 解码 backend，避免启动黑屏。 |
| 中文环境与输入法 | 在 `AppDir/lib/locale` 生成 `zh_CN.utf8` 并在 `AppDir/.env` 设置 `LANG`、`LANGUAGE`、`LC_CTYPE`、`LC_MESSAGES`、`LOCPATH`；不强行注入 Qt/GTK 输入法插件或覆盖 `XMODIFIERS`。 | [中文 locale](../build_parsec.sh#L71-L79) | 与 Parsec 闭源原生客户端依赖边界一致，继承宿主桌面已配置的输入法环境。 |

详细阶段差异见 [模板差异](./template-deviations.md)，固定配置见 [固定配置](./hardcoded.md)。
