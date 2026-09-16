#!/usr/bin/env bash
set -e

rm -rf AppDir || true

yay -S --noconfirm gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux glycin libheif zsync xorg-server xorg-server-common xorg-server-xvfb
yay -S --noconfirm keepassxc xclip fcitx5-qt libxcb xcb-util xcb-util-keysyms libxss \
  xcb-util-renderutil xcb-util-wm xcb-util-image xcb-util-cursor libxkbcommon libxkbcommon-x11 mesa libglvnd \
  qt5-base qt5-svg qt5-x11extras libxtst xdotool libvdpau libva lxqt-qtplugin \
  libx11 libxext libxfixes libxi libxinerama libxcb xcb-util adwaita-qt5 \
  libsm libice libxrandr libxrender libxcursor libxcomposite libxdamage

KEEPASSXC_PACKAGE_VERSION="$(pacman -Q keepassxc | awk '{print $2}')"
KEEPASSXC_VERSION="${KEEPASSXC_PACKAGE_VERSION#*:}"
KEEPASSXC_VERSION="${KEEPASSXC_VERSION%-*}"
if [ -z "$KEEPASSXC_VERSION" ]; then
  echo "Error: failed to determine KeePassXC version." >&2
  exit 1
fi

ARCH="$(uname -m)"
export ARCH

export ICON=/usr/share/icons/hicolor/scalable/apps/keepassxc.svg
export DESKTOP=/usr/share/applications/org.keepassxc.KeePassXC.desktop
export OUTPATH=./dist
export OUTNAME="keepassxc.AppImage"

quick-sharun \
  /usr/bin/keepassxc \
  /usr/bin/keepassxc-cli \
  /usr/bin/keepassxc-proxy \
  /usr/bin/xclip \
  /usr/bin/xclip-copyfile \
  /usr/bin/xclip-cutfile \
  /usr/bin/xclip-pastefile \
  /usr/bin/xdotool \
  /usr/lib/libXtst.so.6 \
  /usr/lib/libxcb-xtest.so.0

quick-sharun --make-appimage

# 构建成功后输出统一的软件版本元数据。
printf '%s\n' "$KEEPASSXC_VERSION" > ./dist/version.txt
