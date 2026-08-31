#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SOURCE_DIR="$SCRIPT_DIR/source"
APPDIR="$SCRIPT_DIR/AppDir"
DIST_DIR="$SCRIPT_DIR/dist"
OUTFILE="$DIST_DIR/xnviewmp.AppImage"
CHECKSUMS="$SOURCE_DIR/XnView_MP-CHECKSUMS.txt"
OFFICIAL_APPIMAGE="$SOURCE_DIR/XnView_MP.AppImage"
LINUXDEPLOY="$SOURCE_DIR/linuxdeploy-x86_64.AppImage"
QT_PLUGIN="$SOURCE_DIR/linuxdeploy-plugin-qt-x86_64.AppImage"
APPIMAGETOOL="$SOURCE_DIR/appimagetool-x86_64.AppImage"
RUNTIME_FILE="$SOURCE_DIR/runtime-x86_64"
CUSTOM_APPRUN="$SOURCE_DIR/AppRun"
FAKE_QMAKE="$SOURCE_DIR/qmake-xnview"
QT_PLUGIN_SOURCE="$SOURCE_DIR/qt-plugins"
QT_TRANSLATIONS_SOURCE="$SOURCE_DIR/qt-translations"

rm -rf "$SOURCE_DIR" "$APPDIR" "$DIST_DIR"
mkdir -p "$SOURCE_DIR" "$DIST_DIR"

yay -S --noconfirm --needed qt5-base qt5-declarative qt5-translations

curl -fL --retry 3 \
  https://download.xnview.com/versions/XnView_MP/XnView_MP-CHECKSUMS.txt \
  -o "$CHECKSUMS"
read -r EXPECTED_SHA APPIMAGE_NAME < <(
  grep -m1 -E '^[0-9a-f]{64}  XnView_MP-[0-9.]+\.glibc[0-9.]+-x86_64\.AppImage$' "$CHECKSUMS"
)
[[ -n "${EXPECTED_SHA:-}" && -n "${APPIMAGE_NAME:-}" ]]

curl -fL --retry 3 \
  "https://download.xnview.com/versions/XnView_MP/$APPIMAGE_NAME" \
  -o "$OFFICIAL_APPIMAGE"
echo "$EXPECTED_SHA  $OFFICIAL_APPIMAGE" | sha256sum -c -
chmod +x "$OFFICIAL_APPIMAGE"

(
  cd "$SOURCE_DIR"
  "$OFFICIAL_APPIMAGE" --appimage-extract >/dev/null
)
mv "$SOURCE_DIR/squashfs-root" "$APPDIR"
mv "$APPDIR/AppRun" "$APPDIR/AppRun.official"

cat > "$CUSTOM_APPRUN" <<'APP_RUN'
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "$0")")"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/xnviewmp"
INI="$CONFIG_DIR/xnview-zh_CN.ini"

mkdir -p "$CONFIG_DIR"
if [[ ! -f "$INI" ]]; then
  printf '[Start]\nlanguage=zh_CN\n' > "$INI"
elif grep -q '^language=' "$INI"; then
  sed -i 's/^language=.*/language=zh_CN/' "$INI"
elif grep -q '^\[Start\]$' "$INI"; then
  sed -i '/^\[Start\]$/a language=zh_CN' "$INI"
else
  printf '\n[Start]\nlanguage=zh_CN\n' >> "$INI"
fi

export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_MESSAGES=zh_CN.UTF-8
export QT_QPA_PLATFORM=xcb
exec "$HERE/AppRun.official" -ini "$INI" "$@"
APP_RUN
chmod +x "$CUSTOM_APPRUN" "$APPDIR/AppRun.official"

curl -fL --retry 3 \
  https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage \
  -o "$LINUXDEPLOY"
curl -fL --retry 3 \
  https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage \
  -o "$QT_PLUGIN"
curl -fL --retry 3 \
  https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage \
  -o "$APPIMAGETOOL"
curl -fL --retry 3 \
  https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-x86_64 \
  -o "$RUNTIME_FILE"
chmod +x "$LINUXDEPLOY" "$QT_PLUGIN" "$APPIMAGETOOL"

HOST_QMAKE="$(command -v qmake-qt5 || command -v qmake)"
HOST_QT_BINS="$($HOST_QMAKE -query QT_INSTALL_BINS)"
HOST_QT_LIBEXECS="$($HOST_QMAKE -query QT_INSTALL_LIBEXECS)"
HOST_QT_TRANSLATIONS="$($HOST_QMAKE -query QT_INSTALL_TRANSLATIONS)"
QT_CORE_REAL="$(basename "$(readlink -f "$APPDIR/opt/XnView/lib/libQt5Core.so.5")")"
QT_VERSION="${QT_CORE_REAL#libQt5Core.so.}"

mkdir -p "$APPDIR/usr/lib" "$QT_PLUGIN_SOURCE" "$QT_TRANSLATIONS_SOURCE"
cp -a "$APPDIR/opt/XnView/lib"/libQt5*.so* "$APPDIR/usr/lib/"
if [[ -d "$APPDIR/usr/plugins" ]]; then
  cp -a "$APPDIR/usr/plugins/." "$QT_PLUGIN_SOURCE/"
fi
for plugin_dir in "$APPDIR/opt/XnView/lib"/*; do
  [[ -d "$plugin_dir" ]] || continue
  cp -a "$plugin_dir" "$QT_PLUGIN_SOURCE/"
done
if [[ -d "$APPDIR/usr/translations" ]]; then
  cp -a "$APPDIR/usr/translations/." "$QT_TRANSLATIONS_SOURCE/"
fi
cp -a "$HOST_QT_TRANSLATIONS"/*.qm "$QT_TRANSLATIONS_SOURCE/" 2>/dev/null || true

cat > "$FAKE_QMAKE" <<EOF_QMAKE
#!/usr/bin/env bash
case "\${1:-}" in
  -query)
    case "\${2:-}" in
      QT_INSTALL_PLUGINS) echo "$QT_PLUGIN_SOURCE" ;;
      QT_INSTALL_LIBEXECS) echo "$HOST_QT_LIBEXECS" ;;
      QT_INSTALL_DATA) echo "$APPDIR/opt/XnView" ;;
      QT_INSTALL_TRANSLATIONS) echo "$QT_TRANSLATIONS_SOURCE" ;;
      QT_INSTALL_BINS) echo "$HOST_QT_BINS" ;;
      QT_INSTALL_LIBS) echo "$APPDIR/opt/XnView/lib" ;;
      QT_INSTALL_QML) echo "$APPDIR/opt/XnView/qml" ;;
      QT_VERSION) echo "$QT_VERSION" ;;
      '')
        printf '%s\n' \
          'QT_INSTALL_PLUGINS:$QT_PLUGIN_SOURCE' \
          'QT_INSTALL_LIBEXECS:$HOST_QT_LIBEXECS' \
          'QT_INSTALL_DATA:$APPDIR/opt/XnView' \
          'QT_INSTALL_TRANSLATIONS:$QT_TRANSLATIONS_SOURCE' \
          'QT_INSTALL_BINS:$HOST_QT_BINS' \
          'QT_INSTALL_LIBS:$APPDIR/opt/XnView/lib' \
          'QT_INSTALL_QML:$APPDIR/opt/XnView/qml' \
          'QT_VERSION:$QT_VERSION'
        ;;
      *) exit 1 ;;
    esac
    ;;
  *) exit 1 ;;
esac
EOF_QMAKE
chmod +x "$FAKE_QMAKE"

export ARCH=x86_64
export QMAKE="$FAKE_QMAKE"
export QML_SOURCES_PATHS="$APPDIR/opt/XnView/qml"
export PATH="$HOST_QT_BINS:$HOST_QT_LIBEXECS:$PATH"
export LD_LIBRARY_PATH="$APPDIR/opt/XnView/lib:$APPDIR/opt/XnView/Plugins:$APPDIR/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"

NO_STRIP=1 APPIMAGE_EXTRACT_AND_RUN=1 \
  "$LINUXDEPLOY" \
  --appdir "$APPDIR" \
  --custom-apprun "$CUSTOM_APPRUN" \
  --exclude-library='*' \
  --plugin qt

APPIMAGE_EXTRACT_AND_RUN=1 \
  "$APPIMAGETOOL" -n \
  --runtime-file "$RUNTIME_FILE" \
  "$APPDIR" "$OUTFILE"

chmod +x "$OUTFILE"
sha256sum "$OUTFILE"
