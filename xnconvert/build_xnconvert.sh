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

# Ubuntu runner: install the complete runtime families used by Qt/XCB/GStreamer/Fcitx5.
sudo apt-get install -y --no-install-recommends \
  qttranslations5-l10n qt5-gtk-platformtheme qtwayland5 \
  fcitx5-frontend-qt5 libfcitx5-qt1 \
  libqt5multimedia5 libqt5multimedia5-plugins libqt5multimediagsttools5 \
  libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
  libpulse0 libpulse-mainloop-glb0 \
  libxkbcommon-x11-0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
  libxcb-render-util0 libxcb-xinerama0 libxcb-xkb1

curl -fL --retry 3 \
  https://download.xnview.com/versions/XnConvert/XnConvert-CHECKSUMS.txt \
  -o "$CHECKSUMS"

read -r EXPECTED_SHA DEB_NAME < <(
  awk '{gsub(/\r/, "", $2)} $2 ~ /^XnConvert-[0-9.]+-linux-x64\.deb$/ {print $1, $2; exit}' "$CHECKSUMS"
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

# The official desktop uses an absolute /opt icon path; linuxdeploy expects an icon name.
sed -i 's|^Icon=.*|Icon=xnconvert|' "$DESKTOP_FILE"

cat > "$APPDIR/usr/bin/xnconvert" <<'EOF_APPRUN'
#!/usr/bin/env bash
set -Eeuo pipefail

HERE="$(dirname "$(readlink -f "$0")")"
ROOT="$(readlink -f "$HERE/../..")"

export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export PATH="$ROOT/opt/XnConvert:$ROOT/usr/bin:${PATH:-}"
export LD_LIBRARY_PATH="$ROOT/opt/XnConvert/lib:$ROOT/usr/lib:${LD_LIBRARY_PATH:-}"
export QT_PLUGIN_PATH="$ROOT/opt/XnConvert/lib:$ROOT/usr/plugins:${QT_PLUGIN_PATH:-}"
export QML_IMPORT_PATH="$ROOT/opt/XnConvert/qml:$ROOT/usr/qml:${QML_IMPORT_PATH:-}"
export QML2_IMPORT_PATH="$ROOT/opt/XnConvert/qml:$ROOT/usr/qml:${QML2_IMPORT_PATH:-}"
export XDG_DATA_DIRS="$ROOT/usr/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export QT_AUTO_SCREEN_SCALE_FACTOR=1
export QT_QPA_PLATFORM=xcb
export QT_FONT_DPI=96

exec "$ROOT/opt/XnConvert/XnConvert" "$@"
EOF_APPRUN
chmod +x "$APPDIR/usr/bin/xnconvert"

# Seed the runtime libraries that are commonly absent on lean distributions. They are
# deliberately kept in usr/lib and the launcher above exposes that directory at runtime.
mkdir -p "$APPDIR/usr/lib" "$APPDIR/usr/translations"
cp -a "$APPDIR/opt/XnConvert/lib"/libQt5XcbQpa.so* "$APPDIR/usr/lib/"

copy_runtime_glob() {
  local pattern="$1"
  local files=()
  mapfile -t files < <(compgen -G "$pattern" || true)
  if ((${#files[@]} == 0)); then
    echo "ERROR: required runtime library pattern not found: $pattern" >&2
    exit 1
  fi
  cp -a "${files[@]}" "$APPDIR/usr/lib/"
}

for runtime_lib in \
  libgstreamer-1.0.so.0 \
  libgstapp-1.0.so.0 \
  libgstbase-1.0.so.0 \
  libgstaudio-1.0.so.0 \
  libgstvideo-1.0.so.0 \
  libgstpbutils-1.0.so.0 \
  libgsttag-1.0.so.0 \
  libgstallocators-1.0.so.0 \
  libgstfft-1.0.so.0 \
  libgstgl-1.0.so.0 \
  libpulse.so.0 \
  libpulse-mainloop-glib.so.0; do
  copy_runtime_glob "/usr/lib/x86_64-linux-gnu/${runtime_lib}*"
done
copy_runtime_glob "/usr/lib/x86_64-linux-gnu/pulseaudio/libpulsecommon-*.so"

test -e "$APPDIR/usr/lib/libQt5XcbQpa.so.5"
test -e "$APPDIR/usr/lib/libgstreamer-1.0.so.0"
test -e "$APPDIR/usr/lib/libgstapp-1.0.so.0"
test -e "$APPDIR/usr/lib/libpulse.so.0"

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
export LD_LIBRARY_PATH="$APPDIR/opt/XnConvert/lib:$APPDIR/usr/lib:${LD_LIBRARY_PATH:-}"

"$LINUXDEPLOY" \
  --appdir "$APPDIR" \
  --desktop-file "$DESKTOP_FILE" \
  --icon-file "$ICON_FILE" \
  --plugin qt \
  --output appimage

test -s "$OUTFILE"
chmod +x "$OUTFILE"

VERIFY_DIR="$SOURCE_DIR/verify-appimage"
rm -rf "$VERIFY_DIR"
mkdir -p "$VERIFY_DIR"
(
  cd "$VERIFY_DIR"
  "$OUTFILE" --appimage-extract >/dev/null
)
VERIFY_ROOT="$VERIFY_DIR/squashfs-root"
test -x "$VERIFY_ROOT/opt/XnConvert/XnConvert"
test -e "$VERIFY_ROOT/usr/lib/libgstreamer-1.0.so.0"
test -e "$VERIFY_ROOT/usr/lib/libgstapp-1.0.so.0"
test -e "$VERIFY_ROOT/usr/lib/libpulse.so.0"
test -e "$VERIFY_ROOT/usr/lib/libpulse-mainloop-glib.so.0"
compgen -G "$VERIFY_ROOT/usr/lib/libpulsecommon-*.so" >/dev/null
test -e "$VERIFY_ROOT/usr/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so"
grep -Fq '$ROOT/usr/lib' "$VERIFY_ROOT/usr/bin/xnconvert"
grep -Fq '$ROOT/usr/plugins' "$VERIFY_ROOT/usr/bin/xnconvert"

LDD_OUTPUT="$(LD_LIBRARY_PATH="$VERIFY_ROOT/opt/XnConvert/lib:$VERIFY_ROOT/usr/lib" ldd "$VERIFY_ROOT/opt/XnConvert/XnConvert")"
printf '%s\n' "$LDD_OUTPUT"
if grep -Fq 'not found' <<<"$LDD_OUTPUT"; then
  echo "ERROR: extracted XnConvert AppImage still has unresolved shared libraries" >&2
  exit 1
fi

sha256sum "$OUTFILE"
