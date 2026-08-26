#!/usr/bin/env bash
set -e

rm -rf AppDir || true

ARCH="$(uname -m)"
export ARCH

# Basic dependencies
yay -S --noconfirm gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux zsync
# App dependencies
yay -S --noconfirm patchelf libnss_nis nss-mdns nss bubblewrap alsa-lib at-spi2-core cairo dbus expat glib2 glibc gtk3 libcups gcc-libs libx11 libxcb libxcomposite libxdamage libxext libxfixes libxkbcommon libxrandr mesa nspr pango systemd-libs ibus debugedit gvfs librsvg libvdpau xcb-util-wm libxkbcommon-x11

farch=x64

echo "Getting binary..."
BASE_URL="https://antigravity.google"
link=$(curl -sSfL --compressed "$BASE_URL/download" | grep -oP "https://edgedl\.me\.gvt1\.com[^\"']+linux-${farch}/Antigravity%20IDE\.tar\.gz" | head -1)

if [[ -z "$link" ]]; then
  echo "Error: failed to find the Antigravity IDE Linux ${farch} download URL." >&2
  exit 1
fi

if ! curl -sSfL --retry 30 --retry-connrefused "$link" -o /tmp/temp.tar.gz 2>/tmp/download.log; then
	cat /tmp/download.log
	exit 1
fi

mkdir -p ./AppDir/bin ./AppDir/share/applications
tar -xvzf /tmp/temp.tar.gz --strip-components=1 -C ./AppDir/bin
rm -f /tmp/temp.tar.gz
curl -sL "https://aur.archlinux.org/cgit/aur.git/plain/antigravity-ide.desktop?h=antigravity-ide" | sed 's|^Exec=/usr/bin/|Exec=|g' > ./AppDir/antigravity-ide.desktop
curl -sL "https://aur.archlinux.org/cgit/aur.git/plain/antigravity-ide-url-handler.desktop?h=antigravity-ide" | sed 's|^Exec=/usr/bin/|Exec=|g' > ./AppDir/share/applications/antigravity-ide-url-handler.desktop

export STARTUPWMCLASS=antigravity-ide
export ICON=./AppDir/bin/resources/app/resources/linux/code.png
export DESKTOP=./AppDir/antigravity-ide.desktop
export OUTPATH=./dist
export OUTNAME="antigravity-ide.AppImage"

export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export DWARFS_COMP="zstd:level=5"

quick-sharun ./AppDir/bin/* /usr/lib/libnss_nis.so* /usr/lib/libnsl.so* /usr/lib/libnss_mdns*_minimal.so* /usr/bin/bwrap
patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2 ./AppDir/shared/bin/language_server
quick-sharun --make-appimage
