#!/usr/bin/env bash
set -e

rm -rf AppDir || true

# 基础必备打包工具和依赖
yay -S --noconfirm gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux zsync xorg-server xorg-server-common

# 安装 sunshine-bin 及其所有必需和可选依赖，加上音视频处理和硬件加速的补充包
yay -S --noconfirm sunshine-bin \
  avahi curl libayatana-appindicator libcap libdrm libevdev libmfx \
  intel-media-sdk libnotify pipewire libpulse libva libx11 \
  libxcb libxfixes libxrandr libxtst miniupnpc numactl openssl opus \
  systemd vulkan-icd-loader which \
  libva-mesa-driver xorg-server-xvfb \
  fauxput-bin \
  intel-media-driver libva-intel-driver xdg-desktop-portal xdg-desktop-portal-wlr \
  ibus alsa-lib alsa-plugins alsa-utils libpipewire cuda xcb-util-wm gvfs librsvg

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
