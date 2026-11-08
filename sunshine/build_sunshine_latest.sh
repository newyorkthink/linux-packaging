#!/usr/bin/env bash
set -e

# 备用脚本：通过 AUR sunshine-bin 获取当前版本，不接入 GitHub Actions workflow。
# 后续需要恢复跟随最新版本时，可人工核对后用本文件替换 build_sunshine.sh。

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

SUNSHINE_PACKAGE_VERSION="$(pacman -Q sunshine-bin | awk '{print $2}')"
SUNSHINE_VERSION="${SUNSHINE_PACKAGE_VERSION#*:}"
SUNSHINE_VERSION="${SUNSHINE_VERSION%-*}"
if [ -z "$SUNSHINE_VERSION" ]; then
  echo "Error: failed to determine Sunshine version." >&2
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
