# Modern CSV AppImage

## 用途

本目录将 Modern CSV Linux 稳定版重新封装为 AppImage，产物名固定为：

```text
moderncsv.AppImage
```

上游与打包参考：

- Modern CSV：`https://www.moderncsv.com/`
- 官方 Linux tar 包：`https://www.moderncsv.com/release/ModernCSV-Linux-v2.4.3.tar.gz`
- pkgforge-dev `quick-sharun`：`https://github.com/pkgforge-dev/Anylinux-AppImages`
- 官方说明：`https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/HOW-TO-MAKE-THESE.md`
- 仓库基线：`copyq/build_copyq.sh`

## 打包环境

Modern CSV 使用仓库统一的 Arch Linux / AnyLinux quick-sharun 构建环境。

`.github/workflows/build.yml` 中的 Modern CSV Job 与 CopyQ 等标准项目一样，直接复用：

```text
ghcr.io/pkgforge-dev/archlinux:latest
pkgforge-dev/anylinux-setup-action
.github/actions/build-anylinux
```

应用脚本本身不再启动额外 Docker / chroot，也不重复下载 quick-sharun。

## 打包流程

`build_moderncsv.sh` 保持普通 quick-sharun 项目的简单结构：

1. 设置 `STARTUPWMCLASS`、`ICON`、`DESKTOP`、`OUTPATH`、`OUTNAME`、`DEPLOY_OPENGL`。
2. 使用 `yay` 安装 quick-sharun 通用基础依赖和 Modern CSV 所需的非 Qt 系统运行依赖。
3. 下载官方 `ModernCSV-Linux-v2.4.3.tar.gz`，去掉最外层 `moderncsvv2.4.3/` 后，直接完整解压到 `AppDir/bin/`，保留官方 `moderncsv`、`moderncsv.desktop`、`moderncsv.png`、`lib/`、`plugins/`、`qt.conf` 等内容。
4. `ICON` 和 `DESKTOP` 直接使用 `AppDir/bin/` 中的官方文件；不设置 `QT_LOCATION`，也不再使用额外的 `/usr/lib/moderncsv` staging 目录。
5. 直接执行：

```bash
quick-sharun ./AppDir/bin/moderncsv
```

6. 只在 `AppDir/.env` 补充当前需要的中文 locale 与 XCB 环境：

```text
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
QT_QPA_PLATFORM=xcb
```

7. 使用 `xvfb-run` 对生成的 `AppDir/AppRun` 做最小启动级 smoke test。
8. 最后执行：

```bash
quick-sharun --make-appimage
```

## AppDir 结构说明

官方 tar 是先完整解压进 `AppDir/bin/`。随后 quick-sharun 会重排入口：最终 `AppDir/bin/moderncsv` 可能变成 sharun 启动入口，原始 ELF 被放到 `AppDir/shared/bin/moderncsv`。这属于 quick-sharun 的正常布局，不代表 tar 只解压了一个文件。

## Qt 与中文输入

Modern CSV 官方 Linux tar 自带 Qt 运行库、plugin 和 `qt.conf`。当前脚本直接保留官方目录结构，不额外设置 `QT_LOCATION`、`LD_LIBRARY_PATH`、`QT_PLUGIN_PATH` 或 `QT_QPA_PLATFORM_PLUGIN_PATH`。

Qt5 与 Qt6 都有各自主版本对应的 Compose、Fcitx5、IBus 输入上下文；如果后续确认某个输入 plugin 确实缺失或不兼容，再针对实际运行错误做最小修复，不在普通 quick-sharun 基线里预先加入复杂重建逻辑。

这里的中文环境只负责 UTF-8 locale 和 Linux 输入环境，不向 Modern CSV 注入非官方中文界面翻译。

## 特殊处理原则

CopyQ 中 `lib/copyq/plugins` 的符号链接修复属于 CopyQ 自身插件搜索行为，不复制到 Modern CSV。

普通程序默认保持“准备上游程序与依赖 -> quick-sharun 主程序 -> 必要 `.env` -> `--make-appimage`”这条主线。只有出现明确、可复现的程序特有错误时才增加最小特殊处理。

## 修复记录

### 2026-09-03：恢复直接 AppDir/bin 打包结构

- 删除 `INSTALL_DIR=/usr/lib/moderncsv`。
- 删除 `QT_LOCATION`。
- 官方 tar 直接完整解压到 `AppDir/bin/`。
- quick-sharun 入口固定为 `./AppDir/bin/moderncsv`。
- 不再引入额外 staging 路径或复杂 Qt plugin 重建逻辑。
