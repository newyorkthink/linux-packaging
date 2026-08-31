#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SOURCE_DIR="$SCRIPT_DIR/source"
APPDIR="$SCRIPT_DIR/AppDir"
DIST_DIR="$SCRIPT_DIR/dist"
OUTFILE="$DIST_DIR/xnconvert.AppImage"
CHECKSUMS="$SOURCE_DIR/XnConvert-CHECKSUMS.txt"
OFFICIAL="$SOURCE_DIR/XnConvert.AppImage"
LINUXDEPLOY="$SOURCE_DIR/linuxdeploy-x86_64.AppImage"
QT_PLUGIN="$SOURCE_DIR/linuxdeploy-plugin-qt-x86_64.AppImage"

rm -rf "$SOURCE_DIR" "$APPDIR" "$DIST_DIR"
mkdir -p "$SOURCE_DIR" "$DIST_DIR"

curl -fL --retry 3 \
  https://download.xnview.com/versions/XnConvert/XnConvert-CHECKSUMS.txt \
  -o "$CHECKSUMS"

read -r EXPECTED_SHA APPIMAGE_NAME < <(
  awk '{gsub(/\r/, "", $2)} $2 ~ /^XnConvert-[0-9.]+\.glibc[0-9.]+-x86_64\.AppImage$/ {print $1, $2; exit}' "$CHECKSUMS"
)
test -n "${EXPECTED_SHA:-}"
test -n "${APPIMAGE_NAME:-}"

curl -fL --retry 3 \
  "https://download.xnview.com/versions/XnConvert/$APPIMAGE_NAME" \
  -o "$OFFICIAL"
echo "$EXPECTED_SHA  $OFFICIAL" | sha256sum -c -
chmod +x "$OFFICIAL"

(
  cd "$SOURCE_DIR"
  "$OFFICIAL" --appimage-extract >/dev/null
)
mv "$SOURCE_DIR/squashfs-root" "$APPDIR"

curl -fL --retry 3 \
  https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage \
  -o "$LINUXDEPLOY"
curl -fL --retry 3 \
  https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage \
  -o "$QT_PLUGIN"
chmod +x "$LINUXDEPLOY" "$QT_PLUGIN"

export ARCH=x86_64
export APPIMAGE_EXTRACT_AND_RUN=1
export QMAKE="$(command -v qmake)"
export LDAI_OUTPUT="$OUTFILE"

"$LINUXDEPLOY" --appdir "$APPDIR" --plugin qt --output appimage

test -s "$OUTFILE"
chmod +x "$OUTFILE"
sha256sum "$OUTFILE"
