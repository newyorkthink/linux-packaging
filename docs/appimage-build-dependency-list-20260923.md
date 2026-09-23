# AppImage 构建依赖清单

本清单供编写或修改应用目录的 `build_*.sh` 时选取软件包。软件包安装位置是该应用的 GitHub Actions 临时构建环境，不是用户主机。Arch Linux / quick-sharun 与 Ubuntu / linuxdeploy 分开选，不能混用包名；Qt 5 与 Qt 6 也不能混装。已有项目以其 README 和已验证脚本为基线，不因本清单批量改写。

**选取顺序：基础包 → 应用本体及其包管理器依赖 → 与实际主程序匹配的一组 Qt / GTK 包 → 有证据需要的功能包。** “基础必装”指该打包路线的新脚本需要的工具，不表示把所有框架包装进每个应用。上游 DEB / Arch 包声明的依赖仍由包管理器安装；包名清单不能代替 AppImage 内对动态加载库、输入法模块和插件的实际收集。

## Arch Linux：quick-sharun / sharun

### 基础必装包

在 **GitHub Actions 的 Arch Linux 构建容器**执行。第一条保持仓库 `AGENTS.md` 第 13 节已确认的基础命令，`base-devel` 本身是一组包，已包含 GCC、Make、pkgconf 等编译工具，不需要重复逐个列出：

```bash
# 安装 quick-sharun / AppImage 打包所需的最小基础工具
yay -S --noconfirm base-devel git wget curl jq binutils patchelf file coreutils findutils \
  grep sed gawk tar gzip xz unzip rsync util-linux appstream-glib \
  desktop-file-utils zsync ca-certificates
```

下面按当前 Job 的实际命令补齐；`yay` 的现有初始化仍由公共 Action 完成，本清单不改变这条启动链。标准矩阵 Job 发布时使用 `gh`，需要 Arch 包 `github-cli`；源码构建使用 CMake、Ninja 或 Python 时，再安装对应工具；`pkgconf` 已由 `base-devel` 提供。脚本实际调用 `unsquashfs` 解包 Snap / 上游 AppImage 时才需要 `squashfs-tools`，不把它当作所有应用的基础依赖。

```bash
# 标准矩阵 Job 发布 Release 前安装 GitHub CLI
yay -S --noconfirm github-cli

# 应用从源码构建且实际调用对应工具时安装编译工具
yay -S --noconfirm cmake ninja python

# 应用实际调用 unsquashfs 时安装解包工具
yay -S --noconfirm squashfs-tools
```

因此，标准 Arch 矩阵构建的完整选包至少是**第一条基础命令 + `github-cli` + 应用包**；源码编译、Snap 解包和 Qt / GTK 等框架包再从对应分类追加。`jq` 已在基础命令中，属于构建期 JSON 解析工具。应用本体的 Arch / AUR 包另外安装，并让包管理器拉入它声明的依赖。

| 应用类别 | 该类别的起始包组 | 仅在实际使用时追加 |
| --- | --- | --- |
| Qt 5 GUI | `qt5-base qt5-svg ibus fcitx5-qt libxcb libxkbcommon libxkbcommon-x11` | `qt5-x11extras`、主题插件、应用实际用到的 Qt 模块 |
| Qt 6 GUI | `qt6-base qt6-svg ibus fcitx5-qt libxcb libxkbcommon libxkbcommon-x11` | `qt6-declarative`（QML）、`qt6-multimedia`、`qt6-imageformats`、`qt6-wayland`、`qt6-tools`、主题插件 |
| GTK 3 GUI | `gtk3 glib2 gdk-pixbuf2 cairo pango at-spi2-core ibus fcitx5-gtk` | `webkit2gtk-4.1`、`libsoup3`、`glib-networking`、应用实际用到的 GIO / GStreamer 模块 |
| GTK 4 GUI | `gtk4 glib2 gdk-pixbuf2 cairo pango at-spi2-core ibus fcitx5-gtk` | `libadwaita`、应用实际用到的 WebKit / GStreamer 模块 |
| Electron / Chromium 上游二进制 | `gtk3 nss nspr alsa-lib at-spi2-core cups dbus glib2 pango cairo fontconfig freetype2 libx11 libxcb libxcomposite libxdamage libxfixes libxkbcommon libxrandr libxss ibus fcitx5-gtk` | `libsecret`、`libnotify`、音视频和图形后端按上游及实际缺失选择 |

Qt 主版本由实际 ELF 依赖或上游自带运行库决定；GUI 按仓库 `AGENTS.md` 和 `anylinux_projects.md` 还需生成并打包 `zh_CN.UTF-8`，同时收入与实际 GUI 版本相符的 IBus 和 Fcitx5 输入模块；只在终端运行的程序不加中文环境或输入模块。`fcitx5-qt` 虽提供 Qt 集成，最终收入 AppImage 的 `platforminputcontexts` 仍必须与主程序的 Qt 主版本一致。GTK 3 / 4 的 `fcitx5-gtk` 模块也必须按实际 GTK 主版本收入产物。Electron 如果自带 Chromium / GTK 库，先保持上游运行时，不用表中包覆盖它。

### 标准矩阵 Job 的发布工具

当前标准矩阵 Job 的共享发布步骤使用 `gh`，因此在“公共环境完全不安装包”的目标下，**每个该类 Job 自身还必须提供 `github-cli`**；对应安装命令已放在上面。`github-cli` 是 CI 发布工具，不会因为安装在构建容器里就自动进入 AppImage。仅同步官方 AppImage 而不执行 quick-sharun 的 Job，不机械套用整组构建基础包。

## Ubuntu：linuxdeploy + appimagetool

### 基础必装包

在 **GitHub Actions 的 Ubuntu 构建环境**执行。前两条和打包基础命令保持仓库 `AGENTS.md` 第 13 节现有写法；最后一条补齐直接使用的下载、JSON 和归档工具。调用 `common/apt/install_packages.sh` 时，它会自行安装其中一部分工具，不用在同一脚本重复安装。

```bash
# 更新 Ubuntu 软件包索引
sudo apt-get update

# 安装基础包管理工具
sudo apt-get install -y aptitude

# 安装 linuxdeploy / appimagetool 打包所需的最小基础工具
sudo aptitude install -y build-essential git wget binutils patchelf file \
  appstream-util desktop-file-utils zsync ca-certificates

# 直接调用下载、JSON 与归档命令的脚本补齐对应工具
sudo apt-get install -y curl jq coreutils findutils grep sed gawk tar gzip \
  xz-utils unzip rsync util-linux
```

```bash
# Ubuntu Job 自己使用 gh 发布 Release 时安装 GitHub CLI
sudo apt-get install -y gh

# 应用从源码构建且实际调用对应工具时安装编译工具
sudo apt-get install -y python3 cmake ninja-build pkg-config
```

应用来自 DEB 时，在同一 Ubuntu 构建环境安装该 DEB 及其依赖，并把同一 DEB 解包到 AppDir；linuxdeploy 才能从对应环境收集依赖。linuxdeploy、输入插件、appimagetool 和 Type 2 runtime 继续由仓库现有公共工具入口动态取得，不固定版本，也不把某个输入插件预装给所有项目。

| 应用类别 | Ubuntu 版本及起始包组 | 仅在实际使用时追加 |
| --- | --- | --- |
| Qt 5 GUI | 22.04：`qtchooser qt5-qmake qt5-qmake-bin qtbase5-dev qtbase5-dev-tools libqt5svg5 qttranslations5-l10n qt5-gtk-platformtheme qtwayland5 ibus fcitx5-frontend-qt5 libfcitx5-qt1 libxkbcommon-x11-0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-render-util0 libxcb-xinerama0 libxcb-xkb1` | QML、Multimedia、GStreamer 模块按应用真实依赖追加；现有 XnView MP 有更完整且已验证的专用清单 |
| Qt 6 GUI | 24.04：`qmake6 qt6-base-dev qt6-base-dev-tools qt6-qpa-plugins qt6-gtk-platformtheme qt6-translations-l10n ibus fcitx5-frontend-qt6 libxkbcommon-x11-0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-render-util0 libxcb-xinerama0 libxcb-xkb1` | `adwaita-qt6`、Qt Multimedia / QML 等只按上游实际使用情况追加 |
| GTK 3 GUI | 22.04：`libgtk-3-0 ibus ibus-gtk3 fcitx5-frontend-gtk3`；24.04：`libgtk-3-0t64 ibus ibus-gtk3 fcitx5-frontend-gtk3` | WebKit、GIO、GStreamer 模块按应用实际使用情况追加 |
| GTK 4 GUI | 24.04：`libgtk-4-1 ibus ibus-gtk4 fcitx5-frontend-gtk4` | 使用 libadwaita 时加 `libadwaita-1-0`；其余插件按实际使用情况追加 |

Ubuntu 22.04 与 24.04 的包名、ABI 和上游自带 Qt / GTK 库不能混用。GUI 项目默认打包 `zh_CN.UTF-8`、IBus 和 Fcitx5 输入模块，Qt / GTK 插件必须与主程序主版本一致；命令行程序不加中文环境或输入法；最终封装仍按仓库 `linuxdeploy_projects.md` 执行。若 Job 自己用 `gh` 发布 Release，在取消公共安装后由该 Job 提供 Ubuntu 的 `gh` 包；不能把 Ubuntu 包名 `gh` 写成 Arch 的 `github-cli`。

## 按功能追加，不纳入所有应用基础包

| 功能 | Arch 包例 | Ubuntu 包例 | 选择依据 |
| --- | --- | --- | --- |
| X11 / XCB 扩展 | `libx11 libxext libxrender libxrandr libxfixes xcb-util xcb-util-image xcb-util-keysyms xcb-util-renderutil xcb-util-wm` | `libx11-6 libxext6 libxrender1 libxrandr2 libxfixes3 libxcb-image0 libxcb-keysyms1 libxcb-render-util0` | 主程序、Qt platform plugin 或其他插件的实际 ELF 依赖 |
| OpenGL / Mesa | `libglvnd mesa` | `libgl1 libglvnd0` | 程序或渲染后端确实需要；驱动不盲目打进 AppImage |
| 音频 / 视频 | `alsa-lib libpulse pipewire ffmpeg` | `libasound2 libpulse0 ffmpeg`；22.04 用 `libpipewire-0.3-0`，24.04 用 `libpipewire-0.3-0t64` | 上游功能、插件与实际加载路径 |
| 桌面集成 | `libsecret libnotify xdg-utils shared-mime-info hicolor-icon-theme` | `libsecret-1-0 libnotify4 xdg-utils shared-mime-info hicolor-icon-theme` | Secret Service、通知、打开链接、MIME、图标等实际功能 |

这些是**选包目录**，不是让 AI 把整行追加进所有脚本。已安装的软件包不一定被 quick-sharun 或 linuxdeploy 自动带入最终 AppImage；`dlopen` 库、Qt / GTK 输入模块、GIO / GStreamer 插件和资源目录必须以应用实际加载方式及现有产物证据单独核对。不要为补一个缺失库复制整套 `/usr/lib`，也不要把用户主机的包当作 CI 构建依赖。

## 当前仓库与清单的边界

本文件只列依赖，没有调整任何构建脚本或 Action。当前 `.github/actions/build-anylinux/action.yml` 仍在公共步骤准备 `yay` 并安装 `github-cli jq`；因此“公共环境不安装包”**尚未实现**。以后若要移除这些公共安装步骤，必须先让每个受影响的 Job 自行具备包管理器和发布工具，并核对发布入口，否则会再次出现一部分应用成功、一部分在发布阶段缺命令的情况。
