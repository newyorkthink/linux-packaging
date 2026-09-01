#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SOURCE_DIR="$SCRIPT_DIR/source"
APPDIR="$SCRIPT_DIR/AppDir"
DIST_DIR="$SCRIPT_DIR/dist"
DEB_FILE="$SOURCE_DIR/joplin.deb"
RELEASES_JSON="$SOURCE_DIR/releases.json"
LINUXDEPLOY="$SOURCE_DIR/linuxdeploy"
GTK_PLUGIN="$SOURCE_DIR/linuxdeploy-plugin-gtk"
RUNTIME_FILE="$SOURCE_DIR/runtime-x86_64"
OUTFILE="$DIST_DIR/joplin.AppImage"

rm -rf "$SOURCE_DIR" "$APPDIR" "$DIST_DIR"
mkdir -p "$SOURCE_DIR" "$DIST_DIR"

if command -v sudo >/dev/null 2>&1; then
  APT=(sudo apt-get)
else
  APT=(apt-get)
fi

"${APT[@]}" update
DEBIAN_FRONTEND=noninteractive "${APT[@]}" install -y --no-install-recommends \
  ca-certificates curl dpkg-dev file findutils gawk grep pkgconf python3 sed \
  libglib2.0-bin libglib2.0-dev libgirepository1.0-dev \
  libgtk-3-bin libgtk-3-dev libgdk-pixbuf2.0-bin libgdk-pixbuf-2.0-dev \
  librsvg2-dev librsvg2-common libpango1.0-dev \
  ibus-gtk3 libibus-1.0-5 \
  libasound2 libatk1.0-0 libatk-bridge2.0-0 libatspi2.0-0 libcairo2 libcups2 \
  libdbus-1-3 libdrm2 libgbm1 libgdk-pixbuf-2.0-0 libglib2.0-0 libgtk-3-0 \
  libnotify4 libnspr4 libnss3 libpango-1.0-0 libsecret-1-0 libuuid1 \
  libappindicator3-1 \
  libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 \
  libxfixes3 libxi6 libxinerama1 libxkbcommon0 libxrandr2 libxrender1 \
  libxshmfence1 libxss1 libxtst6 \
  xdg-utils shared-mime-info hicolor-icon-theme

curl -fL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 20 \
  -H 'Accept: application/vnd.github+json' \
  'https://api.github.com/repos/laurent22/joplin/releases?per_page=30' \
  -o "$RELEASES_JSON"

mapfile -t RELEASE_META < <(
  python3 - "$RELEASES_JSON" <<'PY'
import json
import re
import sys

with open(sys.argv[1], encoding='utf-8') as f:
    releases = json.load(f)

items = []
for release in releases:
    if release.get('draft'):
        continue
    tag = str(release.get('tag_name', ''))
    m = re.fullmatch(r'v?([0-9]+(?:\.[0-9]+)+)', tag)
    if not m:
        continue
    version = m.group(1)
    name = f'Joplin-{version}.deb'
    assets = [a for a in release.get('assets', []) if a.get('name') == name]
    if len(assets) != 1:
        continue
    asset = assets[0]
    digest = str(asset.get('digest', ''))
    if not re.fullmatch(r'sha256:[0-9a-fA-F]{64}', digest):
        continue
    items.append((tuple(map(int, version.split('.'))), version, asset['browser_download_url'], digest.split(':', 1)[1].lower()))

if not items:
    raise SystemExit('No published Joplin Linux x64 DEB found')

_, version, url, sha256 = max(items, key=lambda x: x[0])
print(version)
print(url)
print(sha256)
PY
)

VERSION="${RELEASE_META[0]}"
DEB_URL="${RELEASE_META[1]}"
EXPECTED_SHA256="${RELEASE_META[2]}"
printf 'Joplin version: %s\n' "$VERSION"

curl -fL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 20 \
  "$DEB_URL" -o "$DEB_FILE"
echo "$EXPECTED_SHA256  $DEB_FILE" | sha256sum -c -

dpkg-deb -x "$DEB_FILE" "$APPDIR"
test -x "$APPDIR/opt/Joplin/joplin"
test -f "$APPDIR/opt/Joplin/resources/app.asar"

DESKTOP_FILE="$(find "$APPDIR/usr/share/applications" -maxdepth 1 -type f -iname '*joplin*.desktop' -print -quit)"
test -n "$DESKTOP_FILE"
sed -i -e 's|^Exec=.*|Exec=joplin %U|' -e 's|^Icon=.*|Icon=joplin|' "$DESKTOP_FILE"

# linuxdeploy 不接受 1024x1024 图标；保留官方 512x512 及其他标准尺寸。
rm -f "$APPDIR/usr/share/icons/hicolor/1024x1024/apps/joplin.png"

# 保留 usr/bin/joplin 作为 desktop Exec 入口。
mkdir -p "$APPDIR/usr/bin"
cat > "$APPDIR/usr/bin/joplin" <<'WRAPPER'
#!/usr/bin/env sh
exec "${APPDIR}/opt/Joplin/joplin" "$@"
WRAPPER
chmod +x "$APPDIR/usr/bin/joplin"
sh -n "$APPDIR/usr/bin/joplin"

# 预先创建根目录 AppRun。linuxdeploy 发现 GTK hook 后会把它重命名为普通文件 AppRun.wrapped，
# 再生成新的 AppRun 负责 source GTK hook；这样运行环境在 AppRun.wrapped 中完整保留。
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env sh

HERE="$(dirname "$(readlink -f "${0}")")"

export PATH="$HERE"/opt/Joplin:"$HERE"/usr/bin:"$HERE"/usr/lib:"$HERE"/usr/share:"$PATH"
export LD_LIBRARY_PATH="$HERE"/opt/Joplin:"$HERE"/usr/bin:"$HERE"/usr/lib:"$HERE"/usr/share:"$LD_LIBRARY_PATH"
export XDG_DATA_DIRS="$HERE"/opt/Joplin:"$HERE"/usr/bin:"$HERE"/usr/lib:"$HERE"/usr/share:"$XDG_DATA_DIRS"
export GSETTINGS_SCHEMA_DIR="${HERE}"/usr/share/glib-2.0/schemas/:"${GSETTINGS_SCHEMA_DIR}"

export GTK_THEME=Adwaita-dark
export NO_AT_BRIDGE=1

exec "$HERE"/opt/Joplin/joplin "$@"
APPRUN
chmod +x "$APPDIR/AppRun"
sh -n "$APPDIR/AppRun"

# Electron/NSS 会 dlopen 这些模块；linuxdeploy 只跟踪 ELF NEEDED，不会自动收集它们。
MULTIARCH="$(dpkg-architecture -qDEB_HOST_MULTIARCH)"
if compgen -G "/usr/lib/$MULTIARCH/nss/*.so" >/dev/null; then
  mkdir -p "$APPDIR/usr/lib"
  cp -a /usr/lib/"$MULTIARCH"/nss/*.so "$APPDIR/usr/lib/"
fi

curl -fL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 20 \
  https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage \
  -o "$LINUXDEPLOY"
curl -fL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 20 \
  https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-x86_64 \
  -o "$RUNTIME_FILE"
chmod +x "$LINUXDEPLOY"
cp "$SCRIPT_DIR/linuxdeploy-plugin-gtk" "$GTK_PLUGIN"
chmod +x "$GTK_PLUGIN"

export PATH="$SOURCE_DIR:$PATH"
export LINUXDEPLOY="$LINUXDEPLOY"
export DEPLOY_GTK_VERSION=3
export APPIMAGE_EXTRACT_AND_RUN=1
export LDAI_OUTPUT="$OUTFILE"
export LDAI_RUNTIME_FILE="$RUNTIME_FILE"

# 使用已验证的 linuxdeploy + GTK 插件命令打包。
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin gtk --output appimage

test -s "$OUTFILE"
sha256sum "$OUTFILE"
