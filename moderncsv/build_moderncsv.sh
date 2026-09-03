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

# quick-sharun 通用基础环境：Qt6、GTK3/GTK4、Fcitx5/IBus/Rime、TLS/OpenSSL、X11/XCB、Wayland、OpenGL、字体、图标、SVG/QML/Multimedia、打印和主题插件。
yay -S --noconfirm gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils xorg-server xorg-server-common xorg-server-xvfb openssl ca-certificates nss qt6-base qt6-5compat qt6-svg qt6-tools qt6-wayland qt6-declarative qt6-imageformats qt6-multimedia qt6ct lxqt-qtplugin kvantum qca-qt6 fcitx5 fcitx5-qt fcitx5-rime ibus ibus-rime gtk3 gtk4 gdk-pixbuf2 pango cairo librsvg hicolor-icon-theme adwaita-icon-theme libx11 libxext libxrender libxrandr libxfixes libxi libxinerama libxcb libxkbcommon libxkbcommon-x11 libxss libxtst xcb-util xcb-util-cursor xcb-util-image xcb-util-keysyms xcb-util-renderutil xcb-util-wm wayland wayland-protocols libglvnd mesa fontconfig freetype2 harfbuzz libpng libjpeg-turbo libtiff libwebp libpulse alsa-lib cups glib2 dbus xdg-utils shared-mime-info zsync strace util-linux

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
