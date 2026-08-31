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

rm -rf "$SOURCE_DIR" "$APPDIR" "$DIST_DIR"
mkdir -p "$SOURCE_DIR" "$DIST_DIR"

curl -fL --retry 3 \
  https://download.xnview.com/versions/XnView_MP/XnView_MP-CHECKSUMS.txt \
  -o "$CHECKSUMS"

read -r EXPECTED_SHA DEB_NAME < <(
  awk '{gsub(/\r/, "", $2)} $2 ~ /^XnView_MP-[0-9.]+-linux-x64\.deb$/ {print $1, $2; exit}' "$CHECKSUMS"
)
test -n "${EXPECTED_SHA:-}"
test -n "${DEB_NAME:-}"

curl -fL --retry 3 \
  "https://download.xnview.com/versions/XnView_MP/$DEB_NAME" \
  -o "$DEB"
echo "$EXPECTED_SHA  $DEB" | sha256sum -c -

dpkg-deb -x "$DEB" "$APPDIR"
test -x "$APPDIR/opt/XnView/XnView"

cat > "$APPDIR/usr/bin/xnview" <<'EOF_APPRUN'
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "$0")")"
ROOT="$(readlink -f "$HERE/../..")"
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LD_LIBRARY_PATH="$ROOT/opt/XnView/lib:$ROOT/opt/XnView/Plugins:${LD_LIBRARY_PATH:-}"
export QT_PLUGIN_PATH="$ROOT/opt/XnView/lib"
export QT_QPA_PLATFORM=xcb
exec "$ROOT/opt/XnView/XnView" "$@"
EOF_APPRUN
chmod +x "$APPDIR/usr/bin/xnview"

# linuxdeploy-plugin-qt detects Qt modules from AppDir/usr/lib.
# Keep XnView's own Qt first at runtime; this copy is only the deployment seed.
mkdir -p "$APPDIR/usr/lib"
cp -a "$APPDIR/opt/XnView/lib"/libQt5*.so* "$APPDIR/usr/lib/"

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
export LD_LIBRARY_PATH="$APPDIR/opt/XnView/lib:$APPDIR/opt/XnView/Plugins:${LD_LIBRARY_PATH:-}"

"$LINUXDEPLOY" --appdir "$APPDIR" --plugin qt --output appimage

test -s "$OUTFILE"
chmod +x "$OUTFILE"
sha256sum "$OUTFILE"
