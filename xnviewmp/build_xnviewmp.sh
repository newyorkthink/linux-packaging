#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BASE_URL="https://download.xnview.com/versions/XnView_MP"
SOURCE_DIR="$SCRIPT_DIR/source"
CHECKSUMS="$SOURCE_DIR/XnView_MP-CHECKSUMS.txt"
APPDIR="$SCRIPT_DIR/AppDir"
DIST_DIR="$SCRIPT_DIR/dist"
OUTFILE="$DIST_DIR/xnviewmp.AppImage"
LINUXDEPLOY="$SOURCE_DIR/linuxdeploy-x86_64.AppImage"
CUSTOM_APPRUN="$SOURCE_DIR/AppRun"

rm -rf "$SOURCE_DIR" "$APPDIR" "$DIST_DIR"
mkdir -p "$SOURCE_DIR" "$DIST_DIR"

# 直接使用 XnView 官方 AppImage 作为稳定运行时基线。
curl -fL --retry 3 "$BASE_URL/XnView_MP-CHECKSUMS.txt" -o "$CHECKSUMS"
APPIMAGE_NAME="$(awk '$2 ~ /^XnView_MP-[0-9.]+\.glibc[0-9.]+-x86_64\.AppImage$/ {print $2}' "$CHECKSUMS" | sort -V | tail -n1)"
APPIMAGE_SHA256="$(awk -v file="$APPIMAGE_NAME" '$2 == file {print $1; exit}' "$CHECKSUMS")"
OFFICIAL_APPIMAGE="$SOURCE_DIR/$APPIMAGE_NAME"

test -n "$APPIMAGE_NAME"
test -n "$APPIMAGE_SHA256"
curl -fL --retry 3 "$BASE_URL/$APPIMAGE_NAME" -o "$OFFICIAL_APPIMAGE"
echo "$APPIMAGE_SHA256  $OFFICIAL_APPIMAGE" | sha256sum -c -
chmod +x "$OFFICIAL_APPIMAGE"

(
  cd "$SOURCE_DIR"
  "$OFFICIAL_APPIMAGE" --appimage-extract >/dev/null
)
mv "$SOURCE_DIR/squashfs-root" "$APPDIR"
mv "$APPDIR/AppRun" "$APPDIR/AppRun.official"

# 只加入旧正常包已经验证过的中文环境，不改官方 Qt/GLib/运行库。
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
sha256sum "$OUTFILE"
