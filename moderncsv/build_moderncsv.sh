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

# 安装官方 Modern CSV Qt6 运行时所需的非 Qt 系统依赖，保留现有已成功构建的依赖基线。
yay -S --noconfirm openssl mesa libglvnd libxkbcommon-x11 xcb-util xcb-util-cursor xcb-util-image xcb-util-keysyms xcb-util-renderutil xcb-util-wm xdg-utils patchelf fontconfig

# 单独安装同一套 Arch Qt6 runtime / plugins，避免与官方 tar 中的 Qt5 plugin 混装。
yay -S --noconfirm qt6-base qt6-5compat qt6-svg qt6-imageformats fcitx5-qt

mkdir -p ./AppDir/shared/bin ./dist

###### 下载上游文件 ######

# 下载官方 Linux tar 包。
wget --retry-connrefused --tries=30 \
  https://www.moderncsv.com/release/ModernCSV-Linux-v2.4.3.tar.gz \
  -O /tmp/ModernCSV-Linux.tar.gz

# 只提取应用本体、desktop 和 icon；不带入官方混有 Qt5 plugin 的 lib、plugins 和 qt.conf。
tar -xzf /tmp/ModernCSV-Linux.tar.gz -C ./AppDir/shared/bin --strip-components=1 \
  moderncsv2.4.3/moderncsv \
  moderncsv2.4.3/moderncsv.desktop \
  moderncsv2.4.3/moderncsv.png

###### 核心打包 ######

# 由 quick-sharun 从同一套 Arch Qt6 环境收集 Qt6 runtime、TLS、输入上下文及图形插件。
quick-sharun ./AppDir/shared/bin/moderncsv

quick-sharun --make-appimage
