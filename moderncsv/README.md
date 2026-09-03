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

官方 `ModernCSV-Linux-v2.4.3.tar.gz` 的主程序和随包运行库属于 Qt 6.4.3；这套官方 Qt runtime 必须保持为 Modern CSV 的运行时基线，不能用 Arch 当前 Qt6 替换。官方 `plugins/` 中除 `platforms/libqxcb.so` 外，多项 plugin 实际仍链接 Qt5，并且缺少 Qt6 TLS backend 和 Fcitx5 Qt6 输入上下文。因此当前打包完整保留官方 `lib/`，只清理官方混合 plugin 树，再补入与 Qt 6.4.3 同一 Qt 6.4 系列的 Debian Bookworm Qt 6.4.2 Compose / IBus / Fcitx5 输入插件和 TLS backend。

## 打包流程

`build_moderncsv.sh` 保持 quick-sharun 主线，同时对 Modern CSV 的 Qt runtime / plugin 组合做最小兼容处理：

1. 设置 `STARTUPWMCLASS`、`ICON`、`DESKTOP`、`OUTPATH`、`OUTNAME`、`DEPLOY_OPENGL`，并将 `QT_LOCATION` 指向官方完整程序目录 `moderncsv-source`。
2. 现有非 Qt 系统依赖命令保持不变；不安装 Arch `qt6-base`、`qt6-5compat`、`qt6-svg`、`qt6-imageformats`、`fcitx5-qt`，避免 Arch Qt 6.11.x 覆盖官方 Qt 6.4.3 runtime。
3. 下载官方 `ModernCSV-Linux-v2.4.3.tar.gz`，完整解压到 `moderncsv-source/`，保留官方主程序、`lib/`、desktop、icon、`qt.conf` 和 Qt6 XCB platform plugin。
4. 先保存官方 `plugins/platforms/libqxcb.so`，删除其余混有 Qt5 的官方 plugin，再重建干净的 Qt6 plugin 目录。
5. 固定下载 Debian Bookworm Qt 6.4.2 / Fcitx5 兼容包，只提取并补入以下运行组件：

```text
plugins/platforms/libqxcb.so                        官方 Qt 6.4.3
plugins/platforminputcontexts/libcompose*.so       Debian Qt 6.4.2
plugins/platforminputcontexts/libibus*.so          Debian Qt 6.4.2
plugins/platforminputcontexts/libfcitx5*.so        Debian Qt 6.4.2 ABI
plugins/tls/libqcertonlybackend.so                  Debian Qt 6.4.2
plugins/tls/libqopensslbackend.so                   Debian Qt 6.4.2
lib/libFcitx5Qt6DBusAddons.so.1*                   Debian Bookworm
lib/libFcitx5Utils.so.2*                            Debian Bookworm
```

6. Debian 兼容包只提供缺失 plugin 和 Fcitx5 运行库，不复制其中的 `libQt6*.so`；最终 Qt Core / Gui / Widgets / Network / PrintSupport 等主运行库仍全部来自 Modern CSV 官方 Qt 6.4.3。
7. 执行：

```bash
quick-sharun "$SOURCE_DIR/moderncsv"
```

8. 最后直接执行：

```bash
quick-sharun --make-appimage
```

构建脚本不加入 smoke test、启动测试、测试 workflow 或其他测试代码。

## AppDir 结构说明

官方完整程序目录先解压到 AppDir 外部的 `$PWD/moderncsv-source`。该目录作为 `QT_LOCATION`，使 quick-sharun 从官方 Qt 6.4.3 runtime 和清理后的 Qt6 plugin 树收集实际运行内容，而不是从 Arch 当前 Qt6 包收集 Qt runtime。

`quick-sharun` 最终仍按标准结构生成 `AppDir/bin/`、`AppDir/shared/bin/`、`AppDir/lib/` 等运行目录；`moderncsv-source` 只是构建期 staging 目录，不作为最终 AppImage 内的额外安装前缀。

## Qt 与中文输入

Modern CSV 2.4.3 主程序使用 Qt6，并且官方运行库为 Qt 6.4.3。当前打包固定保留这套官方 Qt runtime，避免再触发 Arch Qt 6.11.x 与主程序之间的 protected symbol / GNU property 冲突。

官方 tar 自带的 Compose / IBus input context 实际链接 Qt5，因此不能继续放在 Qt6 plugin 路径中；当前改用 Debian Bookworm Qt 6.4.2 的 Compose / IBus plugin，并补入同样针对 Qt 6.4.2 ABI 构建的 Fcitx5 Qt6 input context。Qt 6.4.2 与官方 Qt 6.4.3 属于同一 Qt 6.4 系列，且补充包不替换任何官方 `libQt6*.so`。

TLS 同样只补入 Debian Bookworm `libqt6network6` 提供的 Qt 6.4.2 OpenSSL / certificate-only backend；主程序实际使用的 `libQt6Network.so.6` 继续来自官方 Qt 6.4.3。

本脚本不强制设置 `QT_IM_MODULE`，由宿主输入法环境选择 Fcitx5、IBus 或 Compose；这里的中文环境只负责 Linux 输入法兼容，不向 Modern CSV 注入非官方中文界面翻译。

## 特殊处理原则

CopyQ 中 `lib/copyq/plugins` 的符号链接修复属于 CopyQ 自身插件搜索行为，不复制到 Modern CSV。

Modern CSV 的特殊点是“官方 Qt6 runtime + 官方混入 Qt5 plugin”。因此只针对这一根因保留官方 Qt runtime、重建 plugin 树并补齐缺失的同代 Qt6 plugin；不得再次用构建机当前 Qt runtime 覆盖官方 runtime，也不得加入测试代码。

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

### 2026-09-03：恢复官方 Qt 6.4.3 runtime，修复 GNU_PROPERTY 启动崩溃

- 故障现象：最新 Release AppImage 在 Kali Linux 启动时，`libQt6Widgets.so.6` 报 `direct reference to protected function`，随后因 `GNU_PROPERTY_1_NEEDED_INDIRECT_EXTERN_ACCESS` 直接终止。
- 根因核实：故障 AppImage 内的 `libQt6Widgets.so.6` 已被替换为 Arch Qt 6.11.2，并带有 `1_needed: indirect external access` GNU property；Modern CSV 主程序对 `QStyledItemDelegate::initStyleOption` 存在直接符号引用。官方 tar 自带的 Qt 6.4.3 `libQt6Widgets.so.6` 不带该 property，因此将官方 Qt 6.4.3 runtime 整体替换为 Arch Qt 6.11.2 是本次启动崩溃的直接原因。
- 修改文件：`moderncsv/build_moderncsv.sh`、`moderncsv/README.md`。
- 修复内容：删除 Arch Qt6 runtime/plugin 安装命令，恢复完整官方 Qt 6.4.3 runtime，并重新启用 `QT_LOCATION="$SOURCE_DIR"`；官方 plugin 树只保留同包 Qt6 `libqxcb.so`，其余 Qt5 plugin 删除。TLS、Compose / IBus 和 Fcitx5 Qt6 input context 改为只补入 Debian Bookworm Qt 6.4.2 同代 plugin，同时补入对应 Fcitx5 运行库，且不复制 Debian 的任何 `libQt6*.so`。
- 已知结果：已对用户实际报错 AppImage 与官方 `ModernCSV-Linux-v2.4.3.tar.gz` 的 ELF 属性、QtWidgets 符号和 plugin Qt 主版本完成静态核对；构建脚本已通过 `bash -n` 静态语法检查，未加入 smoke test 或其他测试代码。最终运行结果以本次 GitHub Actions 正常构建后的实机反馈为准。
