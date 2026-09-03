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

# 安装官方 Modern CSV Qt6 运行时所需的非 Qt 系统依赖，避免混入 Arch 当前 Qt6 运行库。
yay -S --noconfirm openssl mesa libglvnd libxkbcommon-x11 xcb-util xcb-util-cursor xcb-util-image xcb-util-keysyms xcb-util-renderutil xcb-util-wm xdg-utils patchelf

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

quick-sharun --make-appimage
