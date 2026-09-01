#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log() {
  printf '[BaiduNetDisk] %s\n' "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ "$(uname -m)" == "x86_64" ]] || die "only x86_64 is supported"

SOURCE_DIR="$SCRIPT_DIR/source"
APPDIR="$SCRIPT_DIR/AppDir"
DIST_DIR="$SCRIPT_DIR/dist"
OUTFILE="$DIST_DIR/baidunetdisk.AppImage"
DEB="$SOURCE_DIR/baidunetdisk.deb"
LINUXDEPLOY="$SOURCE_DIR/linuxdeploy"
GTK_PLUGIN="$SOURCE_DIR/linuxdeploy-plugin-gtk"
THEME_DEB_DIR="$SOURCE_DIR/theme-debs"
VERIFY_DIR="$SOURCE_DIR/verify-appimage"
SMOKE_HOME="$SOURCE_DIR/smoke-home"
SMOKE_RUNTIME="$SOURCE_DIR/smoke-runtime"
SMOKE_LOG_1="$SOURCE_DIR/smoke-1.log"
SMOKE_LOG_2="$SOURCE_DIR/smoke-2.log"
CLIENT_API='https://pan.baidu.com/disk/cmsdata?do=client'

rm -rf "$SOURCE_DIR" "$APPDIR" "$DIST_DIR"
mkdir -p "$SOURCE_DIR" "$DIST_DIR"

if command -v sudo >/dev/null 2>&1; then
  APT=(sudo apt-get)
else
  APT=(apt-get)
fi

"${APT[@]}" update
DEBIAN_FRONTEND=noninteractive "${APT[@]}" install -y --no-install-recommends \
  ca-certificates curl desktop-file-utils dpkg-dev file findutils gawk grep pkgconf python3 sed coreutils \
  binutils patchelf xz-utils bzip2 zstd dbus dbus-x11 xvfb xauth \
  libglib2.0-bin libglib2.0-dev libgirepository1.0-dev libgtk-3-dev \
  libgdk-pixbuf-2.0-dev librsvg2-dev libpango1.0-dev \
  ibus-gtk3 \
  libasound2 libatk1.0-0 libatk-bridge2.0-0 libatspi2.0-0 libcairo2 libcups2 \
  libdbus-1-3 libdrm2 libgbm1 libgdk-pixbuf-2.0-0 libglib2.0-0 libgtk-3-0 \
  libgtkmm-2.4-1v5 libnotify4 libnss3 libnspr4 libpango-1.0-0 libsecret-1-0 \
  libappindicator3-1 \
  libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 \
  libxfixes3 libxi6 libxkbcommon0 libxrandr2 libxrender1 libxss1 libxtst6 \
  xdg-utils shared-mime-info hicolor-icon-theme

for command_name in \
  curl dbus-run-session desktop-file-validate dpkg-deb file find grep ldd \
  python3 readelf sed sha256sum timeout xvfb-run; do
  command -v "$command_name" >/dev/null 2>&1 || die "required command missing: $command_name"
done

log "read current official Linux client version"
CLIENT_JSON="$(curl -fsSL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 20 "$CLIENT_API")"
[[ -n "$CLIENT_JSON" ]] || die "official client metadata is empty"

RAW_VERSION="$(printf '%s' "$CLIENT_JSON" | python3 -c '
import json, sys
payload = json.load(sys.stdin)
linux = payload.get("linux") or {}
print(linux.get("version") or "")
')"
if [[ "$RAW_VERSION" =~ ^(百度网盘Linux电脑客户端)?V?([0-9]+(\.[0-9]+)+)$ ]]; then
  VERSION="${BASH_REMATCH[2]}"
else
  die "unexpected official version string: $RAW_VERSION"
fi
PACKAGE_URL="https://issuepcdn.baidupcs.com/issue/netdisk/LinuxGuanjia/$VERSION/baidunetdisk_${VERSION}_amd64.deb"

log "download official DEB: $VERSION"
curl -fL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 20 "$PACKAGE_URL" -o "$DEB"
[[ -s "$DEB" ]] || die "downloaded DEB is empty"
file "$DEB" | grep -q 'Debian binary package' || die "download is not a Debian package"
sha256sum "$DEB"

# Use dpkg-deb so data.tar.{xz,gz,bz2,zst,...} is handled by dpkg itself.
dpkg-deb -x "$DEB" "$APPDIR"

APP_ROOT="$APPDIR/opt/baidunetdisk"
MAIN_BIN="$APP_ROOT/baidunetdisk"
[[ -x "$MAIN_BIN" ]] || die "official package is missing /opt/baidunetdisk/baidunetdisk"
file "$MAIN_BIN" | grep -q 'ELF 64-bit' || die "main executable is not a 64-bit ELF"

# Bundle the Adwaita assets used by the GTK hook instead of relying on the host theme installation.
mkdir -p "$THEME_DEB_DIR"
(
  cd "$THEME_DEB_DIR"
  apt-get download adwaita-icon-theme adwaita-icon-theme-full gnome-themes-extra-data
)
for theme_deb in "$THEME_DEB_DIR"/*.deb; do
  dpkg-deb -x "$theme_deb" "$APPDIR"
done

mapfile -d '' desktop_candidates < <(
  find "$APPDIR/usr/share/applications" -maxdepth 1 -type f \
    \( -iname '*baidunetdisk*.desktop' -o -iname '*baidu*netdisk*.desktop' \) -print0 2>/dev/null
)
[[ ${#desktop_candidates[@]} -eq 1 ]] || die "expected exactly one Baidu Netdisk desktop file, found ${#desktop_candidates[@]}"
DESKTOP_FILE="${desktop_candidates[0]}"

mapfile -d '' icon_candidates < <(
  find "$APPDIR/usr/share/icons" "$APPDIR/usr/share/pixmaps" "$APP_ROOT" \
    -type f \( -iname '*baidunetdisk*.png' -o -iname '*baidunetdisk*.svg' -o \
    -iname '*baidu*netdisk*.png' -o -iname '*baidu*netdisk*.svg' \) -print0 2>/dev/null
)
[[ ${#icon_candidates[@]} -gt 0 ]] || die "official package does not contain a Baidu Netdisk icon"

ICON_FILE="${icon_candidates[0]}"
ICON_SIZE="$(stat -c '%s' "$ICON_FILE")"
for candidate in "${icon_candidates[@]:1}"; do
  candidate_size="$(stat -c '%s' "$candidate")"
  if (( candidate_size > ICON_SIZE )); then
    ICON_FILE="$candidate"
    ICON_SIZE="$candidate_size"
  fi
done

sed -i \
  -e 's|^Exec=.*|Exec=baidunetdisk %U|' \
  -e 's|^Icon=.*|Icon=baidunetdisk|' \
  -e '/^Encoding=/d' \
  -e '/^Value=/d' \
  -e 's/^Terminal=0$/Terminal=false/' \
  "$DESKTOP_FILE"
desktop-file-validate "$DESKTOP_FILE"

mkdir -p "$APPDIR/usr/bin"
cat > "$APPDIR/usr/bin/baidunetdisk" <<'EOF_LAUNCHER'
#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(dirname "$(readlink -f "$0")")"
ROOT="$(readlink -f "$HERE/../..")"
APP_ROOT="$ROOT/opt/baidunetdisk"
export LD_LIBRARY_PATH="$APP_ROOT:$ROOT/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PATH="$ROOT/usr/bin:${PATH:-/usr/bin:/bin}"
cd "$APP_ROOT"
exec "$APP_ROOT/baidunetdisk" --no-sandbox "$@"
EOF_LAUNCHER
chmod +x "$APPDIR/usr/bin/baidunetdisk"
bash -n "$APPDIR/usr/bin/baidunetdisk"

# Keep the Electron NSS core and dlopen modules on one Ubuntu 22.04 runtime set.
MULTIARCH="$(dpkg-architecture -qDEB_HOST_MULTIARCH)"
mkdir -p "$APPDIR/usr/lib"
cp -a \
  "/usr/lib/$MULTIARCH/libnss3.so" \
  "/usr/lib/$MULTIARCH/libnssutil3.so" \
  "/usr/lib/$MULTIARCH/libsmime3.so" \
  "/usr/lib/$MULTIARCH/libssl3.so" \
  "/usr/lib/$MULTIARCH/libfreebl3.so" \
  "/usr/lib/$MULTIARCH/libfreebl3.chk" \
  "/usr/lib/$MULTIARCH/libfreeblpriv3.so" \
  "/usr/lib/$MULTIARCH/libfreeblpriv3.chk" \
  "/usr/lib/$MULTIARCH/nss/libnssckbi.so" \
  "/usr/lib/$MULTIARCH/nss/libnssdbm3.so" \
  "/usr/lib/$MULTIARCH/nss/libnssdbm3.chk" \
  "/usr/lib/$MULTIARCH/nss/libsoftokn3.so" \
  "/usr/lib/$MULTIARCH/nss/libsoftokn3.chk" \
  "$APPDIR/usr/lib/"

# Baidu Netdisk loads GTKmm 2.4 dynamically through Koffi, so normal ldd on the Electron binary cannot discover it.
GTKMM2_LIB="/usr/lib/$MULTIARCH/libgtkmm-2.4.so.1"
APPINDICATOR_LIB="/usr/lib/$MULTIARCH/libappindicator3.so.1"
[[ -e "$GTKMM2_LIB" ]] || die "required GTKmm 2.4 runtime is missing: $GTKMM2_LIB"
[[ -e "$APPINDICATOR_LIB" ]] || die "required AppIndicator runtime is missing: $APPINDICATOR_LIB"

curl -fL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 20 \
  https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage \
  -o "$LINUXDEPLOY"
cp "$SCRIPT_DIR/linuxdeploy-plugin-gtk" "$GTK_PLUGIN"
chmod +x "$LINUXDEPLOY" "$GTK_PLUGIN"

export PATH="$SOURCE_DIR:$PATH"
export LINUXDEPLOY="$LINUXDEPLOY"
export ARCH=x86_64
export APPIMAGE_EXTRACT_AND_RUN=1
export DEPLOY_GTK_VERSION=3
export LDAI_OUTPUT="$OUTFILE"
export VERSION

log "package with Ubuntu 22.04 + linuxdeploy + GTK plugin"
"$LINUXDEPLOY" \
  --appdir "$APPDIR" \
  --desktop-file "$DESKTOP_FILE" \
  --icon-file "$ICON_FILE" \
  --library "$GTKMM2_LIB" \
  --library "$APPINDICATOR_LIB" \
  --plugin gtk \
  --output appimage

[[ -s "$OUTFILE" ]] || die "linuxdeploy did not create the AppImage"
chmod +x "$OUTFILE"
"$OUTFILE" --appimage-version

rm -rf "$VERIFY_DIR"
mkdir -p "$VERIFY_DIR"
(
  cd "$VERIFY_DIR"
  "$OUTFILE" --appimage-extract >/dev/null
)
VERIFY_ROOT="$VERIFY_DIR/squashfs-root"
[[ -x "$VERIFY_ROOT/usr/bin/baidunetdisk" ]] || die "final AppImage is missing launcher"
[[ -x "$VERIFY_ROOT/opt/baidunetdisk/baidunetdisk" ]] || die "final AppImage is missing official executable"
grep -Fq -- '--no-sandbox' "$VERIFY_ROOT/usr/bin/baidunetdisk" || die "final launcher is incorrect"
find "$VERIFY_ROOT/usr/lib" -maxdepth 1 -name 'libgtkmm-2.4.so.1*' -print -quit | grep -q . || die "final AppImage is missing GTKmm 2.4"
[[ -e "$VERIFY_ROOT/usr/lib/libnss3.so" ]] || die "final AppImage is missing bundled NSS"

LDD_OUTPUT="$(LD_LIBRARY_PATH="$VERIFY_ROOT/opt/baidunetdisk:$VERIFY_ROOT/usr/lib" ldd "$VERIFY_ROOT/opt/baidunetdisk/baidunetdisk" 2>&1 || true)"
printf '%s\n' "$LDD_OUTPUT"
if grep -Fq 'not found' <<<"$LDD_OUTPUT"; then
  die "final AppImage still has unresolved shared libraries"
fi

run_smoke() {
  local pass="$1"
  local log_file="$2"
  local status=0

  mkdir -p "$SMOKE_HOME" "$SMOKE_RUNTIME"
  chmod 0700 "$SMOKE_RUNTIME"

  set +e
  timeout 25s \
    env HOME="$SMOKE_HOME" \
      XDG_CONFIG_HOME="$SMOKE_HOME/.config" \
      XDG_CACHE_HOME="$SMOKE_HOME/.cache" \
      XDG_DATA_HOME="$SMOKE_HOME/.local/share" \
      XDG_RUNTIME_DIR="$SMOKE_RUNTIME" \
      APPIMAGE_EXTRACT_AND_RUN=1 \
      dbus-run-session -- xvfb-run -a "$OUTFILE" --disable-gpu \
      >"$log_file" 2>&1
  status=$?
  set -e

  cat "$log_file" || true
  case "$status" in
    0|124) ;;
    *) die "smoke pass $pass exited with status $status" ;;
  esac

  if grep -Eqi \
    'failed to load shared library|cannot open shared object file|sqlcipher_page_cipher: hmac check failed|sqlite3Codec: error decrypting|sqlcipher_codec_ctx_set_error|segmentation fault|trace/breakpoint trap|symbol lookup error|error while loading shared libraries|wrong ELF class|invalid ELF' \
    "$log_file"; then
    die "smoke pass $pass detected a fatal runtime error"
  fi
}

rm -rf "$SMOKE_HOME" "$SMOKE_RUNTIME"
run_smoke 1 "$SMOKE_LOG_1"
run_smoke 2 "$SMOKE_LOG_2"

sha256sum "$OUTFILE"
log "done: $OUTFILE"
