#!/usr/bin/env bash
set -e

rm -rf AppDir dist || true

ARCH="$(uname -m)"
export ARCH

export STARTUPWMCLASS=moderncsv
export ICON=./AppDir/shared/bin/moderncsv.png
export DESKTOP=./AppDir/shared/bin/moderncsv.desktop
export OUTPATH=./dist
export OUTNAME="moderncsv.AppImage"
export DEPLOY_OPENGL=1

###### 准备构建环境 ######

# 安装 quick-sharun 的 Qt6、GTK、Fcitx5/Rime、TLS、OpenGL、X11/XCB、Wayland、字体、打印及常用图形运行时完整基础依赖。
yay -S --noconfirm gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux glycin \
  libheif zsync strace xorg-server xorg-server-common xorg-server-xvfb openssl ca-certificates ca-certificates-utils nss \
  mesa libglvnd egl-wayland libdrm libx11 libxext libxfixes libxi libxinerama libxcb \
  libxkbcommon libxkbcommon-x11 libxss libxtst libice libsm libinput libxrender libxrandr wayland \
  wayland-protocols xcb-util xcb-util-cursor xcb-util-image xcb-util-keysyms xcb-util-renderutil xcb-util-wm xdg-utils dbus shared-mime-info \
  fontconfig freetype2 harfbuzz libjpeg-turbo libpng libtiff libwebp gtk3 gtk4 gdk-pixbuf2 \
  pango cairo librsvg hicolor-icon-theme adwaita-icon-theme glib2 qt6-base qt6-svg qt6-tools qt6-5compat \
  qt6-wayland qt6-declarative qt6-imageformats qt6-multimedia qt6-translations qt6ct lxqt-qtplugin kvantum qca-qt6 libcups \
  libpulse alsa-lib fcitx5 fcitx5-qt fcitx5-gtk fcitx5-rime

# Modern CSV 当前没有需要在 Qt6 通用基础环境之外额外安装的软件包；后续如有额外依赖，必须使用独立 yay 命令，不得并入上面的基础命令。

mkdir -p ./AppDir/shared/bin ./dist

###### 下载上游文件 ######

# 下载官方 Linux tar 包，去掉最外层目录后完整解压到 AppDir/shared/bin。
wget --retry-connrefused --tries=30 \
  https://www.moderncsv.com/release/ModernCSV-Linux-v2.4.3.tar.gz \
  -O /tmp/ModernCSV-Linux.tar.gz

tar -xzf /tmp/ModernCSV-Linux.tar.gz -C ./AppDir/shared/bin --strip-components=1

###### 核心打包 ######

# 直接使用 AppDir/shared/bin 中官方自带的真实主程序、desktop、icon、lib、plugins 和 qt.conf。
quick-sharun ./AppDir/shared/bin/moderncsv

cat >> AppDir/.env <<'EOF_ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
QT_QPA_PLATFORM=xcb
EOF_ENV

quick-sharun --make-appimage
