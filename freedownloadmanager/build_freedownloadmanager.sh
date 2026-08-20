#!/usr/bin/env bash
set -e

rm -rf AppDir dist || true

ARCH="$(uname -m)"
export ARCH

if [ "$ARCH" != "x86_64" ]; then
  echo "Error: this script only supports x86_64."
  exit 1
fi

export APPNAME="Free Download Manager"
export STARTUPWMCLASS="Free Download Manager"
export ICON="/opt/freedownloadmanager/icon.png"
export DESKTOP="/usr/share/applications/freedownloadmanager.desktop"
export OUTPATH=./dist
export OUTNAME="freedownloadmanager.AppImage"

export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export DEPLOY_PIPEWIRE=1
export DEPLOY_QT=1

# 基础打包工具
yay -S --noconfirm \
  gcc base-devel debugedit wget curl tar gzip xz binutils patchelf coreutils \
  appstream-glib desktop-file-utils util-linux zsync \
  xorg-server xorg-server-common xorg-server-xvfb

# FDM AUR 当前可能 sha256 校验失效，临时跳过完整性校验
yay -S --noconfirm --mflags "--skipinteg" freedownloadmanager

# FDM 运行依赖
yay -S --noconfirm \
  ffmpeg gst-plugins-base libtorrent openssl qt6-wayland xdg-utils \
  nss nspr \
  glib2 glibc gcc-libs zlib ca-certificates \
  libx11 libxext libxi libxtst libxss libxrandr libxinerama \
  libxcomposite libxdamage libxfixes libxcb libxkbcommon libxkbcommon-x11 \
  mesa libglvnd libva libvdpau vulkan-icd-loader \
  alsa-lib pulseaudio pulseaudio-alsa pipewire-audio \
  gtk3 ibus shared-mime-info hicolor-icon-theme adwaita-icon-theme \
  fontconfig freetype2 harfbuzz cairo pango gdk-pixbuf2 librsvg \
  qt6-base qt6-declarative qt6-svg qt6-multimedia \
  qt6ct kvantum lxqt-qtplugin

quick-sharun \
  /opt/freedownloadmanager/fdm \
  /opt/freedownloadmanager \
  /usr/bin/xdg-open \
  /usr/lib/libnss* \
  /usr/lib/libsoftokn3.so \
  /usr/lib/libfreeblpriv3.so \
  /usr/lib/pkcs11/*

quick-sharun --make-appimage
