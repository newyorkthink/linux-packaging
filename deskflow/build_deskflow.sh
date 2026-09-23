#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 安装统一的 Arch AppImage 基础包
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base

rm -rf AppDir || true

yay -S --noconfirm gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux glycin libheif zsync xorg-server xorg-server-common xorg-server-xvfb
yay -S --noconfirm glib2 glibc hicolor-icon-theme libei gcc-libs libglvnd libice libportal libsm libx11 libxext libxi libxinerama libxkbcommon libxkbcommon-x11 libxkbfile libxrandr libxtst openssl qt6-base qt6-declarative qt6-svg deskflow xdotool libvdpau libva lxqt-qtplugin qt6ct kvantum

DESKFLOW_PACKAGE_VERSION="$(pacman -Q deskflow | awk '{print $2}')"
DESKFLOW_VERSION="${DESKFLOW_PACKAGE_VERSION#*:}"
DESKFLOW_VERSION="${DESKFLOW_VERSION%-*}"
if [ -z "$DESKFLOW_VERSION" ]; then
  echo "错误：无法解析 Deskflow 版本。" >&2
  exit 1
fi

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

printf '%s\n' "$DESKFLOW_VERSION" > ./dist/version.txt
