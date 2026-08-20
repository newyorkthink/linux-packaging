#!/usr/bin/env bash
set -e

rm -rf AppDir || true

yay -S --noconfirm gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux glycin libheif zsync xorg-server xorg-server-common xorg-server-xvfb
yay -S --noconfirm glib2 glibc hicolor-icon-theme libei gcc-libs libglvnd libice libportal libsm libx11 libxext libxi libxinerama libxkbcommon libxkbcommon-x11 libxkbfile libxrandr libxtst openssl qt6-base qt6-declarative qt6-svg deskflow xdotool libvdpau libva lxqt-qtplugin qt6ct kvantum

ARCH="$(uname -m)"
export ARCH

export ICON=/usr/share/icons/hicolor/symbolic/apps/org.deskflow.deskflow-symbolic.svg
export DESKTOP=/usr/share/applications/org.deskflow.deskflow.desktop
export STARTUPWMCLASS=deskflow
export OUTPATH=./dist
export OUTNAME="deskflow.AppImage"

quick-sharun \
  /usr/bin/deskflow \
  /usr/bin/deskflow-core \
  /usr/bin/xdotool

quick-sharun --make-appimage
