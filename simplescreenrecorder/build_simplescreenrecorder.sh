#!/usr/bin/env bash
set -e

rm -rf AppDir || true

ARCH="$(uname -m)"
export ARCH

export STARTUPWMCLASS=simplescreenrecorder
export ICON=/usr/share/icons/hicolor/256x256/apps/simplescreenrecorder.png
export DESKTOP=/usr/share/applications/be.maartenbaert.simplescreenrecorder.desktop
export OUTPATH=./dist
export OUTNAME="simplescreenrecorder.AppImage"
export DEPLOY_OPENGL=1

# 安装基础依赖 (构建环境和 AppImage 相关)
yay -S --noconfirm gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux glycin libheif zsync xorg-server xorg-server-common xorg-server-xvfb

# 安装 simplescreenrecorder 及其音视频、图形界面相关依赖
yay -S --noconfirm simplescreenrecorder qt5-base qt5-x11extras ffmpeg alsa-lib jack2 libpulse libx11 libxext libxfixes libxi libxinerama glu gtk-update-icon-cache libglvnd mesa fcitx5-qt egl-wayland libxcb xcb-util xcb-util-keysyms libxss extra-cmake-modules xcb-util-renderutil xcb-util-wm xcb-util-image xcb-util-cursor libxkbcommon libxkbcommon-x11 adwaita-qt5 qt5-svg qt5-tools qt5ct lxqt-qtplugin kvantum wl-clipboard xclip

# 使用 quick-sharun 构建 AppDir 并打包成 AppImage
quick-sharun /usr/bin/simplescreenrecorder
quick-sharun --make-appimage
