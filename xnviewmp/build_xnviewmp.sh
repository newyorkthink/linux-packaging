#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# XnView MP bundles an older Qt/media stack. Keep the package build on Ubuntu 22.04
# so linuxdeploy does not mix it with Ubuntu 24.04 media libraries.
if [[ "${GITHUB_ACTIONS:-}" == "true" && "${XNVIEWMP_JAMMY_INNER:-0}" != "1" ]]; then
  command -v docker >/dev/null 2>&1 || {
    echo "ERROR: docker is required for the XnView MP Jammy build" >&2
    exit 1
  }
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  exec docker run --rm \
    -e XNVIEWMP_JAMMY_INNER=1 \
    -e CI=1 \
    -e GH_TOKEN="${GH_TOKEN:-}" \
    -v "$REPO_ROOT:/workspace" \
    -w /workspace/xnviewmp \
    ubuntu:22.04 \
    bash ./build_xnviewmp.sh
fi

SOURCE_DIR="$SCRIPT_DIR/source"
APPDIR="$SCRIPT_DIR/AppDir"
DIST_DIR="$SCRIPT_DIR/dist"
OUTFILE="$DIST_DIR/xnviewmp.AppImage"
EXTRACT_DIR="$SOURCE_DIR/extracted"
CHECKSUMS="$SOURCE_DIR/XnView_MP-CHECKSUMS.txt"
TOOLS_DIR="$SOURCE_DIR/tools"
LINUXDEPLOY="$TOOLS_DIR/linuxdeploy-x86_64.AppImage"
QT_PLUGIN="$TOOLS_DIR/linuxdeploy-plugin-qt-x86_64.AppImage"
APPIMAGETOOL="$TOOLS_DIR/appimagetool-x86_64.AppImage"
RUNTIME_FILE="$TOOLS_DIR/runtime-x86_64"
INTERMEDIATE_APPIMAGE="$SOURCE_DIR/xnviewmp-linuxdeploy-intermediate.AppImage"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

download_tool() {
  local repo="$1" asset="$2" output="$3" metadata url digest

  metadata="$(curl -fsSL --retry 3 --retry-all-errors --connect-timeout 20 --max-time 120 \
    "${api_headers[@]}" "https://api.github.com/repos/$repo/releases/tags/continuous")"
  url="$(jq -er --arg name "$asset" '.assets[] | select(.name == $name) | .browser_download_url' <<< "$metadata")"
  digest="$(jq -er --arg name "$asset" '.assets[] | select(.name == $name) | .digest' <<< "$metadata")"
  [[ "$digest" =~ ^sha256:[[:xdigit:]]{64}$ ]] || die "official tool has no valid SHA-256: $repo/$asset"

  curl -fL --retry 3 --retry-all-errors --connect-timeout 20 --max-time 300 \
    "$url" -o "$output"
  printf '%s  %s\n' "${digest#sha256:}" "$output" | sha256sum -c -
}

[[ "$(uname -m)" == x86_64 ]] || die "only x86_64 is supported"

rm -rf "$SOURCE_DIR" "$APPDIR" "$DIST_DIR"
mkdir -p "$TOOLS_DIR" "$EXTRACT_DIR" "$DIST_DIR"

if command -v sudo >/dev/null 2>&1; then
  APT=(sudo apt-get)
else
  APT=(apt-get)
fi

"${APT[@]}" update
DEBIAN_FRONTEND=noninteractive "${APT[@]}" install -y --no-install-recommends \
  ca-certificates coreutils curl desktop-file-utils file findutils gawk grep jq tar xz-utils \
  qt5-qmake qtbase5-dev libqt5svg5 qttranslations5-l10n qt5-gtk-platformtheme qtwayland5 \
  fcitx5-frontend-qt5 libfcitx5-qt1 \
  libqt5multimedia5 libqt5multimedia5-plugins libqt5multimediagsttools5 \
  libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
  libpulse0 libpulse-mainloop-glib0 \
  libva2 libva-drm2 libva-x11-2 \
  libwayland-client0 libwayland-cursor0 libwayland-egl1 libwayland-server0 libudev1 \
  libxkbcommon-x11-0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
  libxcb-render-util0 libxcb-xinerama0 libxcb-xkb1

for command_name in curl desktop-file-validate find jq qmake readlink sed sha256sum tar; do
  command -v "$command_name" >/dev/null 2>&1 || die "required command missing: $command_name"
done

api_headers=(
  -H 'Accept: application/vnd.github+json'
  -H 'X-GitHub-Api-Version: 2022-11-28'
)
if [[ -n "${GH_TOKEN:-}" ]]; then
  api_headers+=( -H "Authorization: Bearer $GH_TOKEN" )
fi

# Resolve the newest official stable Linux x64 tarball from XnView's checksum list.
curl -fL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 20 --max-time 120 \
  https://download.xnview.com/versions/XnView_MP/XnView_MP-CHECKSUMS.txt \
  -o "$CHECKSUMS"
sed -i 's/\r$//' "$CHECKSUMS"

TGZ_NAME="$(
  awk '{print $2}' "$CHECKSUMS" |
    grep -E '^XnView_MP-[0-9]+(\.[0-9]+)+-linux-x64\.tgz$' |
    sort -V |
    tail -n 1
)"
[[ -n "$TGZ_NAME" ]] || die "no stable Linux x64 tarball found in the official checksum list"
VERSION="$(sed -nE 's/^XnView_MP-([0-9]+(\.[0-9]+)+)-linux-x64\.tgz$/\1/p' <<< "$TGZ_NAME")"
[[ -n "$VERSION" ]] || die "could not parse XnView MP version from $TGZ_NAME"
TGZ="$SOURCE_DIR/$TGZ_NAME"
TGZ_URL="https://download.xnview.com/versions/XnView_MP/$TGZ_NAME"
TGZ_SHA256="$(awk -v name="$TGZ_NAME" '$2 == name {print $1; exit}' "$CHECKSUMS")"
[[ "$TGZ_SHA256" =~ ^[[:xdigit:]]{64}$ ]] || die "official archive has no valid SHA-256"

printf '[XnView MP] official stable source: %s\n' "$TGZ_URL"
curl -fL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 20 --max-time 900 \
  "$TGZ_URL" -o "$TGZ"
printf '%s  %s\n' "$TGZ_SHA256" "$TGZ" | sha256sum -c -

tar -xzf "$TGZ" -C "$EXTRACT_DIR"
mapfile -d '' xnview_bins < <(find "$EXTRACT_DIR" -type f -name XnView -perm -u+x -print0)
[[ ${#xnview_bins[@]} -eq 1 ]] || die "expected one XnView executable, found ${#xnview_bins[@]}"
SOURCE_APP_DIR="$(dirname "${xnview_bins[0]}")"

mkdir -p "$APPDIR/opt/XnView" "$APPDIR/usr/bin" "$APPDIR/usr/share/applications"
cp -a "$SOURCE_APP_DIR/." "$APPDIR/opt/XnView/"
DESKTOP_FILE="$APPDIR/usr/share/applications/XnView.desktop"
ICON_FILE="$APPDIR/opt/XnView/xnview.png"
cp -a "$APPDIR/opt/XnView/XnView.desktop" "$DESKTOP_FILE"

[[ -x "$APPDIR/opt/XnView/XnView" ]] || die "XnView executable is missing"
[[ -e "$ICON_FILE" ]] || die "XnView icon is missing"
[[ -e "$APPDIR/opt/XnView/lib/libmdk.so" ]] || die "XnView media engine is missing"

sed -i \
  -e 's|^Icon=.*|Icon=xnview|' \
  -e 's|^Exec=/opt/XnView/xnview\.sh|Exec=xnview|' \
  -e '/^Value=/d' \
  -e '/^Encoding=/d' \
  -e 's/^Terminal=0$/Terminal=false/' \
  "$DESKTOP_FILE"
desktop-file-validate "$DESKTOP_FILE"

# Keep XnView's bundled Qt/media stack first; usr/lib contains only the compatible
# Jammy runtime families copied below.
cat > "$APPDIR/usr/bin/xnview" <<'EOF_LAUNCHER'
#!/usr/bin/env bash
set -Eeuo pipefail

HERE="$(dirname "$(readlink -f "$0")")"
ROOT="$(readlink -f "$HERE/../..")"

export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh

export PATH="$ROOT/opt/XnView:$ROOT/opt/XnView/lib:$ROOT/opt/XnView/Plugins:$ROOT/opt/XnView/qml:$ROOT/usr:$ROOT/usr/bin:$ROOT/usr/lib:$ROOT/usr/plugins:$ROOT/usr/share:$ROOT/usr/translations:${PATH:-}"
export LD_LIBRARY_PATH="$ROOT/opt/XnView:$ROOT/opt/XnView/lib:$ROOT/opt/XnView/Plugins:$ROOT/opt/XnView/qml:$ROOT/usr:$ROOT/usr/bin:$ROOT/usr/lib:$ROOT/usr/plugins:$ROOT/usr/share:$ROOT/usr/translations:${LD_LIBRARY_PATH:-}"
export QT_PLUGIN_PATH="$ROOT/opt/XnView:$ROOT/opt/XnView/lib:$ROOT/opt/XnView/Plugins:$ROOT/opt/XnView/qml:$ROOT/usr:$ROOT/usr/bin:$ROOT/usr/lib:$ROOT/usr/plugins:$ROOT/usr/share:$ROOT/usr/translations:${QT_PLUGIN_PATH:-}"
export QML_IMPORT_PATH="$ROOT/opt/XnView:$ROOT/opt/XnView/lib:$ROOT/opt/XnView/Plugins:$ROOT/opt/XnView/qml:$ROOT/usr:$ROOT/usr/bin:$ROOT/usr/lib:$ROOT/usr/plugins:$ROOT/usr/share:$ROOT/usr/translations:${QML_IMPORT_PATH:-}"
export QML2_IMPORT_PATH="$ROOT/opt/XnView:$ROOT/opt/XnView/lib:$ROOT/opt/XnView/Plugins:$ROOT/opt/XnView/qml:$ROOT/usr:$ROOT/usr/bin:$ROOT/usr/lib:$ROOT/usr/plugins:$ROOT/usr/share:$ROOT/usr/translations:${QML2_IMPORT_PATH:-}"
export XDG_DATA_DIRS="$ROOT/opt/XnView:$ROOT/opt/XnView/lib:$ROOT/opt/XnView/Plugins:$ROOT/opt/XnView/qml:$ROOT/usr:$ROOT/usr/bin:$ROOT/usr/lib:$ROOT/usr/plugins:$ROOT/usr/share:$ROOT/usr/translations:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

export QT_AUTO_SCREEN_SCALE_FACTOR=1
export QT_QPA_PLATFORM=xcb
export QT_FONT_DPI=96

exec "$ROOT/opt/XnView/XnView" "$@"
EOF_LAUNCHER
chmod +x "$APPDIR/usr/bin/xnview"

mkdir -p "$APPDIR/usr/lib" "$APPDIR/usr/translations"
if [[ -d /usr/share/qt5/translations ]]; then
  cp -a /usr/share/qt5/translations/. "$APPDIR/usr/translations/"
fi
cp -a "$APPDIR/opt/XnView/lib"/libQt5XcbQpa.so* "$APPDIR/usr/lib/"

copy_runtime_glob() {
  local pattern="$1"
  local files=()
  mapfile -t files < <(compgen -G "$pattern" || true)
  ((${#files[@]} > 0)) || die "required runtime library pattern not found: $pattern"
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
  libpulse-mainloop-glib.so.0 \
  libva.so.2 \
  libva-drm.so.2 \
  libva-x11.so.2 \
  libwayland-client.so.0 \
  libwayland-cursor.so.0 \
  libwayland-egl.so.1 \
  libwayland-server.so.0 \
  libudev.so.1; do
  copy_runtime_glob "/usr/lib/x86_64-linux-gnu/${runtime_lib}*"
done
copy_runtime_glob "/usr/lib/x86_64-linux-gnu/pulseaudio/libpulsecommon-*.so"

download_tool linuxdeploy/linuxdeploy linuxdeploy-x86_64.AppImage "$LINUXDEPLOY"
download_tool linuxdeploy/linuxdeploy-plugin-qt linuxdeploy-plugin-qt-x86_64.AppImage "$QT_PLUGIN"
download_tool AppImage/appimagetool appimagetool-x86_64.AppImage "$APPIMAGETOOL"
download_tool AppImage/type2-runtime runtime-x86_64 "$RUNTIME_FILE"
chmod +x "$LINUXDEPLOY" "$QT_PLUGIN" "$APPIMAGETOOL"
ln -sfn linuxdeploy-x86_64.AppImage "$TOOLS_DIR/linuxdeploy"

export ARCH=x86_64
export APPIMAGE_EXTRACT_AND_RUN=1
export PATH="$TOOLS_DIR:$PATH"
export QMAKE=/usr/bin/qmake
export NO_STRIP=1
export LDAI_NO_APPSTREAM=1
export LDAI_OUTPUT="$INTERMEDIATE_APPIMAGE"
export LDAI_RUNTIME_FILE="$RUNTIME_FILE"
export LD_LIBRARY_PATH="$APPDIR/opt/XnView:$APPDIR/opt/XnView/lib:$APPDIR/opt/XnView/Plugins:$APPDIR/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# First pass: let linuxdeploy create and normalize the AppDir and its standard links.
export ARCH=x86_64; linuxdeploy \
  --appdir AppDir \
  --desktop-file "$DESKTOP_FILE" \
  --icon-file "$ICON_FILE" \
  --output appimage

# Replace linuxdeploy's default entry with the real project AppRun. On the Qt pass,
# linuxdeploy wraps this file as AppRun.wrapped and installs its generated hook loader.
rm -f "$APPDIR/AppRun"
cat > "$APPDIR/AppRun" <<'EOF_APPRUN'
#!/usr/bin/env bash
set -Eeuo pipefail

HERE="$(dirname "$(readlink -f "${0}")")"
exec "$HERE/usr/bin/xnview" "$@"
EOF_APPRUN
chmod +x "$APPDIR/AppRun"

# XnView MP is Qt5, so QMAKE must point to the actual Qt5 qmake executable.
export QMAKE=/usr/bin/qmake
export ARCH=x86_64; linuxdeploy \
  --appdir AppDir \
  --desktop-file "$DESKTOP_FILE" \
  --icon-file "$ICON_FILE" \
  --plugin qt \
  --output appimage

# linuxdeploy's AppImage is an intermediate side effect. The release asset is always
# rebuilt from the same AppDir by official appimagetool with the official Type 2 runtime.
"$APPIMAGETOOL" -n "$APPDIR" "$OUTFILE" --runtime-file "$RUNTIME_FILE"
[[ -s "$OUTFILE" ]] || die "final AppImage was not created"
chmod +x "$OUTFILE"

printf '%s\n' "$VERSION" > "$DIST_DIR/version.txt"
sha256sum "$OUTFILE"
