#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SOURCE_DIR="$SCRIPT_DIR/source"
APPDIR="$SCRIPT_DIR/AppDir"
DIST_DIR="$SCRIPT_DIR/dist"
OUTFILE="$DIST_DIR/xnviewmp.AppImage"
OFFICIAL_APPIMAGE="$SOURCE_DIR/XnView_MP.AppImage"
LINUXDEPLOY="$SOURCE_DIR/linuxdeploy-x86_64.AppImage"
APPIMAGETOOL="$SOURCE_DIR/appimagetool-x86_64.AppImage"
RUNTIME_FILE="$SOURCE_DIR/runtime-x86_64"
CUSTOM_APPRUN="$SOURCE_DIR/AppRun"

rm -rf "$SOURCE_DIR" "$APPDIR" "$DIST_DIR"
mkdir -p "$SOURCE_DIR" "$DIST_DIR"

curl -fL --retry 3 \
  https://download.xnview.com/XnView_MP.glibc2.34-x86_64.AppImage \
  -o "$OFFICIAL_APPIMAGE"
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
  printf '[General]\nLanguage=zh_CN\n' > "$INI"
elif grep -q '^Language=' "$INI"; then
  sed -i 's/^Language=.*/Language=zh_CN/' "$INI"
elif grep -q '^\[General\]$' "$INI"; then
  sed -i '/^\[General\]$/a Language=zh_CN' "$INI"
else
  printf '\n[General]\nLanguage=zh_CN\n' >> "$INI"
fi

export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_MESSAGES=zh_CN.UTF-8
exec "$HERE/AppRun.official" -ini "$INI" "$@"
APP_RUN
chmod +x "$CUSTOM_APPRUN" "$APPDIR/AppRun.official"

curl -fL --retry 3 \
  https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage \
  -o "$LINUXDEPLOY"
curl -fL --retry 3 \
  https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage \
  -o "$APPIMAGETOOL"
curl -fL --retry 3 \
  https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-x86_64 \
  -o "$RUNTIME_FILE"
chmod +x "$LINUXDEPLOY" "$APPIMAGETOOL"

export ARCH=x86_64
NO_STRIP=1 APPIMAGE_EXTRACT_AND_RUN=1 \
  "$LINUXDEPLOY" \
  --appdir "$APPDIR" \
  --custom-apprun "$CUSTOM_APPRUN" \
  --exclude-library='*'

APPIMAGE_EXTRACT_AND_RUN=1 \
  "$APPIMAGETOOL" -n \
  --runtime-file "$RUNTIME_FILE" \
  "$APPDIR" "$OUTFILE"

chmod +x "$OUTFILE"
