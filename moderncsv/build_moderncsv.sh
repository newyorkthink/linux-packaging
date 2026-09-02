#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$0")"

WORK_DIR="$PWD/.work"
APPDIR="$PWD/AppDir"
DIST_DIR="$PWD/dist"

rm -rf "$WORK_DIR" "$APPDIR" "$DIST_DIR"
mkdir -p "$WORK_DIR" "$DIST_DIR"

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  build-essential binutils ca-certificates curl dbus-x11 desktop-file-utils patchelf wget xauth xvfb zsync \
  qt6-base-dev libqt6network6t64 fcitx5-frontend-qt6 libssl3t64

RELEASE_INDEX="$WORK_DIR/release-index.html"
curl -fsSL https://www.moderncsv.com/release/ -o "$RELEASE_INDEX"

ASSET="$(grep -oE 'ModernCSV-Linux-v[0-9]+([.][0-9]+)+[.]tar[.]gz' "$RELEASE_INDEX" | sort -uV | tail -n 1)"
[[ -n "$ASSET" ]]

VERSION="${ASSET#ModernCSV-Linux-v}"
VERSION="${VERSION%.tar.gz}"
ARCHIVE="$WORK_DIR/$ASSET"

curl -fL --retry 3 "https://www.moderncsv.com/release/$ASSET" -o "$ARCHIVE"
mkdir -p "$WORK_DIR/source"
tar -xzf "$ARCHIVE" -C "$WORK_DIR/source"

SOURCE_DIR="$(find "$WORK_DIR/source" -mindepth 1 -maxdepth 1 -type d -name 'moderncsv*' -print -quit)"
test -x "$SOURCE_DIR/moderncsv"
test -f "$SOURCE_DIR/moderncsv.desktop"
test -f "$SOURCE_DIR/moderncsv.png"
find "$SOURCE_DIR/lib" -name 'libQt6Core.so*' -print -quit | grep -q .

DESKTOP="$WORK_DIR/moderncsv.desktop"
cp -a "$SOURCE_DIR/moderncsv.desktop" "$DESKTOP"
sed -i \
  -e 's/^Version=.*/Version=1.0/' \
  -e 's|^Exec=.*|Exec=moderncsv|' \
  -e 's|^Icon=.*|Icon=moderncsv|' \
  "$DESKTOP"
desktop-file-validate "$DESKTOP"

QUICK_SHARUN="$WORK_DIR/quick-sharun"
curl -fsSL https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/quick-sharun.sh -o "$QUICK_SHARUN"
chmod +x "$QUICK_SHARUN"

export APPDIR
export DESKTOP
export ICON="$SOURCE_DIR/moderncsv.png"
export OUTPATH="$DIST_DIR"
export OUTNAME="moderncsv.AppImage"

LD_LIBRARY_PATH="$SOURCE_DIR/lib" \
QT_QPA_PLATFORM=xcb \
  "$QUICK_SHARUN" "$SOURCE_DIR/moderncsv"

cat >> "$APPDIR/.env" <<'EOF_ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
QT_QPA_PLATFORM=xcb
EOF_ENV

"$QUICK_SHARUN" --make-appimage

test -s "$DIST_DIR/moderncsv.AppImage"
printf '%s\n' "$VERSION" > "$DIST_DIR/version.txt"
SOURCE_SHA256="$(sha256sum "$ARCHIVE" | awk '{print $1}')"
printf '%s  %s\n' "$SOURCE_SHA256" "$ASSET" > "$DIST_DIR/source.sha256"
