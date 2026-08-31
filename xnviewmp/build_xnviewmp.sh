#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# The old known-good XnView AppImage carries Ubuntu 22.04-era media runtime
# (PulseAudio 15.99 / GStreamer 1.20 family). Build this package in Jammy on CI
# instead of mixing XnView's bundled MDK/Qt with Ubuntu 24.04 media libraries.
if [[ "${GITHUB_ACTIONS:-}" == "true" && "${XNVIEWMP_JAMMY_INNER:-0}" != "1" ]]; then
  command -v docker >/dev/null 2>&1 || {
    echo "ERROR: docker is required for the XnView MP Jammy build" >&2
    exit 1
  }
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  exec docker run --rm \
    -e XNVIEWMP_JAMMY_INNER=1 \
    -e CI=1 \
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
TGZ="$SOURCE_DIR/XnView_MP-1.11.5-linux-x64.tgz"
LINUXDEPLOY="$SOURCE_DIR/linuxdeploy-x86_64.AppImage"
QT_PLUGIN="$SOURCE_DIR/linuxdeploy-plugin-qt-x86_64.AppImage"
DESKTOP_FILE="$APPDIR/usr/share/applications/XnView.desktop"
ICON_FILE="$APPDIR/opt/XnView/xnview.png"

STABLE_VERSION="1.11.5"
TGZ_URL="https://download.xnview.com/old_versions/XnView_MP/XnView_MP-${STABLE_VERSION}-linux-x64.tgz"
TGZ_SHA256="736c272f3007a59d9247fb6786f7a4d34d442386c1ceb262fae090261e96a9b7"
# These are from the user's old working AppImage. The build must use the exact same
# XnView executable and media engine, not merely another package with the same version.
XNVIEW_SHA256="c6d2bcabfc45d6dfdf154c4a4215384826c55da6ca31195def66798f9b1bf432"
MDK_SHA256="84f36b38514cb4abfeb0383ac419aff08ac09c627b010d53e84d6d2878406fcc"
FFMPEG_SHA256="3248cf00156ddfcab9d2c0803b933a2218fffbcf0cb792dadddbb317d7517edd"

rm -rf "$SOURCE_DIR" "$APPDIR" "$DIST_DIR"
mkdir -p "$SOURCE_DIR" "$EXTRACT_DIR" "$DIST_DIR"

if command -v sudo >/dev/null 2>&1; then
  APT=(sudo apt-get)
else
  APT=(apt-get)
fi

"${APT[@]}" update
DEBIAN_FRONTEND=noninteractive "${APT[@]}" install -y --no-install-recommends \
  ca-certificates coreutils curl desktop-file-utils ffmpeg file findutils gawk grep tar xz-utils \
  xvfb xauth \
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

for command_name in curl desktop-file-validate ffmpeg file find ldd qmake readlink sha256sum tar timeout xvfb-run; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "ERROR: required command missing: $command_name" >&2
    exit 1
  }
done

printf '[XnView MP] stable source: %s\n' "$TGZ_URL"
curl -fL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 20 \
  "$TGZ_URL" -o "$TGZ"
echo "$TGZ_SHA256  $TGZ" | sha256sum -c -

tar -xzf "$TGZ" -C "$EXTRACT_DIR"
mapfile -d '' xnview_bins < <(find "$EXTRACT_DIR" -type f -name XnView -perm -u+x -print0)
if [[ ${#xnview_bins[@]} -ne 1 ]]; then
  echo "ERROR: expected exactly one XnView executable in stable TGZ, found ${#xnview_bins[@]}" >&2
  exit 1
fi
SOURCE_APP_DIR="$(dirname "${xnview_bins[0]}")"
mkdir -p "$APPDIR/opt/XnView" "$APPDIR/usr/bin" "$APPDIR/usr/share/applications"
cp -a "$SOURCE_APP_DIR/." "$APPDIR/opt/XnView/"
cp -a "$APPDIR/opt/XnView/XnView.desktop" "$DESKTOP_FILE"

test -x "$APPDIR/opt/XnView/XnView"
test -e "$ICON_FILE"
test -e "$APPDIR/opt/XnView/lib/libmdk.so"
test -e "$APPDIR/opt/XnView/lib/libffmpeg.so.8"
test -e "$APPDIR/opt/XnView/language/xnview_zh_CN.qm"

ACTUAL_XNVIEW_SHA256="$(sha256sum "$APPDIR/opt/XnView/XnView" | awk '{print $1}')"
ACTUAL_MDK_SHA256="$(sha256sum "$APPDIR/opt/XnView/lib/libmdk.so" | awk '{print $1}')"
ACTUAL_FFMPEG_SHA256="$(sha256sum "$APPDIR/opt/XnView/lib/libffmpeg.so.8" | awk '{print $1}')"
printf '[XnView MP] XnView SHA-256: %s\n' "$ACTUAL_XNVIEW_SHA256"
printf '[XnView MP] libmdk SHA-256: %s\n' "$ACTUAL_MDK_SHA256"
printf '[XnView MP] libffmpeg SHA-256: %s\n' "$ACTUAL_FFMPEG_SHA256"
[[ "$ACTUAL_XNVIEW_SHA256" == "$XNVIEW_SHA256" ]] || { echo 'ERROR: XnView executable differs from old working package' >&2; exit 1; }
[[ "$ACTUAL_MDK_SHA256" == "$MDK_SHA256" ]] || { echo 'ERROR: libmdk differs from old working package' >&2; exit 1; }
[[ "$ACTUAL_FFMPEG_SHA256" == "$FFMPEG_SHA256" ]] || { echo 'ERROR: libffmpeg differs from old working package' >&2; exit 1; }

# Normalize XnView's legacy desktop entry for modern desktop-file-utils/linuxdeploy.
sed -i \
  -e 's|^Icon=.*|Icon=xnview|' \
  -e '/^Value=/d' \
  -e '/^Encoding=/d' \
  -e 's/^Terminal=0$/Terminal=false/' \
  "$DESKTOP_FILE"
desktop-file-validate "$DESKTOP_FILE"

# Reproduce the old working AppImage launch environment. /opt/XnView stays first so
# XnView always uses its own Qt/MDK/FFmpeg; usr/lib supplies only the packaged runtime.
cat > "$APPDIR/usr/bin/xnview" <<'EOF_APPRUN'
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
EOF_APPRUN
chmod +x "$APPDIR/usr/bin/xnview"

mkdir -p "$APPDIR/usr/lib" "$APPDIR/usr/translations"
if [[ -d /usr/share/qt5/translations ]]; then
  cp -a /usr/share/qt5/translations/. "$APPDIR/usr/translations/"
fi

cp -a "$APPDIR/opt/XnView/lib"/libQt5XcbQpa.so* "$APPDIR/usr/lib/"
test -e "$APPDIR/usr/lib/libQt5XcbQpa.so.5"

copy_runtime_glob() {
  local pattern="$1"
  local files=()
  mapfile -t files < <(compgen -G "$pattern" || true)
  if ((${#files[@]} == 0)); then
    echo "ERROR: required runtime library pattern not found: $pattern" >&2
    exit 1
  fi
  cp -a "${files[@]}" "$APPDIR/usr/lib/"
}

# Match the media/desktop runtime families present in the old working AppImage.
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

curl -fL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 20 \
  https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage \
  -o "$LINUXDEPLOY"
curl -fL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 20 \
  https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage \
  -o "$QT_PLUGIN"
chmod +x "$LINUXDEPLOY" "$QT_PLUGIN"

export ARCH=x86_64
export APPIMAGE_EXTRACT_AND_RUN=1
export LDAI_OUTPUT="$OUTFILE"
export LD_LIBRARY_PATH="$APPDIR/opt/XnView:$APPDIR/opt/XnView/lib:$APPDIR/opt/XnView/Plugins:$APPDIR/usr/lib:${LD_LIBRARY_PATH:-}"

"$LINUXDEPLOY" \
  --appdir "$APPDIR" \
  --desktop-file "$DESKTOP_FILE" \
  --icon-file "$ICON_FILE" \
  --plugin qt \
  --output appimage

test -s "$OUTFILE"
chmod +x "$OUTFILE"

VERIFY_DIR="$SOURCE_DIR/verify-appimage"
rm -rf "$VERIFY_DIR"
mkdir -p "$VERIFY_DIR"
(
  cd "$VERIFY_DIR"
  "$OUTFILE" --appimage-extract >/dev/null
)
VERIFY_ROOT="$VERIFY_DIR/squashfs-root"
test -x "$VERIFY_ROOT/opt/XnView/XnView"
test -e "$VERIFY_ROOT/opt/XnView/lib/libmdk.so"
test -e "$VERIFY_ROOT/opt/XnView/lib/libffmpeg.so.8"
test -e "$VERIFY_ROOT/usr/lib/libgstreamer-1.0.so.0"
test -e "$VERIFY_ROOT/usr/lib/libgstapp-1.0.so.0"
test -e "$VERIFY_ROOT/usr/lib/libpulse.so.0"
test -e "$VERIFY_ROOT/usr/lib/libpulse-mainloop-glib.so.0"
test -e "$VERIFY_ROOT/usr/lib/libva.so.2"
test -e "$VERIFY_ROOT/usr/lib/libva-drm.so.2"
test -e "$VERIFY_ROOT/usr/lib/libva-x11.so.2"
test -e "$VERIFY_ROOT/usr/lib/libwayland-client.so.0"
test -e "$VERIFY_ROOT/usr/lib/libudev.so.1"
compgen -G "$VERIFY_ROOT/usr/lib/libpulsecommon-*.so" >/dev/null
test -e "$VERIFY_ROOT/usr/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so"
grep -Fq '$ROOT/usr/lib' "$VERIFY_ROOT/usr/bin/xnview"
grep -Fq '$ROOT/usr/plugins' "$VERIFY_ROOT/usr/bin/xnview"

# Final image must still contain the exact old-working media core after linuxdeploy.
[[ "$(sha256sum "$VERIFY_ROOT/opt/XnView/XnView" | awk '{print $1}')" == "$XNVIEW_SHA256" ]]
[[ "$(sha256sum "$VERIFY_ROOT/opt/XnView/lib/libmdk.so" | awk '{print $1}')" == "$MDK_SHA256" ]]
[[ "$(sha256sum "$VERIFY_ROOT/opt/XnView/lib/libffmpeg.so.8" | awk '{print $1}')" == "$FFMPEG_SHA256" ]]

LDD_OUTPUT="$(LD_LIBRARY_PATH="$VERIFY_ROOT/opt/XnView:$VERIFY_ROOT/opt/XnView/lib:$VERIFY_ROOT/opt/XnView/Plugins:$VERIFY_ROOT/usr/lib" ldd "$VERIFY_ROOT/opt/XnView/XnView")"
printf '%s\n' "$LDD_OUTPUT"
if grep -Fq 'not found' <<<"$LDD_OUTPUT"; then
  echo "ERROR: extracted XnView AppImage still has unresolved shared libraries" >&2
  exit 1
fi

run_media_smoke() {
  local name="$1"
  local media_file="$2"
  local log_file="$SOURCE_DIR/${name}-smoke.log"
  local home_dir="$SOURCE_DIR/${name}-home"
  local runtime_dir="$SOURCE_DIR/${name}-runtime"
  local rc

  mkdir -p "$home_dir" "$runtime_dir"
  chmod 700 "$runtime_dir"
  set +e
  APPIMAGE_EXTRACT_AND_RUN=1 timeout 15s xvfb-run -a env \
    HOME="$home_dir" XDG_RUNTIME_DIR="$runtime_dir" \
    "$OUTFILE" "$media_file" >"$log_file" 2>&1
  rc=$?
  set -e

  cat "$log_file"
  printf '[XnView MP] %s smoke exit code: %s\n' "$name" "$rc"
  if grep -Eqi 'segmentation fault|core dumped|Crash report dumped|KCrashReporter|Aborted|error while loading shared libraries|Could not load the Qt platform plugin|no Qt platform plugin could be initialized|failed to load libva\.so\.[12]' "$log_file"; then
    echo "ERROR: XnView MP $name smoke test detected a crash or missing media runtime" >&2
    exit 1
  fi
  if [[ "$rc" -ne 0 && "$rc" -ne 124 ]]; then
    echo "ERROR: XnView MP $name smoke test exited unexpectedly: $rc" >&2
    exit 1
  fi
}

# First exercise a plain startup.
STARTUP_LOG="$SOURCE_DIR/startup-smoke.log"
STARTUP_HOME="$SOURCE_DIR/startup-home"
STARTUP_RUNTIME="$SOURCE_DIR/startup-runtime"
mkdir -p "$STARTUP_HOME" "$STARTUP_RUNTIME"
chmod 700 "$STARTUP_RUNTIME"
set +e
APPIMAGE_EXTRACT_AND_RUN=1 timeout 15s xvfb-run -a env \
  HOME="$STARTUP_HOME" XDG_RUNTIME_DIR="$STARTUP_RUNTIME" \
  "$OUTFILE" >"$STARTUP_LOG" 2>&1
STARTUP_STATUS=$?
set -e
cat "$STARTUP_LOG"
if [[ "$STARTUP_STATUS" -ne 0 && "$STARTUP_STATUS" -ne 124 ]]; then
  echo "ERROR: XnView MP startup smoke test exited unexpectedly: $STARTUP_STATUS" >&2
  exit 1
fi
if grep -Eqi 'segmentation fault|core dumped|Crash report dumped|KCrashReporter|Aborted' "$STARTUP_LOG"; then
  echo "ERROR: XnView MP startup smoke test detected a crash" >&2
  exit 1
fi

# Exercise common phone/social-video formats. 1080p H.264 is included because the
# real failure was reproduced while selecting a 1080p MP4 in XnView's media browser.
H264_SMOKE="$SOURCE_DIR/h264-smoke.mp4"
HEVC_SMOKE="$SOURCE_DIR/hevc-smoke.mp4"
ffmpeg -hide_banner -loglevel error -y \
  -f lavfi -i 'testsrc2=size=1920x1080:rate=30' \
  -f lavfi -i 'sine=frequency=1000:sample_rate=48000' \
  -t 3 -c:v libx264 -preset ultrafast -profile:v high -level 4.1 -pix_fmt yuv420p \
  -c:a aac -b:a 128k -shortest -movflags +faststart "$H264_SMOKE"
ffmpeg -hide_banner -loglevel error -y \
  -f lavfi -i 'testsrc2=size=360x640:rate=30' \
  -t 3 -c:v libx265 -preset ultrafast -pix_fmt yuv420p \
  -x265-params 'log-level=error' -movflags +faststart "$HEVC_SMOKE"

run_media_smoke h264 "$H264_SMOKE"
run_media_smoke hevc "$HEVC_SMOKE"

sha256sum "$OUTFILE"
