#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SOURCE_DIR="$SCRIPT_DIR/source"
APPDIR="$SCRIPT_DIR/AppDir"
DIST_DIR="$SCRIPT_DIR/dist"
OUTFILE="$DIST_DIR/xnconvert.AppImage"
CHECKSUMS="$SOURCE_DIR/XnConvert-CHECKSUMS.txt"
DEB="$SOURCE_DIR/XnConvert.deb"
LINUXDEPLOY="$SOURCE_DIR/linuxdeploy-x86_64.AppImage"
QT_PLUGIN="$SOURCE_DIR/linuxdeploy-plugin-qt-x86_64.AppImage"
DESKTOP_FILE="$APPDIR/usr/share/applications/XnConvert.desktop"
ICON_FILE="$APPDIR/opt/XnConvert/xnconvert.png"

rm -rf "$SOURCE_DIR" "$APPDIR" "$DIST_DIR"
mkdir -p "$SOURCE_DIR" "$DIST_DIR"

# Ubuntu runner: install the Qt/XCB/GStreamer/Fcitx5 runtime pieces linuxdeploy may need.
sudo apt-get install -y --no-install-recommends \
  qttranslations5-l10n qt5-gtk-platformtheme qtwayland5 \
  fcitx5-frontend-qt5 libfcitx5-qt1 \
  libqt5multimedia5 libqt5multimedia5-plugins libqt5multimediagsttools5 \
  libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
  libxkbcommon-x11-0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
  libxcb-render-util0 libxcb-xinerama0 libxcb-xkb1

curl -fL --retry 3 \
  https://download.xnview.com/versions/XnConvert/XnConvert-CHECKSUMS.txt \
  -o "$CHECKSUMS"

read -r EXPECTED_SHA DEB_NAME < <(
  awk '{gsub(/\r/, "", $2)} $2 ~ /^XnConvert-[0-9.]+-linux-x64\.deb$/ {print $1, $2; exit}' "$CHECKSUMS"
)
test -n "${EXPECTED_SHA:-}"
test -n "${DEB_NAME:-}"

curl -fL --retry 3 \
  "https://download.xnview.com/versions/XnConvert/$DEB_NAME" \
  -o "$DEB"
echo "$EXPECTED_SHA  $DEB" | sha256sum -c -

dpkg-deb -x "$DEB" "$APPDIR"
test -x "$APPDIR/opt/XnConvert/XnConvert"
test -f "$DESKTOP_FILE"
test -f "$ICON_FILE"
test -f "$APPDIR/opt/XnConvert/lib/platforms/libqxcb.so"

# The official desktop uses an absolute /opt icon path; linuxdeploy expects an icon name.
sed -i 's|^Icon=.*|Icon=xnconvert|' "$DESKTOP_FILE"

# XnConvert ships its own Qt build under /opt/XnConvert. Keep that Qt build and its own
# qxcb plugin together, then use linuxdeploy's usr/lib only as the fallback for XCB/runtime deps.
cat > "$APPDIR/usr/bin/xnconvert" <<'EOF_APPRUN'
#!/usr/bin/env bash
set -Eeuo pipefail

HERE="$(dirname "$(readlink -f "$0")")"
ROOT="$(readlink -f "$HERE/../..")"

export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LD_LIBRARY_PATH="$ROOT/opt/XnConvert/lib:$ROOT/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export QT_PLUGIN_PATH="$ROOT/opt/XnConvert/lib"
export QT_QPA_PLATFORM_PLUGIN_PATH="$ROOT/opt/XnConvert/lib/platforms"
export QT_QPA_PLATFORM=xcb

exec "$ROOT/opt/XnConvert/XnConvert" "$@"
EOF_APPRUN
chmod +x "$APPDIR/usr/bin/xnconvert"

# Give linuxdeploy-plugin-qt one XCB-related Qt seed only. Do not seed every Qt module,
# otherwise unrelated Multimedia/QML modules drag in unnecessary dependency chains.
# Pre-create translations so the Qt plugin can link XnConvert's own language files cleanly.
mkdir -p "$APPDIR/usr/lib" "$APPDIR/usr/translations"
cp -a "$APPDIR/opt/XnConvert/lib"/libQt5XcbQpa.so* "$APPDIR/usr/lib/"
test -e "$APPDIR/usr/lib/libQt5XcbQpa.so.5"

# Make the existing XnConvert icon discoverable by the plain linuxdeploy AppDir scan.
mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"
cp -a "$ICON_FILE" "$APPDIR/usr/share/icons/hicolor/256x256/apps/xnconvert.png"

curl -fL --retry 3 \
  https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage \
  -o "$LINUXDEPLOY"
curl -fL --retry 3 \
  https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage \
  -o "$QT_PLUGIN"
chmod +x "$LINUXDEPLOY" "$QT_PLUGIN"

export ARCH=x86_64
export APPIMAGE_EXTRACT_AND_RUN=1
export LDAI_OUTPUT="$OUTFILE"
export LD_LIBRARY_PATH="$APPDIR/opt/XnConvert/lib:${LD_LIBRARY_PATH:-}"

"$LINUXDEPLOY" --appdir "$APPDIR" --plugin qt --output appimage

test -s "$OUTFILE"
chmod +x "$OUTFILE"

# Check the exact Qt/xcb path used by the final launcher, not the runner's host Qt plugin.
VERIFY_DIR="$SOURCE_DIR/verify-appimage"
rm -rf "$VERIFY_DIR"
mkdir -p "$VERIFY_DIR"
(
  cd "$VERIFY_DIR"
  "$OUTFILE" --appimage-extract >/dev/null
)
VERIFY_ROOT="$VERIFY_DIR/squashfs-root"
test -x "$VERIFY_ROOT/usr/bin/xnconvert"
test -x "$VERIFY_ROOT/opt/XnConvert/XnConvert"
test -e "$VERIFY_ROOT/opt/XnConvert/lib/platforms/libqxcb.so"
test -e "$VERIFY_ROOT/usr/lib/libxcb-icccm.so.4"
test -e "$VERIFY_ROOT/usr/lib/libxcb-image.so.0"
test -e "$VERIFY_ROOT/usr/lib/libxcb-keysyms.so.1"
test -e "$VERIFY_ROOT/usr/lib/libxcb-render-util.so.0"
test -e "$VERIFY_ROOT/usr/lib/libxcb-xkb.so.1"
test -e "$VERIFY_ROOT/usr/lib/libxkbcommon-x11.so.0"

grep -Fqx 'export QT_PLUGIN_PATH="$ROOT/opt/XnConvert/lib"' "$VERIFY_ROOT/usr/bin/xnconvert"
grep -Fqx 'export QT_QPA_PLATFORM_PLUGIN_PATH="$ROOT/opt/XnConvert/lib/platforms"' "$VERIFY_ROOT/usr/bin/xnconvert"
grep -Fqx 'export QT_QPA_PLATFORM=xcb' "$VERIFY_ROOT/usr/bin/xnconvert"

LDD_OUTPUT="$(LD_LIBRARY_PATH="$VERIFY_ROOT/opt/XnConvert/lib:$VERIFY_ROOT/usr/lib" ldd "$VERIFY_ROOT/opt/XnConvert/lib/platforms/libqxcb.so")"
printf '%s\n' "$LDD_OUTPUT"
if grep -Fq 'not found' <<<"$LDD_OUTPUT"; then
  echo "ERROR: bundled official XnConvert qxcb plugin still has unresolved shared libraries" >&2
  exit 1
fi

sha256sum "$OUTFILE"
