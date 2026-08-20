#!/usr/bin/env bash
set -e



rm -rf AppDir || true

ARCH="$(uname -m)"
export ARCH

export ICON=/usr/share/icons/hicolor/scalable/apps/mpv.svg
export DESKTOP=/usr/share/applications/mpv.desktop
export OUTPATH=./dist
export OUTNAME="mpv.AppImage"

yay -S --noconfirm gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux glycin libheif zsync xorg-server xorg-server-common xorg-server-xvfb
yay -S --noconfirm mpv mpv-mpris

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
