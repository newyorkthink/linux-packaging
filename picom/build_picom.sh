#!/usr/bin/env bash
set -e

rm -rf AppDir dist || true

# 安装基础打包工具
yay -S --noconfirm \
  gcc base-devel wget git binutils patchelf coreutils \
  appstream-glib desktop-file-utils util-linux zsync \
  xorg-server xorg-server-common

# 安装 picom 和运行依赖
yay -S --noconfirm \
  picom \
  bash glibc gcc-libs \
  hicolor-icon-theme \
  libconfig dbus libepoxy libev libglvnd pcre2 pixman \
  libx11 libxext libxcb libxrender libxrandr libxinerama libxdamage libxfixes \
  xcb-util-image xcb-util-renderutil \
  xorg-xprop xorg-xwininfo

ARCH="$(uname -m)"
export ARCH

export APPNAME="picom"
export STARTUPWMCLASS="picom"
export ICON="/usr/share/icons/hicolor/scalable/apps/compton.svg"
export DESKTOP="/usr/share/applications/picom.desktop"
export OUTPATH=./dist
export OUTNAME="picom.AppImage"

# 保留 OpenGL/EGL 相关库，picom 可用 xrender/glx 后端
export DEPLOY_OPENGL=1

# 使用 quick-sharun 构建 AppDir
quick-sharun \
  /usr/bin/picom \
  /usr/bin/picom-trans \
  /usr/bin/picom-inspect \
  /usr/bin/compton \
  /usr/bin/compton-trans \
  /usr/bin/xprop \
  /usr/bin/xwininfo \
  /etc/xdg/picom.conf

# 构建 AppImage
quick-sharun --make-appimage
