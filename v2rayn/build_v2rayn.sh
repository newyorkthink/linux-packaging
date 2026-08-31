#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APPDIR="$SCRIPT_DIR/AppDir"
DIST_DIR="$SCRIPT_DIR/dist"
SOURCE_DIR="$SCRIPT_DIR/source"
VERIFY_DIR="$SCRIPT_DIR/verify"
WORK_DIR="$SCRIPT_DIR/work"
ARCHIVE="$WORK_DIR/v2rayN-linux-64.zip"
RELEASE_JSON="$WORK_DIR/release.json"

fail() {
  echo "v2rayN build error: $*" >&2
  exit 1
}

clean_project_dir() {
  local target="$1"
  case "$target" in
    "$SCRIPT_DIR"/*) rm -rf -- "$target" ;;
    *) fail "refusing to remove path outside project: $target" ;;
  esac
}

[[ "$(uname -m)" == "x86_64" ]] || fail "only x86_64 is supported"
command -v quick-sharun >/dev/null 2>&1 || fail "quick-sharun is not available"

cd "$SCRIPT_DIR"
for target in "$APPDIR" "$DIST_DIR" "$SOURCE_DIR" "$VERIFY_DIR" "$WORK_DIR"; do
  clean_project_dir "$target"
done
mkdir -p "$DIST_DIR" "$SOURCE_DIR" "$VERIFY_DIR" "$WORK_DIR"

# Build/runtime libraries required by the official self-contained Avalonia Linux package,
# plus isolated X11/DBus smoke-test tooling.
yay -S --noconfirm --needed \
  bash curl jq unzip file patchelf coreutils desktop-file-utils xdg-utils \
  glibc gcc-libs zlib fontconfig freetype2 \
  libx11 libxext libxrender libxrandr libxi libxcb libxfixes libxinerama \
  libxcomposite libxcursor libxdamage libxkbcommon dbus \
  xorg-server-xvfb xorg-xauth

curl --fail --silent --show-error --location \
  --retry 3 --retry-delay 2 --connect-timeout 20 --max-time 120 \
  https://api.github.com/repos/2dust/v2rayN/releases/latest \
  -o "$RELEASE_JSON"

TAG="$(jq -er 'select(.draft == false and .prerelease == false) | .tag_name' "$RELEASE_JSON")"
[[ "$TAG" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z]+)*$ ]] || fail "unexpected stable release tag: $TAG"
VERSION="${TAG#v}"
ASSET_NAME="v2rayN-linux-64.zip"
ASSET_URL="$(jq -er --arg name "$ASSET_NAME" '.assets[] | select(.name == $name) | .browser_download_url' "$RELEASE_JSON")"
ASSET_DIGEST="$(jq -er --arg name "$ASSET_NAME" '.assets[] | select(.name == $name) | .digest' "$RELEASE_JSON")"

case "$ASSET_URL" in
  https://github.com/2dust/v2rayN/releases/download/*/v2rayN-linux-64.zip) ;;
  *) fail "unexpected release asset URL: $ASSET_URL" ;;
esac
[[ "$ASSET_DIGEST" =~ ^sha256:[0-9a-fA-F]{64}$ ]] || fail "missing or invalid GitHub release SHA-256 digest"

curl --fail --show-error --location \
  --retry 3 --retry-delay 2 --connect-timeout 20 --max-time 900 \
  "$ASSET_URL" -o "$ARCHIVE"

EXPECTED_SHA256="${ASSET_DIGEST#sha256:}"
ACTUAL_SHA256="$(sha256sum "$ARCHIVE" | cut -d' ' -f1)"
[[ "${ACTUAL_SHA256,,}" == "${EXPECTED_SHA256,,}" ]] || fail "release archive SHA-256 mismatch"
printf 'v2rayN version: %s\nsource sha256: %s\n' "$VERSION" "$ACTUAL_SHA256"

unzip -q "$ARCHIVE" -d "$SOURCE_DIR"
MAIN_SOURCE="$(find "$SOURCE_DIR" -type f -name 'v2rayN' -print -quit)"
[[ -n "$MAIN_SOURCE" && -f "$MAIN_SOURCE" ]] || fail "v2rayN executable not found in official archive"
chmod +x "$MAIN_SOURCE"
APP_ROOT="$(dirname -- "$MAIN_SOURCE")"
MAIN_FILE_INFO="$(file -Lb "$MAIN_SOURCE")"
[[ "$MAIN_FILE_INFO" == *"ELF 64-bit"* && "$MAIN_FILE_INFO" == *"x86-64"* ]] || fail "unexpected v2rayN executable type: $MAIN_FILE_INFO"
[[ -d "$APP_ROOT/bin" ]] || fail "official runtime bin directory is missing"
ICON_SOURCE="$APP_ROOT/v2rayN.png"
[[ -s "$ICON_SOURCE" ]] || fail "official v2rayN.png icon is missing"

DESKTOP_FILE="$WORK_DIR/v2rayn.desktop"
cat > "$DESKTOP_FILE" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=v2rayN
Comment=v2rayN for Linux
Exec=v2rayN
Icon=v2rayn
Terminal=false
Categories=Network;
DESKTOP
desktop-file-validate "$DESKTOP_FILE"

export ARCH=x86_64
export VERSION
export APPNAME="v2rayN"
export STARTUPWMCLASS="v2rayN"
export ICON="$ICON_SOURCE"
export DESKTOP="$DESKTOP_FILE"
export OUTPATH="$DIST_DIR"
export OUTNAME="v2rayn.AppImage"

# Put the real GUI executable first so quick-sharun selects the intended AppImage entrypoint.
ELF_INPUTS=("$MAIN_SOURCE")
while IFS= read -r -d '' candidate; do
  [[ "$candidate" == "$MAIN_SOURCE" ]] && continue
  description="$(file -Lb "$candidate")"
  if [[ "$description" == ELF* && ( "$description" == *"dynamically linked"* || "$description" == *"shared object"* ) ]]; then
    ELF_INPUTS+=("$candidate")
  fi
done < <(find "$APP_ROOT" -type f -print0)

quick-sharun "${ELF_INPUTS[@]}"
[[ -x "$APPDIR/AppRun" ]] || fail "quick-sharun did not create AppRun"

# Preserve the official self-contained directory exactly. shared/bin holds the real files;
# bin also gets the data tree because sharun launches through its bin hardlinks.
mkdir -p "$APPDIR/bin" "$APPDIR/shared/bin"
cp -an "$APP_ROOT"/. "$APPDIR/bin"/
cp -an "$APP_ROOT"/. "$APPDIR/shared/bin"/

# The upstream Debian launcher changes into /opt/v2rayN before exec; keep the same semantics.
touch "$APPDIR/.env"
if ! grep -Fxq 'SHARUN_WORKING_DIR=${SHARUN_DIR}/bin' "$APPDIR/.env"; then
  printf '%s\n' 'SHARUN_WORKING_DIR=${SHARUN_DIR}/bin' >> "$APPDIR/.env"
fi
if ! grep -Fxq 'PATH=${SHARUN_DIR}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' "$APPDIR/.env"; then
  printf '%s\n' 'PATH=${SHARUN_DIR}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' >> "$APPDIR/.env"
fi
printf '%s\n' 'v2rayN' > "$APPDIR/.app"

[[ -x "$APPDIR/shared/bin/v2rayN" ]] || fail "packaged v2rayN executable is missing"
[[ -d "$APPDIR/shared/bin/bin" ]] || fail "packaged v2rayN core/data directory is missing"
[[ -s "$APPDIR/bin/v2rayN.png" ]] || fail "packaged icon source is missing"

quick-sharun --make-appimage
APPIMAGE="$DIST_DIR/v2rayn.AppImage"
[[ -x "$APPIMAGE" && -s "$APPIMAGE" ]] || fail "AppImage was not created"
file "$APPIMAGE"
sha256sum "$APPIMAGE" | tee "$DIST_DIR/v2rayn.AppImage.sha256"

EXTRACT_DIR="$VERIFY_DIR/extract"
mkdir -p "$EXTRACT_DIR"
(
  cd "$EXTRACT_DIR"
  "$APPIMAGE" --appimage-extract >/dev/null
)
EXTRACTED="$EXTRACT_DIR/squashfs-root"
[[ -x "$EXTRACTED/AppRun" ]] || fail "extracted AppRun is missing"
[[ -x "$EXTRACTED/shared/bin/v2rayN" ]] || fail "extracted v2rayN executable is missing"
[[ -d "$EXTRACTED/shared/bin/bin" ]] || fail "extracted core/data directory is missing"

# The extracted executable is launched through sharun; the isolated GUI smoke test below
# is the authoritative runtime dependency check for the bundled loader/library path.
SMOKE_HOME="$VERIFY_DIR/smoke-home"
SMOKE_LOG="$VERIFY_DIR/smoke.log"
mkdir -p "$SMOKE_HOME/config" "$SMOKE_HOME/cache" "$SMOKE_HOME/data"
set +e
HOME="$SMOKE_HOME" \
XDG_CONFIG_HOME="$SMOKE_HOME/config" \
XDG_CACHE_HOME="$SMOKE_HOME/cache" \
XDG_DATA_HOME="$SMOKE_HOME/data" \
APPIMAGE_EXTRACT_AND_RUN=1 \
timeout 20s dbus-run-session -- xvfb-run -a "$APPIMAGE" >"$SMOKE_LOG" 2>&1
SMOKE_RC=$?
set -e

cat "$SMOKE_LOG"
if grep -Eqi 'Unhandled exception|DllNotFoundException|Segmentation fault|core dumped|Exec format error|wrong ELF class' "$SMOKE_LOG"; then
  fail "fatal runtime error detected during smoke test"
fi
[[ "$SMOKE_RC" -eq 124 ]] || fail "GUI did not remain running for the 20-second smoke test (exit=$SMOKE_RC)"

echo "v2rayN AppImage build and smoke test passed."
