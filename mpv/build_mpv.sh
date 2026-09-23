#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 安装统一的 Arch AppImage 基础包
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base



rm -rf AppDir || true

ARCH="$(uname -m)"
export ARCH

export ICON=/usr/share/icons/hicolor/scalable/apps/mpv.svg
export DESKTOP=/usr/share/applications/mpv.desktop
export OUTPATH=./dist
export OUTNAME="mpv.AppImage"

yay -S --noconfirm gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux glycin libheif zsync xorg-server xorg-server-common xorg-server-xvfb
yay -S --noconfirm mpv mpv-mpris

MPV_PACKAGE_VERSION="$(pacman -Q mpv | awk '{print $2}')"
MPV_VERSION="${MPV_PACKAGE_VERSION#*:}"
MPV_VERSION="${MPV_VERSION%-*}"
if [ -z "$MPV_VERSION" ]; then
  echo "Error: failed to determine mpv version." >&2
  exit 1
fi

quick-sharun /usr/bin/mpv

# Download standalone yt-dlp directly to AppDir to avoid patchelf corruption
mkdir -p AppDir/usr/bin
wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux -O AppDir/usr/bin/yt-dlp
chmod +x AppDir/usr/bin/yt-dlp

# Fix 'Non-C locale detected' for mpv
# Clear LC_ALL so it doesn't override LC_NUMERIC, keeping Chinese UI (LANG) intact
echo "LC_ALL=" >> AppDir/.env
echo "LC_NUMERIC=C" >> AppDir/.env

# Add hook to launch GUI when no arguments are provided (e.g. double clicking the AppImage)
mkdir -p AppDir/bin
cat << 'EOF' > AppDir/bin/mpv-launch-gui.src.hook
#!/bin/false

if [ -z "$1" ]; then
	set -- "--player-operation-mode=pseudo-gui"
fi
EOF

quick-sharun --make-appimage

# 构建成功后输出统一的软件版本元数据。
printf '%s\n' "$MPV_VERSION" > ./dist/version.txt
