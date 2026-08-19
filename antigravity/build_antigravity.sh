#!/usr/bin/env bash
set -e

rm -rf AppDir || true

ARCH="$(uname -m)"
export ARCH

# Basic dependencies
yay -S --noconfirm gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux zsync
# App dependencies
yay -S --noconfirm patchelf libnss_nis nss-mdns nss alsa-lib at-spi2-core cairo dbus expat glib2 glibc gtk3 libcups gcc-libs libx11 libxcb libxcomposite libxdamage libxext libxfixes libxkbcommon libxrandr mesa nspr pango systemd-libs ibus debugedit gvfs librsvg libvdpau libxkbcommon-x11

farch=x64

echo "Getting binary..."
BASE_URL="https://antigravity.google"
link=$(curl -sSfL --compressed "$BASE_URL/download" | grep -oP "https://storage\.googleapis\.com/antigravity-public/antigravity-hub/[^\"']+/linux-${farch}/Antigravity\.tar\.gz" | head -1)

if [[ -z "$link" ]]; then
  echo "Error: failed to find the Antigravity Linux ${farch} download URL." >&2
  exit 1
fi

curl -sSfL --retry 30 --retry-connrefused "$link" -o /tmp/temp.tar.gz

mkdir -p ./AppDir/bin
curl -sL "https://aur.archlinux.org/cgit/aur.git/plain/antigravity.desktop?h=antigravity" | sed 's|^Exec=/usr/bin/|Exec=|g' > ./AppDir/antigravity.desktop
tar -xvzf /tmp/temp.tar.gz --strip-components=1 -C ./AppDir/bin
rm -f /tmp/temp.tar.gz

curl -sL "https://aur.archlinux.org/cgit/aur.git/plain/antigravity.png?h=antigravity" -o ./antigravity.png

export STARTUPWMCLASS=antigravity
export ICON=./antigravity.png
export DESKTOP=./AppDir/antigravity.desktop
export OUTPATH=./dist
export OUTNAME="antigravity.AppImage"

export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1

quick-sharun ./AppDir/bin/antigravity
quick-sharun --make-appimage
