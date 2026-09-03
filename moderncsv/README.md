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

官方 `ModernCSV-Linux-v2.4.3.tar.gz` 的主程序明确链接 Qt6，随包 `libQt6Core.so.6` 为 Qt 6.4.3；但官方 `plugins/` 中除 `platforms/libqxcb.so` 外存在多项仍链接 Qt5 的 plugin，并且缺少 Qt6 TLS backend 和 Fcitx5 Qt6 输入上下文。当前打包因此只保留官方应用本体、desktop 和 icon，不再把官方 `lib/`、`plugins/`、`qt.conf` 带入 AppDir；Qt runtime 与 plugin 统一改由同一次 Arch 构建环境中的 Qt6 包提供，再交给 quick-sharun 收集。

## 打包流程

`build_moderncsv.sh` 保持普通 quick-sharun 项目的简单结构：

1. 设置 `STARTUPWMCLASS`、`ICON`、`DESKTOP`、`OUTPATH`、`OUTNAME`、`DEPLOY_OPENGL`。
2. 已有非 Qt 系统依赖命令保持不变；另起一条独立 `yay` 命令安装 `qt6-base`、`qt6-5compat`、`qt6-svg`、`qt6-imageformats`、`fcitx5-qt`，使 Qt6 library、TLS plugin、图像 plugin、Compose / IBus / Fcitx5 输入上下文来自同一套 Arch Qt6 环境。
3. 下载官方 `ModernCSV-Linux-v2.4.3.tar.gz`，只从最外层 `moderncsv2.4.3/` 中提取：

```text
moderncsv
moderncsv.desktop
moderncsv.png
```

4. 不提取官方 `lib/`、`plugins/`、`qt.conf`，避免继续携带官方包中的 Qt5 / Qt6 plugin 混装。
5. `ICON` 和 `DESKTOP` 直接指向 `AppDir/shared/bin/` 中的官方文件，然后执行：

```bash
quick-sharun ./AppDir/shared/bin/moderncsv
```

6. quick-sharun 根据 Modern CSV 的 Qt6 ELF 依赖从 Arch Qt6 plugin 根目录收集 `platforms/`、`platforminputcontexts/`、`platformthemes/`、`imageformats/`、`iconengines/`、`xcbglintegrations/` 和 `tls/` 等需要的 plugin，并同时收集对应动态库。
7. 最后直接执行：

```bash
quick-sharun --make-appimage
```

构建脚本不加入 smoke test、启动测试、测试 workflow 或其他测试代码。

## AppDir 结构说明

官方应用本体先放入 `AppDir/shared/bin/`。该目录只保留 Modern CSV 自身的 `moderncsv`、`moderncsv.desktop` 和 `moderncsv.png`，不再保留官方 Qt runtime 目录。

`quick-sharun` 使用 `AppDir/shared/bin/` 保存真实程序，并在 `AppDir/bin/` 为对应程序生成 sharun 启动入口。因此最终结构中，`AppDir/bin/moderncsv` 是启动入口，真实 Modern CSV ELF 位于 `AppDir/shared/bin/moderncsv`；统一的 Qt6 动态库和 plugin 由 quick-sharun 部署到其标准 AppDir 目录。

不再使用 `$PWD/moderncsv-source` 或 `/usr/lib/moderncsv` 这类额外 staging 路径。

## Qt 与中文输入

Modern CSV 2.4.3 主程序本身是 Qt6 程序。当前打包不再沿用官方 tar 中混有 Qt5 plugin 的 `plugins/`，而是让 Qt6 runtime 与全部 Qt plugin 来自同一次 Arch Qt6 构建环境。

`qt6-base` 提供 Qt6 的 Compose / IBus `platforminputcontexts` 和 TLS backend；`fcitx5-qt` 提供 Qt6 的 `libfcitx5platforminputcontextplugin.so`；`qt6-svg` 与 `qt6-imageformats` 提供对应的 Qt6 SVG / 图像 plugin。这样最终 `platforminputcontexts/` 中的 Compose、IBus、Fcitx5 plugin 与最终 Qt runtime 保持同一 Qt 主版本和同一构建环境，不再混入 Qt5 input context。

本脚本不设置 `LD_LIBRARY_PATH`、`QT_PLUGIN_PATH`、`QT_QPA_PLATFORM_PLUGIN_PATH` 或 `QT_LOCATION`，避免人为覆盖 quick-sharun 的 Qt runtime / plugin 搜索关系；也不强制设置 `QT_IM_MODULE`，由宿主输入法环境选择 Fcitx5、IBus 或 Compose。

这里的中文环境只负责 Linux 输入法兼容，不向 Modern CSV 注入非官方中文界面翻译。

## 特殊处理原则

CopyQ 中 `lib/copyq/plugins` 的符号链接修复属于 CopyQ 自身插件搜索行为，不复制到 Modern CSV。

普通程序默认保持“准备上游程序与依赖 -> 设置 quick-sharun 变量 -> quick-sharun 主程序 -> 必要运行环境 -> `--make-appimage`”这一条主线。只有程序出现能够明确定位的特有运行问题时，才增加对应的最小兼容处理；不得加入测试代码。

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
