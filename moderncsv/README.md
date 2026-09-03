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

当前 `build_moderncsv.sh` 复用仓库 quick-sharun Qt6 通用基础环境，基础命令单独保持，不把当前应用的额外依赖混入其中。基础环境覆盖 Qt6、GTK3/GTK4、Fcitx5/Rime、TLS/OpenSSL、X11/XCB、Wayland、OpenGL、字体、图标、SVG/QML/Multimedia、打印和主题插件等构建期依赖；当前 Modern CSV 没有需要在该通用基线之外额外安装的软件包。Modern CSV 官方 tar 自带的 `lib/`、`plugins/` 和 `qt.conf` 仍保持原有目录关系，不直接用系统 Qt 文件覆盖官方目录。

## 打包流程

`build_moderncsv.sh` 保持普通 quick-sharun 项目的简单结构：

1. 设置 `STARTUPWMCLASS`、`ICON`、`DESKTOP`、`OUTPATH`、`OUTNAME`、`DEPLOY_OPENGL`。
2. 使用独立的一条 `yay -S --noconfirm ...` 安装仓库 quick-sharun Qt6 通用基础环境，依赖列表按约每 10 个包换行；其中包含 Qt6、GTK3/GTK4、Fcitx5、Fcitx5 Qt/GTK、Fcitx5 Rime、OpenSSL/NSS、X11/XCB、Wayland、OpenGL、字体、图标、SVG/QML/Multimedia、打印及主题插件，不安装 `ibus` / `ibus-rime`。
3. 当前 Modern CSV 没有额外软件包；后续如果出现项目特有依赖，必须另起一条独立 `yay` 命令，禁止并入通用基础命令。
4. 下载官方 `ModernCSV-Linux-v2.4.3.tar.gz`，去掉压缩包最外层 `moderncsvv2.4.3/` 目录后，完整解压到 `AppDir/shared/bin/`；保留官方 `moderncsv`、`moderncsv.desktop`、`moderncsv.png`、`lib/`、`plugins/`、`qt.conf` 等全部内容。
5. `ICON` 和 `DESKTOP` 直接指向 `AppDir/shared/bin/` 中的官方文件，然后执行：

```bash
quick-sharun ./AppDir/shared/bin/moderncsv
```

6. 只在 `AppDir/.env` 补充当前需要的中文 locale 与 XCB 环境：

```text
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
QT_QPA_PLATFORM=xcb
```

7. 最后直接执行：

```bash
quick-sharun --make-appimage
```

构建脚本不加入 smoke test、启动测试、测试 workflow 或其他测试代码。

## AppDir 结构说明

官方 tar 的完整程序目录先放入 `AppDir/shared/bin/`，使 `moderncsv` 与官方自带的 `lib/`、`plugins/`、`qt.conf` 保持原有相对目录关系。

`quick-sharun` 使用 `AppDir/shared/bin/` 保存真实程序，并在 `AppDir/bin/` 为对应程序生成 sharun 启动入口。因此最终结构中，`AppDir/bin/moderncsv` 是启动入口，真实 Modern CSV ELF 与其官方运行时目录位于 `AppDir/shared/bin/`。

不再使用 `$PWD/moderncsv-source` 或 `/usr/lib/moderncsv` 这类额外 staging 路径。

## Qt 与中文输入

Modern CSV 官方 Linux tar 包自带 Qt 运行库和 plugin。当前打包继续保持官方 runtime 的目录关系，同时在 Arch Linux 构建环境中准备与 Qt6 主版本一致的 Qt6、Fcitx5 Qt/GTK 和 Fcitx5 Rime 组件，供 quick-sharun 收集实际需要的运行库与输入环境；通用基础环境不安装 `ibus` / `ibus-rime`。

Qt5 与 Qt6 都有各自主版本对应的输入上下文；除了 Qt 主版本必须一致外，实际 plugin 还必须与最终 Qt runtime ABI 兼容。最终 AppImage 中的 `platforminputcontexts/` 必须保持 Qt6 主版本一致，不能把 Qt5 输入上下文 plugin 混入 Qt6 runtime。官方 runtime 已经携带的 plugin 不因基础依赖列表调整而擅自删除。

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
