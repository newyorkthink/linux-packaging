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
CUSTOM_APPRUN="$SOURCE_DIR/AppRun"

rm -rf "$SOURCE_DIR" "$APPDIR" "$DIST_DIR"
mkdir -p "$SOURCE_DIR" "$DIST_DIR"

# 直接取 XnView 官方当前 Linux AppImage，保留官方运行库。
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

# 只加旧正常包使用的中文环境，不碰官方 Qt/GLib/依赖。
cat > "$CUSTOM_APPRUN" <<'APP_RUN'
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "$0")")"
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
exec "$HERE/AppRun.official" "$@"
APP_RUN
chmod +x "$CUSTOM_APPRUN" "$APPDIR/AppRun.official"

curl -fL --retry 3 \
  https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage \
  -o "$LINUXDEPLOY"
chmod +x "$LINUXDEPLOY"

export ARCH=x86_64
export LDAI_OUTPUT="$OUTFILE"
NO_STRIP=1 APPIMAGE_EXTRACT_AND_RUN=1 \
  "$LINUXDEPLOY" \
  --appdir "$APPDIR" \
  --custom-apprun "$CUSTOM_APPRUN" \
  --exclude-library='*' \
  --output appimage

chmod +x "$OUTFILE"
