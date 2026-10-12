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

if [ ! -f /usr/share/deskflow/translations/deskflow_zh_CN.qm ]; then
  echo "错误：Arch deskflow 包缺少简体中文翻译。" >&2
  exit 1
fi

# Deskflow 依次查找 applicationDirPath()/translations 和 ../share/deskflow/translations。
# 只收集 ELF 时这些 qm 不会进包，语言列表是空的，界面只能停在英文。
quick-sharun \
  /usr/bin/deskflow \
  /usr/bin/deskflow-core \
  /usr/bin/xdotool \
  /usr/share/deskflow

if [ -d AppDir/share/deskflow/translations ]; then
  mkdir -p AppDir/bin
  ln -sfn ../share/deskflow/translations AppDir/bin/translations
  if [ -d AppDir/shared/bin ]; then
    ln -sfn ../../share/deskflow/translations AppDir/shared/bin/translations
  fi
else
  echo "错误：quick-sharun 未把 Deskflow 翻译目录收集进 AppDir。" >&2
  exit 1
fi

if [ ! -f AppDir/share/deskflow/translations/deskflow_zh_CN.qm ]; then
  echo "错误：AppImage 内缺少 deskflow_zh_CN.qm。" >&2
  exit 1
fi

quick-sharun --make-appimage

printf '%s\n' "$DESKFLOW_VERSION" > ./dist/version.txt
