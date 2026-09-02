#!/usr/bin/env bash
set -e

rm -rf AppDir dist || true

ARCH="$(uname -m)"
export ARCH

export STARTUPWMCLASS=moderncsv
export ICON=./AppDir/bin/moderncsv.png
export DESKTOP=./AppDir/bin/moderncsv.desktop
export OUTPATH=./dist
export OUTNAME="moderncsv.AppImage"
export DEPLOY_OPENGL=1

# quick-sharun 通用基础依赖，其他 AppImage 的 quick-sharun 打包脚本可直接复用。
yay -S --noconfirm base-devel wget patchelf coreutils appstream-glib desktop-file-utils util-linux zsync strace xorg-server xorg-server-common xorg-server-xvfb

# 安装官方 Modern CSV Qt6 运行时所需的非 Qt 系统依赖，避免混入 Arch 当前 Qt6 运行库。
yay -S --noconfirm openssl mesa libglvnd libxkbcommon-x11 xcb-util xcb-util-cursor xcb-util-image xcb-util-keysyms xcb-util-renderutil xcb-util-wm xdg-utils

mkdir -p ./AppDir/bin ./dist

# 下载官方 Linux tar 包，去掉最外层目录后完整解压到 AppDir/bin。
wget --retry-connrefused --tries=30 \
  https://www.moderncsv.com/release/ModernCSV-Linux-v2.4.3.tar.gz \
  -O /tmp/ModernCSV-Linux.tar.gz

tar -xzf /tmp/ModernCSV-Linux.tar.gz -C ./AppDir/bin --strip-components=1

# 直接使用 AppDir/bin 中官方自带的真实主程序、desktop、icon、lib、plugins 和 qt.conf。
quick-sharun ./AppDir/bin/moderncsv

cat >> AppDir/.env <<'EOF_ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
QT_QPA_PLATFORM=xcb
EOF_ENV

quick-sharun --make-appimage
