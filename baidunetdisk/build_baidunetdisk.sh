#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SOURCE_DIR="$SCRIPT_DIR/source"
APPDIR="$SCRIPT_DIR/AppDir"
DIST_DIR="$SCRIPT_DIR/dist"
DEB="$SOURCE_DIR/baidunetdisk.deb"
LINUXDEPLOY="$SOURCE_DIR/linuxdeploy-x86_64.AppImage"
GTK_PLUGIN="$SOURCE_DIR/linuxdeploy-plugin-gtk.sh"
OUTFILE="$DIST_DIR/baidunetdisk.AppImage"
CLIENT_API='https://pan.baidu.com/disk/cmsdata?do=client'

rm -rf "$SOURCE_DIR" "$APPDIR" "$DIST_DIR"
mkdir -p "$SOURCE_DIR" "$APPDIR" "$DIST_DIR"

yay -S --noconfirm --needed \
  binutils curl desktop-file-utils file findutils grep python tar \
  gtk3 gtkmm3 gobject-introspection librsvg pkgconf

CLIENT_JSON="$(curl -fsSL --retry 5 --retry-all-errors "$CLIENT_API")"
VERSION="$(printf '%s' "$CLIENT_JSON" | python3 -c '
import json, re, sys
v = (json.load(sys.stdin).get("linux") or {}).get("version", "")
m = re.search(r"([0-9]+(?:\.[0-9]+)+)$", v)
print(m.group(1) if m else "")
')"
[[ -n "$VERSION" ]] || { echo 'ERROR: cannot determine Baidu Netdisk version' >&2; exit 1; }

DEB_URL="https://pkg-ant.baidu.com/issue/netdisk/LinuxGuanjia/$VERSION/baidunetdisk_${VERSION}_amd64.deb"
echo "[BaiduNetDisk] download $DEB_URL"
curl -fL --retry 5 --retry-all-errors "$DEB_URL" -o "$DEB"

data_member="$(ar t "$DEB" | grep -m1 '^data\.tar')"
[[ -n "$data_member" ]] || { echo 'ERROR: data archive not found in DEB' >&2; exit 1; }
ar p "$DEB" "$data_member" | tar -xf - -C "$APPDIR"

test -x "$APPDIR/opt/baidunetdisk/baidunetdisk"

DESKTOP_FILE="$(find "$APPDIR/usr/share/applications" -maxdepth 1 -type f -iname '*baidu*netdisk*.desktop' -print -quit)"
[[ -n "$DESKTOP_FILE" ]] || { echo 'ERROR: desktop file not found' >&2; exit 1; }

ICON_FILE="$(find "$APPDIR/usr/share/icons" "$APPDIR/usr/share/pixmaps" "$APPDIR/opt/baidunetdisk" \
  -type f \( -iname '*baidunetdisk*.png' -o -iname '*baidu*netdisk*.png' -o -iname '*baidunetdisk*.svg' -o -iname '*baidu*netdisk*.svg' \) \
  -print 2>/dev/null | head -n1)"
[[ -n "$ICON_FILE" ]] || { echo 'ERROR: icon not found' >&2; exit 1; }

mkdir -p "$APPDIR/usr/bin"
cat > "$APPDIR/usr/bin/baidunetdisk" <<'EOF_LAUNCHER'
#!/usr/bin/env bash
set -e
ROOT="$(cd -- "$(dirname -- "$(readlink -f "$0")")/../.." && pwd)"
export LD_LIBRARY_PATH="$ROOT/opt/baidunetdisk${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cd "$ROOT/opt/baidunetdisk"
exec "$ROOT/opt/baidunetdisk/baidunetdisk" --no-sandbox "$@"
EOF_LAUNCHER
chmod +x "$APPDIR/usr/bin/baidunetdisk"

sed -i \
  -e 's|^Exec=.*|Exec=baidunetdisk %U|' \
  -e 's|^Icon=.*|Icon=baidunetdisk|' \
  "$DESKTOP_FILE"
desktop-file-validate "$DESKTOP_FILE" || true

curl -fL --retry 5 --retry-all-errors \
  https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage \
  -o "$LINUXDEPLOY"
curl -fL --retry 5 --retry-all-errors \
  https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh \
  -o "$GTK_PLUGIN"
chmod +x "$LINUXDEPLOY" "$GTK_PLUGIN"

export ARCH=x86_64
export APPIMAGE_EXTRACT_AND_RUN=1
export DEPLOY_GTK_VERSION=3
export LDAI_OUTPUT="$OUTFILE"
export VERSION

"$LINUXDEPLOY" \
  --appdir "$APPDIR" \
  --desktop-file "$DESKTOP_FILE" \
  --icon-file "$ICON_FILE" \
  --plugin gtk \
  --output appimage

test -s "$OUTFILE"
chmod +x "$OUTFILE"
sha256sum "$OUTFILE"
