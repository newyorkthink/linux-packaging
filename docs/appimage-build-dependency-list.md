# AppImage 构建依赖清单

本清单供编写或修改应用目录的 `build_*.sh` 时选取软件包。软件包安装位置是该应用的 GitHub Actions 临时构建环境，不是用户主机。Arch Linux / quick-sharun 与 Ubuntu / linuxdeploy 分开使用各自包名；Qt 5 与 Qt 6 也不能混装。已有项目以其 README 和已验证脚本为基线，不因本清单批量改写。

**选取顺序：统一基础包 → 应用本体及其包管理器依赖 → 与实际主程序匹配的一组 Qt / GTK 包 → 有证据需要的功能包。** 上游 DEB / Arch 包声明的依赖仍由包管理器安装；包名清单不能代替 AppImage 内对动态加载库、输入法模块和插件的实际收集。

## Arch Linux：quick-sharun / sharun

### 统一基础包

GitHub Actions 的 Arch Linux 构建容器使用同一套基础包。应用脚本以 `common/arch/install_packages.sh --base` 安装以下全部 95 个包；需要安装当前应用的额外依赖时，另以包名为参数调用同一个入口。`base-devel` 覆盖的工具仍显式列出，`jq` 和 `github-cli` 都包含在基础包内。以下命令中的反斜杠必须紧贴行尾：

v2rayN 因提前安装整套基础包曾在图形检查中出现 `free(): invalid pointer`，按 `AGENTS.md` 的应用特例使用精确依赖列表，并在打包前包含发布步骤需要的 `github-cli`；不在 AppImage 生成后再安装整套基础包。此例外不改变其他应用的基础包要求。

```bash
# 在 GitHub Actions 的 Arch Linux 构建容器中安装统一基础环境
yay -S --noconfirm base-devel archlinux-keyring gcc make pkgconf patch autoconf \
  automake binutils bison debugedit fakeroot file findutils flex gawk gettext \
  grep groff gzip libtool m4 pacman sed sudo texinfo which git wget curl jq \
  github-cli patchelf coreutils tar bzip2 xz zstd lz4 unzip zip 7zip rsync \
  util-linux appstream-glib desktop-file-utils shared-mime-info \
  hicolor-icon-theme xdg-utils zsync ca-certificates ca-certificates-utils \
  cmake ninja meson python perl squashfs-tools libarchive cpio elfutils \
  pax-utils chrpath openssl openssh gnupg dbus at-spi2-core nspr nss \
  nss-mdns avahi xdg-desktop-portal ibus xterm xclip xsel xorg-xrdb \
  wqy-microhei wqy-zenhei noto-fonts-emoji polkit glib2 pango gdk-pixbuf2 \
  libdrm libxkbcommon fontconfig xdotool openal lsb-release socat nginx \
  boost-libs inetutils
```

`yay` 和 `quick-sharun` 由当前 Arch 构建链提供；上述命令只安装软件包。基础环境中有 `ibus`、桌面运行库和字体，不表示 quick-sharun 会自动把它们全收入 AppImage。CLI 成品不加入中文环境或输入模块；GUI 必须按主程序真实技术栈收集对应输入模块。GTK、Qt、Fcitx 仍属于应用专用依赖。

| 应用类别 | 该类别的起始包组 | 仅在实际使用时追加 |
| --- | --- | --- |
| Qt 5 GUI | `qt5-base qt5-svg ibus fcitx5-qt libxcb libxkbcommon libxkbcommon-x11` | `qt5-x11extras`、主题插件、应用实际用到的 Qt 模块 |
| Qt 6 GUI | `qt6-base qt6-svg ibus fcitx5-qt libxcb libxkbcommon libxkbcommon-x11` | `qt6-declarative`（QML）、`qt6-multimedia`、`qt6-imageformats`、`qt6-wayland`、`qt6-tools`、主题插件 |
| GTK 3 GUI | `gtk3 glib2 gdk-pixbuf2 cairo pango at-spi2-core ibus fcitx5-gtk` | `webkit2gtk-4.1`、`libsoup3`、`glib-networking`、应用实际用到的 GIO / GStreamer 模块 |
| GTK 4 GUI | `gtk4 glib2 gdk-pixbuf2 cairo pango at-spi2-core ibus fcitx5-gtk` | `libadwaita`、应用实际用到的 WebKit / GStreamer 模块 |
| Electron / Chromium 上游二进制 | `gtk3 nss nspr alsa-lib at-spi2-core cups dbus glib2 pango cairo fontconfig freetype2 libx11 libxcb libxcomposite libxdamage libxfixes libxkbcommon libxrandr libxss ibus fcitx5-gtk` | `libsecret`、`libnotify`、音视频和图形后端按上游及实际缺失选择 |

Qt 主版本由实际 ELF 依赖或上游自带运行库决定；GUI 按仓库 `AGENTS.md` 和 `anylinux_projects.md` 还需生成并打包 `zh_CN.UTF-8`，同时收入与实际 GUI 版本相符的 IBus 和 Fcitx5 输入模块；只在终端运行的程序不加中文环境或输入模块。`fcitx5-qt` 虽提供 Qt 集成，最终收入 AppImage 的 `platforminputcontexts` 仍必须与主程序的 Qt 主版本一致。GTK 3 / 4 的 `fcitx5-gtk` 模块也必须按实际 GTK 主版本收入产物。Electron 如果自带 Chromium / GTK 库，先保持上游运行时，不用表中包覆盖它。

### 标准矩阵 Job 的发布工具

标准矩阵 Job 的发布步骤使用 `gh` 和 `jq`；Arch 基础包已显式包含 `github-cli jq`。这两个命令属于构建和发布环境，不会仅因安装在容器里就进入 AppImage。
v2rayN 的精确依赖列表也分别安装了 `github-cli` 与 `jq`，供同一 Job 的下载和发布使用。

## Ubuntu：linuxdeploy + appimagetool

### 统一基础包

Ubuntu 22.04／24.04 的基础包由 `common/apt/install_packages.sh` 在应用首次安装依赖时自动附加。Arch 包名不直接用于 Ubuntu：例如 `github-cli` 对应 `gh`，`appstream-glib` 对应 `appstream-util`，`ninja` 对应 `ninja-build`，`7zip` 对应 `p7zip-full`。以下为公共入口安装的全部 Ubuntu 包名；`libglib2.0-0` 只用于 22.04，`libglib2.0-0t64` 只用于 24.04：

```text
build-essential ubuntu-keyring gcc g++ make pkgconf patch autoconf automake
binutils bison debugedit fakeroot file findutils flex gawk gettext grep
groff gzip libtool m4 dpkg sed sudo texinfo debianutils git wget curl jq gh
patchelf coreutils tar bzip2 xz-utils zstd lz4 unzip zip p7zip-full rsync
util-linux appstream-util desktop-file-utils shared-mime-info
hicolor-icon-theme xdg-utils zsync ca-certificates cmake ninja-build meson
python3 perl squashfs-tools libarchive-tools cpio elfutils pax-utils chrpath
openssl openssh-client gnupg dbus at-spi2-core libnspr4 libnss3
libnss-mdns avahi-daemon xdg-desktop-portal ibus xterm xclip xsel
x11-xserver-utils fonts-wqy-microhei fonts-wqy-zenhei
fonts-noto-color-emoji polkitd libpango-1.0-0 libgdk-pixbuf-2.0-0
libdrm2 libxkbcommon0 fontconfig xdotool libopenal1 lsb-release socat
nginx libboost-all-dev inetutils-tools
22.04：libglib2.0-0
24.04：libglib2.0-0t64
```

`ca-certificates-utils` 在 Ubuntu 无独立同名包，`update-ca-certificates` 由 `ca-certificates` 提供；`pacman` 与 `archlinux-keyring` 在 Ubuntu 对应为 `dpkg` 与 `ubuntu-keyring`。公共入口继续接受应用专用包或本地 DEB 参数，并保留 `--no-update` 用于已更新索引后的本地 DEB 安装。

| 应用类别 | Ubuntu 版本及起始包组 | 仅在实际使用时追加 |
| --- | --- | --- |
| Qt 5 GUI | 22.04：`qtchooser qt5-qmake qt5-qmake-bin qtbase5-dev qtbase5-dev-tools libqt5svg5 qttranslations5-l10n qt5-gtk-platformtheme qtwayland5 ibus fcitx5-frontend-qt5 libfcitx5-qt1 libxkbcommon-x11-0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-render-util0 libxcb-xinerama0 libxcb-xkb1` | QML、Multimedia、GStreamer 模块按应用真实依赖追加；现有 XnView MP 有更完整且已验证的专用清单 |
| Qt 6 GUI | 24.04：`qmake6 qt6-base-dev qt6-base-dev-tools qt6-qpa-plugins qt6-gtk-platformtheme qt6-translations-l10n ibus fcitx5-frontend-qt6 libxkbcommon-x11-0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-render-util0 libxcb-xinerama0 libxcb-xkb1` | `adwaita-qt6`、Qt Multimedia / QML 等只按上游实际使用情况追加 |
| GTK 3 GUI | 22.04：`libgtk-3-0 ibus ibus-gtk3 fcitx5-frontend-gtk3`；24.04：`libgtk-3-0t64 ibus ibus-gtk3 fcitx5-frontend-gtk3` | WebKit、GIO、GStreamer 模块按应用实际使用情况追加 |
| GTK 4 GUI | 24.04：`libgtk-4-1 ibus ibus-gtk4 fcitx5-frontend-gtk4` | 使用 libadwaita 时加 `libadwaita-1-0`；其余插件按实际使用情况追加 |

Ubuntu 22.04 与 24.04 的包名、ABI 和上游自带 Qt / GTK 库不能混用。GUI 项目默认打包 `zh_CN.UTF-8`、IBus 和 Fcitx5 输入模块，Qt / GTK 插件必须与主程序主版本一致；命令行程序不加中文环境或输入法；最终封装仍按仓库 `linuxdeploy_projects.md` 执行。若 Job 自己用 `gh` 发布 Release，在取消公共安装后由该 Job 提供 Ubuntu 的 `gh` 包；不能把 Ubuntu 包名 `gh` 写成 Arch 的 `github-cli`。

## 基础包逐项说明

Arch 列逐项对应上面的 95 包；Ubuntu 列为功能对应包名，不表示两个发行版的 ABI 相同。Ubuntu 使用 `common/apt/install_packages.sh` 的完整清单，额外显式列出 `g++`。

| Arch 包 | Ubuntu 对应包 | 用途 |
| --- | --- | --- |
| `base-devel` | `build-essential、g++` | Arch 开发工具组，包含编译和打包常用程序 |
| `archlinux-keyring` | `ubuntu-keyring` | 发行版软件仓库签名密钥 |
| `gcc` | `gcc` | GNU C/C++ 编译器 |
| `make` | `make` | 按 Makefile 执行构建 |
| `pkgconf` | `pkgconf` | 查询库的编译和链接参数 |
| `patch` | `patch` | 应用源码补丁 |
| `autoconf` | `autoconf` | 生成 configure 脚本 |
| `automake` | `automake` | 生成 Autotools Makefile |
| `binutils` | `binutils` | 汇编、链接及 ELF 分析工具 |
| `bison` | `bison` | 生成语法分析器 |
| `debugedit` | `debugedit` | 调整调试信息中的源码路径 |
| `fakeroot` | `fakeroot` | 在打包时模拟文件属主权限 |
| `file` | `file` | 识别文件类型 |
| `findutils` | `findutils` | 查找和遍历文件 |
| `flex` | `flex` | 生成词法分析器 |
| `gawk` | `gawk` | 文本字段与记录处理 |
| `gettext` | `gettext` | 国际化消息与翻译工具 |
| `grep` | `grep` | 搜索文本 |
| `groff` | `groff` | 生成手册等排版文档 |
| `gzip` | `gzip` | 处理 gzip 压缩数据 |
| `libtool` | `libtool` | 管理共享库构建 |
| `m4` | `m4` | Autotools 使用的宏处理器 |
| `pacman` | `dpkg` | 发行版原生软件包管理工具 |
| `sed` | `sed` | 流式文本替换 |
| `sudo` | `sudo` | 以管理员权限执行安装命令 |
| `texinfo` | `texinfo` | 生成 GNU 信息文档 |
| `which` | `debianutils` | 定位 PATH 中的命令 |
| `git` | `git` | 获取及管理源码 |
| `wget` | `wget` | 下载网络文件 |
| `curl` | `curl` | HTTP 等协议下载和请求 |
| `jq` | `jq` | 解析和处理 JSON |
| `github-cli` | `gh` | 使用 gh 发布 GitHub Release 资产 |
| `patchelf` | `patchelf` | 修改 ELF 解释器和 RPATH |
| `coreutils` | `coreutils` | 文件、路径与文本基础命令 |
| `tar` | `tar` | 归档与解包 tar 文件 |
| `bzip2` | `bzip2` | 处理 bzip2 压缩数据 |
| `xz` | `xz-utils` | 处理 xz 压缩数据 |
| `zstd` | `zstd` | 处理 zstd 压缩数据 |
| `lz4` | `lz4` | 处理 lz4 压缩数据 |
| `unzip` | `unzip` | 解开 ZIP 文件 |
| `zip` | `zip` | 创建 ZIP 文件 |
| `7zip` | `p7zip-full` | 处理 7z 等压缩格式 |
| `rsync` | `rsync` | 同步文件并保留属性 |
| `util-linux` | `util-linux` | 挂载、设备和系统辅助工具 |
| `appstream-glib` | `appstream-util` | 检查和处理 AppStream 元数据 |
| `desktop-file-utils` | `desktop-file-utils` | 检查及维护 desktop 启动文件 |
| `shared-mime-info` | `shared-mime-info` | 文件 MIME 类型数据库 |
| `hicolor-icon-theme` | `hicolor-icon-theme` | 通用图标主题目录规范 |
| `xdg-utils` | `xdg-utils` | 打开 URL、文件和查询桌面默认应用 |
| `zsync` | `zsync` | 生成或使用增量更新元数据 |
| `ca-certificates` | `ca-certificates` | 受信任的 CA 证书集合 |
| `ca-certificates-utils` | `ca-certificates` | Arch 证书更新辅助工具；Ubuntu 更新命令由 ca-certificates 提供 |
| `cmake` | `cmake` | 配置和生成 CMake 构建 |
| `ninja` | `ninja-build` | 执行 Ninja 构建 |
| `meson` | `meson` | 配置 Meson 项目 |
| `python` | `python3` | 运行 Python 构建和辅助脚本 |
| `perl` | `perl` | 运行 Perl 构建和辅助脚本 |
| `squashfs-tools` | `squashfs-tools` | 制作或解开 SquashFS |
| `libarchive` | `libarchive-tools` | 读取多种归档格式及 bsdtar 工具 |
| `cpio` | `cpio` | 处理 cpio 归档 |
| `elfutils` | `elfutils` | 检查 ELF 与调试信息 |
| `pax-utils` | `pax-utils` | 检查 ELF 属性和依赖 |
| `chrpath` | `chrpath` | 查看或修改 ELF RPATH |
| `openssl` | `openssl` | TLS、证书和加密命令 |
| `openssh` | `openssh-client` | SSH 连接与 Git 传输工具 |
| `gnupg` | `gnupg` | 验证和管理 OpenPGP 签名 |
| `dbus` | `dbus` | 应用与服务之间的消息总线 |
| `at-spi2-core` | `at-spi2-core` | 桌面无障碍接口服务 |
| `nspr` | `libnspr4` | Mozilla 跨平台线程和网络基础库 |
| `nss` | `libnss3` | Mozilla 证书与加密运行库 |
| `nss-mdns` | `libnss-mdns` | 通过 NSS 解析 mDNS 本地域名 |
| `avahi` | `avahi-daemon` | mDNS 和 DNS-SD 设备发现服务 |
| `xdg-desktop-portal` | `xdg-desktop-portal` | 桌面文件选择与屏幕共享等 portal 接口 |
| `ibus` | `ibus` | 输入法框架及切换服务 |
| `xterm` | `xterm` | X11 终端模拟器 |
| `xclip` | `xclip` | X11 剪贴板命令工具 |
| `xsel` | `xsel` | 另一套 X11 剪贴板命令工具 |
| `xorg-xrdb` | `x11-xserver-utils` | 加载 Xresources 资源数据库 |
| `wqy-microhei` | `fonts-wqy-microhei` | 文泉驿微米黑中文字体 |
| `wqy-zenhei` | `fonts-wqy-zenhei` | 文泉驿正黑中文字体 |
| `noto-fonts-emoji` | `fonts-noto-color-emoji` | 彩色 Emoji 字体 |
| `polkit` | `polkitd` | 桌面权限授权服务 |
| `glib2` | `libglib2.0-0（22.04）或 libglib2.0-0t64（24.04）` | GLib 事件循环与基础数据结构 |
| `pango` | `libpango-1.0-0` | 多语言文本排版 |
| `gdk-pixbuf2` | `libgdk-pixbuf-2.0-0` | 图片加载及像素缓冲处理 |
| `libdrm` | `libdrm2` | 图形栈 DRM 用户态接口 |
| `libxkbcommon` | `libxkbcommon0` | 键盘布局和按键解析 |
| `fontconfig` | `fontconfig` | 查找与匹配系统字体 |
| `xdotool` | `xdotool` | 模拟 X11 键鼠及窗口操作 |
| `openal` | `libopenal1` | 空间音频运行库 |
| `lsb-release` | `lsb-release` | 报告发行版识别信息 |
| `socat` | `socat` | 在 socket、文件和终端间转发数据 |
| `nginx` | `nginx` | Web 服务与反向代理 |
| `boost-libs` | `libboost-all-dev` | Boost C++ 库集合 |
| `inetutils` | `inetutils-tools` | 传统网络与主机信息命令 |

## 按功能追加，不纳入所有应用基础包

| 功能 | Arch 包例 | Ubuntu 包例 | 选择依据 |
| --- | --- | --- | --- |
| X11 / XCB 扩展 | `libx11 libxext libxrender libxrandr libxfixes xcb-util xcb-util-image xcb-util-keysyms xcb-util-renderutil xcb-util-wm` | `libx11-6 libxext6 libxrender1 libxrandr2 libxfixes3 libxcb-image0 libxcb-keysyms1 libxcb-render-util0` | 主程序、Qt platform plugin 或其他插件的实际 ELF 依赖 |
| OpenGL / Mesa | `libglvnd mesa` | `libgl1 libglvnd0` | 程序或渲染后端确实需要；驱动不盲目打进 AppImage |
| 音频 / 视频 | `alsa-lib libpulse pipewire ffmpeg` | `libasound2 libpulse0 ffmpeg`；22.04 用 `libpipewire-0.3-0`，24.04 用 `libpipewire-0.3-0t64` | 上游功能、插件与实际加载路径 |
| 桌面集成 | `libsecret libnotify xdg-utils shared-mime-info hicolor-icon-theme` | `libsecret-1-0 libnotify4 xdg-utils shared-mime-info hicolor-icon-theme` | Secret Service、通知、打开链接、MIME、图标等实际功能 |

这些是**选包目录**，不是让 AI 把整行追加进所有脚本。已安装的软件包不一定被 quick-sharun 或 linuxdeploy 自动带入最终 AppImage；`dlopen` 库、Qt / GTK 输入模块、GIO / GStreamer 插件和资源目录必须以应用实际加载方式及现有产物证据单独核对。不要为补一个缺失库复制整套 `/usr/lib`，也不要把用户主机的包当作 CI 构建依赖。

**PulseAudio 缺库核对：** 仅在应用真实依赖 `libpulse.so.0` 时，由该应用脚本安装构建环境的 Arch `libpulse` 或 Ubuntu `libpulse0`，并检查最终 AppImage 是否实际包含 `libpulse.so.0`、同包的 `libpulsecommon-*.so` 及所需的间接依赖。程序位于 `/opt` 或经 `dlopen` 加载时，工具可能没有自动发现这些库；按该应用的实际 ELF 依赖显式部署，并核对最终成品，不能只在已安装 `libpulse` 的构建机上运行 `ldd` 就认定跨发行版可用。此项不加入统一基础包，也不批量改动其他应用。

## 应用专用缺包处理与当前构建入口

以后基础包统一以本文件和 `common/arch/install_packages.sh`、`common/apt/install_packages.sh` 为准。个别应用缺包、与某包不兼容或仅该应用需要特殊功能时，只在该应用的 `build_*.sh` 增补或处理，并在同目录 README 写明原因；不得因此修改统一基础包。既有脚本若未调用公共安装入口，不能仅凭本文件声称它已安装这套基础包。

当前 `.github/actions/build-anylinux/action.yml` 仍准备 `yay` 并安装 `github-cli jq` 供旧矩阵脚本使用；这一旧步骤不替代应用调用上述统一基础包入口。变更共享发布链前须先核对全部受影响的 Job。
