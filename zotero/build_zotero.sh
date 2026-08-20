#!/usr/bin/env bash
set -e

rm -rf AppDir Zotero_linux-x86_64 \
  zotero.desktop zotero.ico \
  /tmp/zotero.tar || true

ARCH="$(uname -m)"

if [ "$ARCH" != "x86_64" ]; then
  echo "Error: this script only supports x86_64 / linux-x64."
  exit 1
fi

export ARCH

yay -S --noconfirm gcc base-devel curl wget tar bzip2 binutils patchelf coreutils \
  appstream-glib desktop-file-utils util-linux zsync \
  xorg-server xorg-server-common xorg-server-xvfb

yay -S --noconfirm alsa-lib gtk3 nss \
  gcc-libs glibc lsof inetutils \
  libx11 libxext libxi libxrandr libxrender libxtst libxkbcommon \
  libxcomposite libxdamage libxfixes mesa libglvnd \
  shared-mime-info xdg-utils ibus

export APPNAME=Zotero
export STARTUPWMCLASS=zotero
export ICON=./zotero.ico
export DESKTOP=./zotero.desktop
export OUTPATH=./dist
export OUTNAME="zotero.AppImage"
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1

TARBALL_LINK="https://www.zotero.org/download/client/dl?channel=release&platform=linux-x86_64"

mkdir -p ./AppDir/bin ./dist

wget --retry-connrefused --tries=30 "$TARBALL_LINK" -O /tmp/zotero.tar

tar -xf /tmp/zotero.tar

cp -v ./Zotero_linux-x86_64/zotero.desktop ./zotero.desktop
cp -v ./Zotero_linux-x86_64/icons/icon128.png ./zotero.ico

mv -v ./Zotero_linux-x86_64/* ./AppDir/bin/

chmod +x ./AppDir/bin/zotero-bin

sed -i \
  's#^Exec=.*#Exec=zotero-bin -url %U#' \
  ./zotero.desktop

quick-sharun \
  ./AppDir/bin/zotero-bin \
  /usr/bin/hostname \
  /usr/lib/libnss* \
  /usr/lib/libsoftokn3.so \
  /usr/lib/libfreeblpriv3.so \
  /usr/lib/pkcs11/* \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so

quick-sharun --make-appimage
