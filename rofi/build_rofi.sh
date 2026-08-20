#!/usr/bin/env bash
set -e

rm -rf AppDir || true

# 安装基础打包工具和依赖
yay -S --noconfirm gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux zsync xorg-server xorg-server-common

# 安装 rofi 及其 emoji 插件，以及其它运行时所需的依赖
yay -S --noconfirm rofi rofi-emoji \
  bash cairo gdk-pixbuf2 glib2 glibc hicolor-icon-theme \
  libxcb libxkbcommon libxkbcommon-x11 pango startup-notification \
  wayland xcb-imdkit xcb-util xcb-util-cursor xcb-util-keysyms xcb-util-wm \
  libva libvdpau

ARCH="$(uname -m)"
export ARCH

export STARTUPWMCLASS=rofi
export ICON=/usr/share/icons/hicolor/scalable/apps/rofi.svg
export DESKTOP=/usr/share/applications/rofi.desktop
export OUTPATH=./dist
export OUTNAME="rofi.AppImage"
export DEPLOY_OPENGL=1

# 使用 quick-sharun 构建 AppDir，并包含指定的二进制文件
quick-sharun \
  /usr/bin/rofi \
  /usr/bin/rofi-sensible-terminal \
  /usr/bin/rofi-theme-selector



# 构建 AppImage
quick-sharun --make-appimage
