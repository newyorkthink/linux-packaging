#!/usr/bin/env bash
# Patch the upstream official WinPodX AppImage without rebuilding or replacing its bundled FreeRDP.
set -Eeuo pipefail
shopt -s nullglob

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log() {
  printf '[WinPodX Release] %s\n' "$*"
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

[[ "$(uname -m)" == "x86_64" ]] || die "当前仅支持 x86_64。"
for command_name in appimagetool docker gh ldd python3 sha256sum; do
  command -v "$command_name" >/dev/null 2>&1 || die "构建环境缺少 $command_name。"
done

readonly UPSTREAM_REPO="kernalix7/winpodx"
readonly UPSTREAM_ASSET_NAME="winpodx-x86_64.AppImage"
readonly REQUESTED_TAG="${WINPODX_TAG:-}"
readonly WORK_DIR="$SCRIPT_DIR/.winpodx-release-build"
readonly DOWNLOAD_DIR="$WORK_DIR/download"
readonly EXTRACT_DIR="$WORK_DIR/extract"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly OUTFILE="$DIST_DIR/winpodx.AppImage"
readonly CHECKSUM_FILE="$DIST_DIR/winpodx.AppImage.sha256"
readonly VERSION_FILE="$DIST_DIR/winpodx-release-version.txt"
readonly QT_FIX_SCRIPT="$SCRIPT_DIR/fix_winpodx_qt_runtime.sh"

rm -rf "$WORK_DIR"
rm -f "$OUTFILE" "$CHECKSUM_FILE" "$VERSION_FILE"
mkdir -p "$DOWNLOAD_DIR" "$EXTRACT_DIR" "$DIST_DIR"

if [[ -n "$REQUESTED_TAG" ]]; then
  UPSTREAM_TAG="$REQUESTED_TAG"
else
  UPSTREAM_TAG="$(
    gh release view --repo "$UPSTREAM_REPO" --json tagName --jq .tagName
  )"
fi
[[ -n "$UPSTREAM_TAG" ]] || die "无法确定 WinPodX 上游最新正式版本。"
readonly UPSTREAM_TAG

log "下载上游官方 AppImage：$UPSTREAM_TAG / $UPSTREAM_ASSET_NAME"
gh release download "$UPSTREAM_TAG" \
  --repo "$UPSTREAM_REPO" \
  --pattern "$UPSTREAM_ASSET_NAME" \
  --dir "$DOWNLOAD_DIR"

mapfile -t upstream_appimages < <(
  find "$DOWNLOAD_DIR" -maxdepth 1 -type f \
    -name "$UPSTREAM_ASSET_NAME" -print | sort
)
[[ ${#upstream_appimages[@]} -eq 1 ]] || \
  die "预期下载 1 个官方 AppImage，实际得到 ${#upstream_appimages[@]} 个。"
readonly UPSTREAM_APPIMAGE="${upstream_appimages[0]}"
readonly UPSTREAM_SHA256="$(sha256sum "$UPSTREAM_APPIMAGE" | awk '{print $1}')"
chmod +x "$UPSTREAM_APPIMAGE"

log "解包官方 AppImage"
(
  cd "$EXTRACT_DIR"
  "$UPSTREAM_APPIMAGE" --appimage-extract >/dev/null
)
readonly APPDIR="$EXTRACT_DIR/squashfs-root"
readonly BUNDLED_PYTHON="$APPDIR/opt/python/bin/python3"
readonly BUNDLE_DIR="$APPDIR/opt/python/share/winpodx"
[[ -x "$APPDIR/AppRun" ]] || die "官方 AppImage 内缺少 AppRun。"
[[ -x "$BUNDLED_PYTHON" ]] || die "官方 AppImage 内缺少便携 Python。"
[[ -x "$APPDIR/usr/bin/xfreerdp" ]] || die "官方 AppImage 未内置 xfreerdp。"
[[ -x "$APPDIR/usr/bin/sdl-freerdp" ]] || die "官方 AppImage 未内置 sdl-freerdp。"
for marker in scripts config data; do
  [[ -d "$BUNDLE_DIR/$marker" ]] || die "官方 AppImage 缺少资源目录：$marker"
done

# Keep a byte-level manifest so none of the official FreeRDP binaries or core
# libraries can be silently replaced by the patching steps below.
readonly FREERDP_MANIFEST="$WORK_DIR/official-freerdp.sha256"
(
  cd "$APPDIR"
  find usr/bin usr/lib -maxdepth 1 -type f \( \
    -name '*freerdp*' -o \
    -name 'libfreerdp*.so*' -o \
    -name 'libwinpr*.so*' \
  \) -print0 | sort -z | xargs -0 sha256sum
) > "$FREERDP_MANIFEST"
grep -F 'usr/bin/xfreerdp' "$FREERDP_MANIFEST" >/dev/null || \
  die "无法记录官方 xfreerdp 校验值。"
grep -F 'usr/lib/libfreerdp3.so.3' "$FREERDP_MANIFEST" >/dev/null || \
  die "无法记录官方 libfreerdp 校验值。"
grep -F 'usr/lib/libwinpr3.so.3' "$FREERDP_MANIFEST" >/dev/null || \
  die "无法记录官方 libwinpr 校验值。"

mapfile -t rdp_sources < <(
  find "$APPDIR/opt/python/lib" -path '*/winpodx/core/rdp.py' -type f -print
)
[[ ${#rdp_sources[@]} -eq 1 ]] || die "无法唯一定位 winpodx/core/rdp.py。"
readonly RDP_SOURCE="${rdp_sources[0]}"

# Preserve the previously verified audio patch exactly: use Pulse when the
# host exposes a Pulse/PipeWire-Pulse endpoint, otherwise fall back to ALSA.
grep -F '"/sound:sys:alsa",' "$RDP_SOURCE" >/dev/null || \
  die "上游音频参数已经变化，需要重新检查补丁。"

log "保留 Pulse/PipeWire-Pulse 音频，并提供 ALSA 回退"
python3 - "$RDP_SOURCE" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
old = '        "/sound:sys:alsa",\n'
new = '''        "/sound:sys:"
        + (
            "pulse"
            if (
                os.environ.get("PULSE_SERVER")
                or (
                    Path(
                        os.environ.get(
                            "XDG_RUNTIME_DIR",
                            f"/run/user/{os.getuid()}",
                        )
                    )
                    / "pulse/native"
                ).exists()
            )
            else "alsa"
        ),
'''
if text.count(old) != 1:
    raise SystemExit("音频参数替换目标不是唯一的一处")
path.write_text(text.replace(old, new), encoding="utf-8")
PY
"$BUNDLED_PYTHON" -m py_compile "$RDP_SOURCE"

[[ -f "$QT_FIX_SCRIPT" ]] || die "找不到 Qt 修复脚本：$QT_FIX_SCRIPT"
chmod +x "$QT_FIX_SCRIPT"
"$QT_FIX_SCRIPT" "$APPDIR"

readonly QT_ROOT="$(find "$APPDIR/opt/python/lib" \
  -path '*/site-packages/PySide6/Qt' -type d -print -quit)"
[[ -n "$QT_ROOT" ]] || die "官方 AppImage 内缺少 PySide6 Qt 运行时。"

log "让 AppRun 使用 Qt 私有 XCB 库和固定的 WinPodX 资源目录"
python3 - "$APPDIR/AppRun" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
appdir_line = 'APPDIR="$(dirname "$(readlink -f "$0")")"\n'
ld_line = 'export LD_LIBRARY_PATH="$APPDIR/usr/lib:$APPDIR/opt/python/lib:$LD_LIBRARY_PATH"\n'

if text.count(appdir_line) != 1:
    raise SystemExit("AppRun 的 APPDIR 定义不是唯一的一处")
if text.count(ld_line) != 1:
    raise SystemExit("AppRun 的 LD_LIBRARY_PATH 定义已变化")

appdir_patch = appdir_line + (
    'export APPDIR\n'
    'export WINPODX_BUNDLE_DIR="$APPDIR/opt/python/share/winpodx"\n'
    'QT_ROOT="$APPDIR/opt/python/lib/python3.11/site-packages/PySide6/Qt"\n'
    'export QT_PLUGIN_PATH="$QT_ROOT/plugins"\n'
    'export QT_QPA_PLATFORM_PLUGIN_PATH="$QT_ROOT/plugins/platforms"\n'
)
ld_patch = (
    'export LD_LIBRARY_PATH="$QT_ROOT/lib:$APPDIR/usr/lib:'
    '$APPDIR/opt/python/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"\n'
)
text = text.replace(appdir_line, appdir_patch).replace(ld_line, ld_patch)
path.write_text(text, encoding="utf-8")
PY
chmod +x "$APPDIR/AppRun"
sh -n "$APPDIR/AppRun"

# Keep the exact relocatable wrapper used by the earlier Ubuntu 24 build.
# The upstream pip launcher has a build-time /home/runner shebang; GUI tray
# auto-spawn finds `winpodx` through PATH, so usr/bin must provide this valid
# entry before opt/python/bin.
log "创建 WinPodX 托盘子进程使用的可重定位入口"
cat > "$APPDIR/usr/bin/winpodx" <<'WINPODX_WRAPPER'
#!/bin/sh
APPDIR="${APPDIR:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
exec "$APPDIR/opt/python/bin/python3" -m winpodx "$@"
WINPODX_WRAPPER
chmod +x "$APPDIR/usr/bin/winpodx"
sh -n "$APPDIR/usr/bin/winpodx"

readonly ICON_SOURCE="$BUNDLE_DIR/data/winpodx-icon.svg"
readonly DESKTOP_SOURCE="$BUNDLE_DIR/data/winpodx.desktop"
[[ -f "$ICON_SOURCE" && ! -L "$ICON_SOURCE" ]] || \
  die "官方 WinPodX SVG 图标缺失或不是普通文件。"
[[ -f "$DESKTOP_SOURCE" && ! -L "$DESKTOP_SOURCE" ]] || \
  die "官方 WinPodX desktop 文件缺失或不是普通文件。"
[[ -f "$APPDIR/winpodx.png" ]] || die "官方 AppImage 根图标缺失。"
[[ -f "$APPDIR/winpodx.desktop" ]] || die "官方 AppImage 根 desktop 文件缺失。"

# Keep the upstream AppImage root icon and also provide the standard scalable
# theme location. WINPODX_BUNDLE_DIR above makes runtime installation into the
# user's hicolor theme deterministic, which fixes i3bar/taskbar lookup.
install -Dm644 "$ICON_SOURCE" \
  "$APPDIR/usr/share/icons/hicolor/scalable/apps/winpodx.svg"
install -Dm644 "$DESKTOP_SOURCE" \
  "$APPDIR/usr/share/applications/winpodx.desktop"

log "验证官方 FreeRDP 未被替换、音频后端、Qt 和图标"
(
  cd "$APPDIR"
  sha256sum -c "$FREERDP_MANIFEST" >/dev/null
)

LD_LIBRARY_PATH="$APPDIR/usr/lib:$APPDIR/opt/python/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  "$APPDIR/usr/bin/xfreerdp" /buildconfig \
  > "$WORK_DIR/freerdp-buildconfig.txt" 2>&1
grep -F 'WITH_PULSE=ON' "$WORK_DIR/freerdp-buildconfig.txt" >/dev/null || \
  die "官方内置 FreeRDP 未启用 PulseAudio。"
grep -F 'WITH_ALSA=ON' "$WORK_DIR/freerdp-buildconfig.txt" >/dev/null || \
  die "官方内置 FreeRDP 未启用 ALSA。"
grep -F '"pulse"' "$RDP_SOURCE" >/dev/null || die "Pulse 音频补丁未写入。"

for private_library in \
  libxcb-cursor.so.0 \
  libxcb-icccm.so.4 \
  libxcb-image.so.0 \
  libxcb-keysyms.so.1 \
  libxcb-render-util.so.0 \
  libxcb-util.so.1 \
  libxcb-xkb.so.1 \
  libxkbcommon-x11.so.0; do
  [[ -f "$QT_ROOT/lib/$private_library" ]] || \
    die "Qt 私有目录缺少 $private_library。"
  [[ ! -e "$APPDIR/usr/lib/$private_library" ]] || \
    die "FreeRDP 公共运行库目录不应包含 $private_library。"
done

qt_dependencies="$(
  LD_LIBRARY_PATH="$QT_ROOT/lib:$APPDIR/usr/lib:$APPDIR/opt/python/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    ldd "$QT_ROOT/plugins/platforms/libqxcb.so"
)"
if grep -F 'not found' <<<"$qt_dependencies" >/dev/null; then
  printf '%s\n' "$qt_dependencies" >&2
  die "Qt xcb 平台插件仍有缺失依赖。"
fi

freerdp_dependencies="$(
  LD_LIBRARY_PATH="$QT_ROOT/lib:$APPDIR/usr/lib:$APPDIR/opt/python/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    ldd "$APPDIR/usr/bin/xfreerdp"
)"
for official_library in libfreerdp-client3.so.3 libfreerdp3.so.3 libwinpr3.so.3; do
  grep -F "$official_library => $APPDIR/usr/lib/$official_library" \
    <<<"$freerdp_dependencies" >/dev/null || \
    die "xfreerdp 未加载官方内置 $official_library。"
done
if grep -F 'not found' <<<"$freerdp_dependencies" >/dev/null; then
  printf '%s\n' "$freerdp_dependencies" >&2
  die "官方内置 xfreerdp 仍有缺失依赖。"
fi

WINPODX_BUNDLE_DIR="$BUNDLE_DIR" \
PYTHONPATH="$APPDIR/opt/python/lib/python3.11/site-packages" \
LD_LIBRARY_PATH="$APPDIR/usr/lib:$APPDIR/opt/python/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  "$BUNDLED_PYTHON" - <<'PY'
from winpodx.desktop.icons import bundled_data_path

icon = bundled_data_path("winpodx-icon.svg")
if icon is None or not icon.is_file() or icon.is_symlink():
    raise SystemExit("WinPodX 图标资源无法解析")
print(icon)
PY

resolved_wrapper="$(
  PATH="$APPDIR/usr/bin:$APPDIR/opt/python/bin:$PATH" \
    "$BUNDLED_PYTHON" -c 'import shutil; print(shutil.which("winpodx") or "")'
)"
[[ "$resolved_wrapper" == "$APPDIR/usr/bin/winpodx" ]] || \
  die "托盘子进程未优先找到可重定位 winpodx 入口：$resolved_wrapper"

wrapper_version="$(
  WINPODX_BUNDLE_DIR="$BUNDLE_DIR" \
  PYTHONPATH="$APPDIR/opt/python/lib/python3.11/site-packages" \
  LD_LIBRARY_PATH="$QT_ROOT/lib:$APPDIR/usr/lib:$APPDIR/opt/python/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    "$APPDIR/usr/bin/winpodx" --version
)"
grep -F "winpodx ${UPSTREAM_TAG#v}" <<<"$wrapper_version" >/dev/null || \
  die "托盘子进程入口无法启动：$wrapper_version"

version_output="$("$APPDIR/AppRun" --version)"
readonly VERSION="${UPSTREAM_TAG#v}"
grep -F "winpodx $VERSION" <<<"$version_output" >/dev/null || \
  die "WinPodX 版本检查失败：$version_output"

cat > "$VERSION_FILE" <<EOF_VERSION
tag=$UPSTREAM_TAG
version=$VERSION
source=official-appimage
asset=$UPSTREAM_ASSET_NAME
upstream_sha256=$UPSTREAM_SHA256
freerdp=bundled-upstream-official
patches=qt-xcb,audio-pulse-fallback,i3bar-icon
EOF_VERSION

log "生成最终 winpodx.AppImage"
ARCH=x86_64 appimagetool "$APPDIR" "$OUTFILE" >/dev/null
chmod +x "$OUTFILE"
"$OUTFILE" --appimage-version >/dev/null
(
  cd "$DIST_DIR"
  sha256sum winpodx.AppImage > winpodx.AppImage.sha256
)

log "已生成：dist/winpodx.AppImage（$UPSTREAM_TAG / 官方 AppImage）"
