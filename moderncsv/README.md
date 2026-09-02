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
2. 使用 `yay` 安装 quick-sharun 通用基础依赖，以及 Modern CSV 官方 Qt6 运行时需要的 OpenSSL、OpenGL、XKB / XCB 等非 Qt 系统依赖；不再安装 Arch 当前版本的 `qt6-base`、`qt6-5compat`、`fcitx5-qt`。
3. 下载官方 `ModernCSV-Linux-v2.4.3.tar.gz`，去掉压缩包最外层 `moderncsvv2.4.3/` 目录后，完整解压到 `AppDir/bin/`；保留官方 `moderncsv`、`moderncsv.desktop`、`moderncsv.png`、`lib/`、`plugins/`、`qt.conf` 等全部内容。
4. `ICON` 和 `DESKTOP` 直接指向 `AppDir/bin/` 中的官方文件，然后执行：

```bash
quick-sharun ./AppDir/bin/moderncsv
```

5. 只在 `AppDir/.env` 补充当前需要的中文 locale 与 XCB 环境：

```text
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
QT_QPA_PLATFORM=xcb
```

6. 最后直接执行：

```bash
quick-sharun --make-appimage
```

构建脚本不加入 smoke test、启动测试、测试 workflow 或其他测试代码。

## AppDir 结构说明

`quick-sharun` 完成后，`AppDir/bin/moderncsv` 是 sharun 生成的启动入口；原始 Modern CSV ELF 会放在 `AppDir/shared/bin/moderncsv`。因此最终 `AppDir/bin` 只看到一个 `moderncsv` 属于正常的 sharun 布局，并不表示官方 tar 只解压了一个文件。

官方 tar 直接在 `AppDir/bin/` 中准备，不再使用 `$PWD/moderncsv-source` 或 `/usr/lib/moderncsv` 这类额外 staging 路径。

## Qt 与中文输入

Modern CSV 官方 Linux tar 包自带 Qt 运行库和 plugin。当前打包优先保持官方运行时，不把 Arch 当前 Qt6 运行库直接混入。

Qt5 与 Qt6 都有各自主版本对应的 Compose、Fcitx5、IBus 输入上下文；除了 Qt 主版本必须一致外，实际 plugin 还必须与最终 Qt runtime ABI 兼容。官方 tar 缺少或包含不兼容的输入上下文 plugin 时，需要单独针对实际 Qt runtime 处理，不能仅为了凑齐文件名直接复制其他 Qt 版本的 plugin。

本脚本不设置 `LD_LIBRARY_PATH`、`QT_PLUGIN_PATH`、`QT_QPA_PLATFORM_PLUGIN_PATH` 或 `QT_LOCATION`，避免人为覆盖 quick-sharun 和官方 Qt runtime 的正常搜索关系。

这里的中文环境只负责 UTF-8 locale 和 Linux 输入环境，不向 Modern CSV 注入非官方中文界面翻译。

## 特殊处理原则

CopyQ 中 `lib/copyq/plugins` 的符号链接修复属于 CopyQ 自身插件搜索行为，不复制到 Modern CSV。

普通程序默认保持“准备上游程序与依赖 -> 设置 quick-sharun 变量 -> quick-sharun 主程序 -> 必要 `.env` -> `--make-appimage`”这一条主线。只有程序出现能够明确定位的特有运行问题时，才增加对应的最小兼容处理；不得加入测试代码。

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
