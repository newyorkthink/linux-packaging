#!/usr/bin/env bash
set -e

rm -rf AppDir || true

# 基础必备打包工具和依赖
yay -S --noconfirm gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux zsync xorg-server xorg-server-common

# 固定使用 Sunshine 官方 GitHub Release v2025.924.154138 的 Arch Linux 包
SUNSHINE_PINNED_VERSION="2025.924.154138"
SUNSHINE_PACKAGE="sunshine.pkg.tar.zst"
SUNSHINE_PACKAGE_URL="https://github.com/LizardByte/Sunshine/releases/download/v${SUNSHINE_PINNED_VERSION}/${SUNSHINE_PACKAGE}"
SUNSHINE_PACKAGE_SHA256="2d7be01ffde6fb346c86f102edb5158b513db5f194c0481cd5e782cadafd9c3c"
wget --tries=3 --timeout=30 -O "$SUNSHINE_PACKAGE" "$SUNSHINE_PACKAGE_URL"
printf '%s  %s\n' "$SUNSHINE_PACKAGE_SHA256" "$SUNSHINE_PACKAGE" | sha256sum -c -

# 安装 Sunshine 所有必需和可选依赖，加上音视频处理和硬件加速的补充包
yay -S --noconfirm \
  avahi curl libayatana-appindicator libcap libdrm libevdev libmfx \
  intel-media-sdk libnotify pipewire libpulse libva libx11 \
  libxcb libxfixes libxrandr libxtst miniupnpc numactl openssl opus \
  systemd vulkan-icd-loader which \
  libva-mesa-driver xorg-server-xvfb \
  fauxput-bin \
  intel-media-driver libva-intel-driver xdg-desktop-portal xdg-desktop-portal-wlr \
  ibus alsa-lib alsa-plugins alsa-utils libpipewire cuda xcb-util-wm gvfs librsvg

# 安装已固定并完成 SHA-256 校验的 Sunshine 官方包
pacman -U --noconfirm "$SUNSHINE_PACKAGE"

SUNSHINE_PACKAGE_VERSION="$(pacman -Q sunshine | awk '{print $2}')"
SUNSHINE_VERSION="${SUNSHINE_PACKAGE_VERSION#*:}"
SUNSHINE_VERSION="${SUNSHINE_VERSION%-*}"
if [ -z "$SUNSHINE_VERSION" ]; then
  echo "Error: failed to determine Sunshine version." >&2
  exit 1
fi
if [ "$SUNSHINE_VERSION" != "$SUNSHINE_PINNED_VERSION" ]; then
  echo "Error: installed Sunshine version '$SUNSHINE_VERSION' does not match pinned version '$SUNSHINE_PINNED_VERSION'." >&2
  exit 1
fi

ARCH="$(uname -m)"
export ARCH

export ICON=/usr/share/icons/hicolor/scalable/apps/dev.lizardbyte.app.Sunshine.svg
export DESKTOP=/usr/share/applications/dev.lizardbyte.app.Sunshine.desktop
export OUTPATH=./dist
export OUTNAME="sunshine.AppImage"

export MAIN_BIN=sunshine
quick-sharun \
  /usr/bin/sunshine

# 根据需要可以在这里处理额外的 hooks 或复制必要的动态库等
# 例如修复可能导致冲突的库，或设置某些环境变量

quick-sharun --make-appimage

# 构建成功后输出统一的软件版本元数据。
printf '%s\n' "$SUNSHINE_VERSION" > ./dist/version.txt
