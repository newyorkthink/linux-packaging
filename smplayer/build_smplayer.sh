#!/usr/bin/env bash

# 任一构建命令失败时立即停止，避免继续发布不完整的 AppImage。
set -e

rm -rf AppDir || true

yay -S --noconfirm gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux glycin libheif zsync xorg-server xorg-server-common xorg-server-xvfb
yay -S --noconfirm xclip fcitx5-qt libxcb xcb-util xcb-util-keysyms libxss extra-cmake-modules xcb-util-renderutil xcb-util-wm xcb-util-image \
  xcb-util-cursor libxkbcommon libxkbcommon-x11 mesa libglvnd \
  make pkgconf base-devel giflib libpng libx11 libxft libxrender \
  libxcomposite libxdamage libxfixes libxext libxinerama freetype2 libjpeg-turbo
yay -S --noconfirm mpv mpv-mpris smplayer smplayer-skins smplayer-themes mplayer qt5-base openssl lxqt-qtplugin kvantum zlib qt5-declarative libstdc++ \
  libgcc hicolor-icon-theme glibc libdecor librsvg libjxl qt5-svg adwaita-qt5 pipewire pipewire-alsa

export STARTUPWMCLASS=smplayer
export ICON=/usr/share/icons/hicolor/scalable/apps/smplayer.svg
export DESKTOP=/usr/share/applications/smplayer.desktop
export OUTPATH=./dist
export OUTNAME="smplayer.AppImage"

# 下载官方 Python 版 yt-dlp，并将系统 Python 一并封装，避免 PyInstaller 单文件在只读 AppImage 挂载点修改 ELF 解释器失败。
wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O /usr/bin/yt-dlp
chmod +x /usr/bin/yt-dlp
export DEPLOY_PYTHON=1

# SMPlayer needs its binary, web server, and yt-dlp for online videos
quick-sharun /usr/bin/smplayer /usr/bin/simple_web_server /usr/bin/mplayer /usr/bin/mpv /usr/bin/yt-dlp


# Set LC_ALL and LC_NUMERIC safely, like mpv
echo "LC_ALL=" >> AppDir/.env
echo "LC_NUMERIC=C" >> AppDir/.env

# 当前 Arch 稳定版 SMPlayer 使用 Qt5；强制使用已封装的 adwaita-qt5 深色样式。
echo "QT_STYLE_OVERRIDE=Adwaita-Dark" >> AppDir/.env

quick-sharun --make-appimage
