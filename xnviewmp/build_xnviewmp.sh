#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SOURCE_DIR="$SCRIPT_DIR/source"
APPDIR="$SCRIPT_DIR/AppDir"
DIST_DIR="$SCRIPT_DIR/dist"
OUTFILE="$DIST_DIR/xnviewmp.AppImage"
CHECKSUMS="$SOURCE_DIR/XnView_MP-CHECKSUMS.txt"
DEB="$SOURCE_DIR/XnView_MP.deb"
LINUXDEPLOY="$SOURCE_DIR/linuxdeploy-x86_64.AppImage"
QT_PLUGIN="$SOURCE_DIR/linuxdeploy-plugin-qt-x86_64.AppImage"
DESKTOP_FILE="$APPDIR/usr/share/applications/XnView.desktop"
ICON_FILE="$APPDIR/opt/XnView/xnview.png"

rm -rf "$SOURCE_DIR" "$APPDIR" "$DIST_DIR"
mkdir -p "$SOURCE_DIR" "$DIST_DIR"

# Ubuntu runner: install the complete runtime families XnView commonly reaches through
# Qt Multimedia, GStreamer, PulseAudio, XCB and Qt input methods.
sudo apt-get install -y --no-install-recommends \
  ffmpeg xvfb xauth \
  qttranslations5-l10n qt5-gtk-platformtheme qtwayland5 \
  fcitx5-frontend-qt5 libfcitx5-qt1 \
  libqt5multimedia5 libqt5multimedia5-plugins libqt5multimediagsttools5 \
  libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
  libpulse0 libpulse-mainloop-glib0 \
  libxkbcommon-x11-0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
  libxcb-render-util0 libxcb-xinerama0 libxcb-xkb1

curl -fL --retry 3 \
  https://download.xnview.com/versions/XnView_MP/XnView_MP-CHECKSUMS.txt \
  -o "$CHECKSUMS"

# Do not pick the first entry from the archive checksum file: it may already contain
# an unreleased build. 1.11.5 is the current public stable release; keep the archive
# checksum verification so this cannot silently fetch a different binary.
STABLE_VERSION="1.11.5"
DEB_NAME="XnView_MP-${STABLE_VERSION}-linux-x64.deb"
EXPECTED_SHA="$(awk -v name="$DEB_NAME" '{gsub(/\r/, "", $2)} $2 == name {print $1; exit}' "$CHECKSUMS")"
test -n "$EXPECTED_SHA"

curl -fL --retry 3 \
  "https://download.xnview.com/versions/XnView_MP/$DEB_NAME" \
  -o "$DEB"
echo "$EXPECTED_SHA  $DEB" | sha256sum -c -

PACKAGE_VERSION="$(dpkg-deb -f "$DEB" Version | tr -d '\r\n')"
if [[ "$PACKAGE_VERSION" != "$STABLE_VERSION" ]]; then
  echo "ERROR: downloaded XnView MP package version mismatch" >&2
  echo "expected: $STABLE_VERSION" >&2
  echo "package:  $PACKAGE_VERSION" >&2
  exit 1
fi

dpkg-deb -x "$DEB" "$APPDIR"
for required_path in \
  "$APPDIR/opt/XnView/XnView" \
  "$DESKTOP_FILE" \
  "$ICON_FILE"; do
  if [[ ! -e "$required_path" ]]; then
    echo "ERROR: required XnView package path missing: $required_path" >&2
    find "$APPDIR" -maxdepth 4 \( -type f -o -type l \) -print >&2
    exit 1
  fi
done
test -x "$APPDIR/opt/XnView/XnView"
printf '[XnView MP] stable version: %s\n' "$STABLE_VERSION"

# The official desktop uses an absolute /opt icon path; linuxdeploy expects an icon name.
sed -i 's|^Icon=.*|Icon=xnview|' "$DESKTOP_FILE"

cat > "$APPDIR/usr/bin/xnview" <<'EOF_APPRUN'
#!/usr/bin/env bash
set -Eeuo pipefail

HERE="$(dirname "$(readlink -f "$0")")"
ROOT="$(readlink -f "$HERE/../..")"

export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export PATH="$ROOT/opt/XnView:$ROOT/usr/bin:${PATH:-}"
export LD_LIBRARY_PATH="$ROOT/opt/XnView/lib:$ROOT/opt/XnView/Plugins:$ROOT/usr/lib:${LD_LIBRARY_PATH:-}"
export QT_PLUGIN_PATH="$ROOT/opt/XnView/lib:$ROOT/usr/plugins:${QT_PLUGIN_PATH:-}"
export QML_IMPORT_PATH="$ROOT/opt/XnView/qml:$ROOT/usr/qml:${QML_IMPORT_PATH:-}"
export QML2_IMPORT_PATH="$ROOT/opt/XnView/qml:$ROOT/usr/qml:${QML2_IMPORT_PATH:-}"
export XDG_DATA_DIRS="$ROOT/usr/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export QT_AUTO_SCREEN_SCALE_FACTOR=1
export QT_QPA_PLATFORM=xcb
export QT_FONT_DPI=96

exec "$ROOT/opt/XnView/XnView" "$@"
EOF_APPRUN
chmod +x "$APPDIR/usr/bin/xnview"

# Seed the runtime libraries that have repeatedly been missing on lean hosts. Keeping
# them in usr/lib only works if the AppRun launcher above also exposes usr/lib.
mkdir -p "$APPDIR/usr/lib" "$APPDIR/usr/translations"
cp -a "$APPDIR/opt/XnView/lib"/libQt5XcbQpa.so* "$APPDIR/usr/lib/"

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
test -e "$APPDIR/usr/lib/libpulse-mainloop-glib.so.0"
compgen -G "$APPDIR/usr/lib/libpulsecommon-*.so" >/dev/null

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
export LD_LIBRARY_PATH="$APPDIR/opt/XnView/lib:$APPDIR/opt/XnView/Plugins:$APPDIR/usr/lib:${LD_LIBRARY_PATH:-}"

"$LINUXDEPLOY" \
  --appdir "$APPDIR" \
  --desktop-file "$DESKTOP_FILE" \
  --icon-file "$ICON_FILE" \
  --plugin qt \
  --output appimage

test -s "$OUTFILE"
chmod +x "$OUTFILE"

# Verify the final AppImage itself, not just the runner environment. This catches the
# exact class of failure where CI has a host library but the published AppImage does not
# expose its bundled copy through LD_LIBRARY_PATH/QT_PLUGIN_PATH.
VERIFY_DIR="$SOURCE_DIR/verify-appimage"
rm -rf "$VERIFY_DIR"
mkdir -p "$VERIFY_DIR"
(
  cd "$VERIFY_DIR"
  "$OUTFILE" --appimage-extract >/dev/null
)
VERIFY_ROOT="$VERIFY_DIR/squashfs-root"
test -x "$VERIFY_ROOT/opt/XnView/XnView"
test -e "$VERIFY_ROOT/usr/lib/libgstreamer-1.0.so.0"
test -e "$VERIFY_ROOT/usr/lib/libgstapp-1.0.so.0"
test -e "$VERIFY_ROOT/usr/lib/libpulse.so.0"
test -e "$VERIFY_ROOT/usr/lib/libpulse-mainloop-glib.so.0"
compgen -G "$VERIFY_ROOT/usr/lib/libpulsecommon-*.so" >/dev/null
test -e "$VERIFY_ROOT/usr/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so"
grep -Fq '$ROOT/usr/lib' "$VERIFY_ROOT/usr/bin/xnview"
grep -Fq '$ROOT/usr/plugins' "$VERIFY_ROOT/usr/bin/xnview"

LDD_OUTPUT="$(LD_LIBRARY_PATH="$VERIFY_ROOT/opt/XnView/lib:$VERIFY_ROOT/opt/XnView/Plugins:$VERIFY_ROOT/usr/lib" ldd "$VERIFY_ROOT/opt/XnView/XnView")"
printf '%s\n' "$LDD_OUTPUT"
if grep -Fq 'not found' <<<"$LDD_OUTPUT"; then
  echo "ERROR: extracted XnView AppImage still has unresolved shared libraries" >&2
  exit 1
fi

# Exercise the internal video path before publishing. A plain GUI startup smoke test
# does not catch the crash that happens only after XnView opens an MP4.
VIDEO_SMOKE="$SOURCE_DIR/video-smoke.mp4"
VIDEO_LOG="$SOURCE_DIR/video-smoke.log"
VIDEO_HOME="$SOURCE_DIR/video-home"
VIDEO_RUNTIME="$SOURCE_DIR/video-runtime"
mkdir -p "$VIDEO_HOME" "$VIDEO_RUNTIME"
chmod 700 "$VIDEO_RUNTIME"
ffmpeg -hide_banner -loglevel error -y \
  -f lavfi -i 'testsrc=size=320x180:rate=25' -t 2 \
  -c:v mpeg4 -q:v 5 "$VIDEO_SMOKE"

set +e
timeout 15s xvfb-run -a env \
  HOME="$VIDEO_HOME" XDG_RUNTIME_DIR="$VIDEO_RUNTIME" \
  "$OUTFILE" "$VIDEO_SMOKE" >"$VIDEO_LOG" 2>&1
VIDEO_STATUS=$?
set -e
cat "$VIDEO_LOG"
if [[ "$VIDEO_STATUS" -ne 124 ]]; then
  echo "ERROR: XnView MP video smoke test exited unexpectedly: $VIDEO_STATUS" >&2
  exit 1
fi
if grep -Eqi 'segmentation fault|Crash report dumped|KCrashReporter' "$VIDEO_LOG"; then
  echo "ERROR: XnView MP video smoke test detected a crash" >&2
  exit 1
fi

sha256sum "$OUTFILE"
