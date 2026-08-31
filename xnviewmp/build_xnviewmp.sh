#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
cd "$SCRIPT_DIR"

log() {
  printf '[XnView MP] %s\n' "$*"
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

HOST_ARCH="$(uname -m)"
readonly HOST_ARCH
[[ "$HOST_ARCH" == x86_64 ]] || die "当前仅支持 x86_64。"
command -v yay >/dev/null 2>&1 || die "构建环境缺少命令：yay"

readonly BASE_URL="https://download.xnview.com/versions/XnView_MP"
readonly CHECKSUMS_URL="$BASE_URL/XnView_MP-CHECKSUMS.txt"
readonly SOURCE_DIR="$SCRIPT_DIR/source"
readonly CHECKSUMS_FILE="$SOURCE_DIR/XnView_MP-CHECKSUMS.txt"
readonly OFFICIAL_APPIMAGE="$SOURCE_DIR/XnView_MP-official.AppImage"
readonly APPDIR="$SCRIPT_DIR/AppDir"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly OUTFILE="$DIST_DIR/xnviewmp.AppImage"
readonly VERIFY_DIR="$SCRIPT_DIR/verify"
readonly VERIFY_ROOT="$VERIFY_DIR/squashfs-root"
readonly SMOKE_HOME="$SCRIPT_DIR/smoke-home"
readonly SMOKE_CONFIG="$SCRIPT_DIR/smoke-config"
readonly SMOKE_CACHE="$SCRIPT_DIR/smoke-cache"
readonly SMOKE_RUNTIME="$SCRIPT_DIR/smoke-runtime"
readonly SMOKE_LOG="$SCRIPT_DIR/xnviewmp-smoke.log"
readonly APPIMAGETOOL="$SOURCE_DIR/appimagetool-x86_64.AppImage"
readonly APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
readonly APPIMAGETOOL_SHA256="a6d71e2b6cd66f8e8d16c37ad164658985e0cf5fcaa950c90a482890cb9d13e0"

# XnView 官方 AppImage 1.11.x 在部分精简系统缺少 libpulse.so.0。
# 只补 Debian 12 的 PulseAudio client library，不再把构建机的 Qt/GLib/glibc 运行库塞进 AppImage。
readonly LIBPULSE_DEB="$SOURCE_DIR/libpulse0_16.1+dfsg1-2+b1_amd64.deb"
readonly LIBPULSE_URL="https://deb.debian.org/debian/pool/main/p/pulseaudio/libpulse0_16.1+dfsg1-2+b1_amd64.deb"
readonly LIBPULSE_SHA256="7b2c5403cb726312219aad678becc6d6adcee1d8694fdffce0b6ec15ae010831"
readonly LIBPULSE_EXTRACT="$SOURCE_DIR/libpulse-extract"
readonly LIBPULSE_GLIB_DEB="$SOURCE_DIR/libpulse-mainloop-glib0_16.1+dfsg1-2+b1_amd64.deb"
readonly LIBPULSE_GLIB_URL="https://deb.debian.org/debian/pool/main/p/pulseaudio/libpulse-mainloop-glib0_16.1+dfsg1-2+b1_amd64.deb"
readonly LIBPULSE_GLIB_SHA256="adb9309bc4418b7c67c6bf97fa22bc9efc26c0659e21e1c79abad66fc11b76b1"
readonly LIBPULSE_GLIB_EXTRACT="$SOURCE_DIR/libpulse-glib-extract"

rm -rf \
  "$SOURCE_DIR" \
  "$APPDIR" \
  "$DIST_DIR" \
  "$VERIFY_DIR" \
  "$SMOKE_HOME" \
  "$SMOKE_CONFIG" \
  "$SMOKE_CACHE" \
  "$SMOKE_RUNTIME"
rm -f "$SMOKE_LOG"
mkdir -p "$SOURCE_DIR" "$DIST_DIR" "$VERIFY_DIR"

# 只安装构建/审计工具。运行库来自 XnView 官方 AppImage；额外仅引入固定版本 libpulse0。
yay -S --noconfirm --needed \
  binutils coreutils curl desktop-file-utils file findutils gawk grep python tar xz \
  xorg-server-xvfb xorg-xauth

for command_name in \
  ar awk cat chmod cp curl desktop-file-validate file find grep mkdir mv python3 readelf \
  sed sha256sum strings tar timeout xvfb-run; do
  command -v "$command_name" >/dev/null 2>&1 || die "构建环境缺少命令：$command_name"
done

log "读取 XnView MP 官方校验文件并解析最新稳定 x86_64 AppImage"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  "$CHECKSUMS_URL" \
  -o "$CHECKSUMS_FILE"
[[ -s "$CHECKSUMS_FILE" ]] || die "官方校验文件为空。"

mapfile -t appimage_meta < <(
  python3 - "$CHECKSUMS_FILE" <<'PY'
import re
import sys

pattern = re.compile(
    r"^(?P<sha>[0-9a-f]{64})  "
    r"(?P<name>XnView_MP-(?P<version>[0-9]+(?:\.[0-9]+)+)\.glibc[0-9.]+-x86_64\.AppImage)$"
)

matches = []
with open(sys.argv[1], "r", encoding="utf-8") as fh:
    for raw in fh:
        match = pattern.fullmatch(raw.rstrip("\n"))
        if not match:
            continue
        version = match.group("version")
        matches.append((tuple(int(part) for part in version.split(".")), version, match.group("name"), match.group("sha")))

if not matches:
    raise SystemExit("官方校验文件中没有找到稳定的 x86_64 AppImage。")

_, version, name, sha256 = max(matches, key=lambda item: item[0])
print(version)
print(name)
print(sha256)
PY
)
[[ ${#appimage_meta[@]} -eq 3 ]] || die "无法完整解析官方 AppImage 元数据。"
readonly VERSION="${appimage_meta[0]}"
readonly APPIMAGE_NAME="${appimage_meta[1]}"
readonly EXPECTED_SHA256="${appimage_meta[2]}"
readonly APPIMAGE_URL="$BASE_URL/$APPIMAGE_NAME"

[[ "$VERSION" =~ ^[0-9]+(\.[0-9]+)+$ ]] || die "解析出的版本号异常：$VERSION"
[[ "$EXPECTED_SHA256" =~ ^[0-9a-f]{64}$ ]] || die "解析出的 SHA-256 异常。"
printf 'XnView MP version: %s\nXnView MP source: %s\n' "$VERSION" "$APPIMAGE_URL"

log "下载并校验官方 AppImage"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  "$APPIMAGE_URL" \
  -o "$OFFICIAL_APPIMAGE"
[[ -s "$OFFICIAL_APPIMAGE" ]] || die "官方下载文件为空。"
chmod 0755 "$OFFICIAL_APPIMAGE"
file "$OFFICIAL_APPIMAGE" | grep -q 'ELF 64-bit' || die "官方下载文件不是 64 位 AppImage ELF。"
[[ "$(sha256sum "$OFFICIAL_APPIMAGE" | awk '{print $1}')" == "$EXPECTED_SHA256" ]] || \
  die "官方 AppImage SHA-256 校验失败。"

log "提取官方 AppImage，保留官方应用文件和依赖布局"
(
  cd "$SOURCE_DIR"
  "$OFFICIAL_APPIMAGE" --appimage-extract >/dev/null
)
[[ -d "$SOURCE_DIR/squashfs-root" ]] || die "官方 AppImage 提取失败。"
mv "$SOURCE_DIR/squashfs-root" "$APPDIR"
[[ -x "$APPDIR/opt/XnView/XnView" ]] || die "官方 AppImage 缺少 opt/XnView/XnView。"
[[ -f "$APPDIR/opt/XnView/language/xnview_zh_CN.qm" ]] || die "官方包缺少简体中文翻译文件。"
[[ -f "$APPDIR/opt/XnView/language/xnview_zh_TW.qm" ]] || die "官方包缺少繁体中文翻译文件。"

log "补入 Debian 12 libpulse0，避免依赖目标系统安装 PulseAudio client library"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  "$LIBPULSE_URL" \
  -o "$LIBPULSE_DEB"
[[ "$(sha256sum "$LIBPULSE_DEB" | awk '{print $1}')" == "$LIBPULSE_SHA256" ]] || \
  die "libpulse0 SHA-256 校验失败。"
mkdir -p "$LIBPULSE_EXTRACT"
(
  cd "$LIBPULSE_EXTRACT"
  ar x "$LIBPULSE_DEB"
)
data_archive="$(find "$LIBPULSE_EXTRACT" -maxdepth 1 -type f -name 'data.tar.*' -print -quit)"
[[ -n "$data_archive" ]] || die "libpulse0 deb 中没有 data.tar.*。"
tar -xf "$data_archive" -C "$APPDIR"
[[ -e "$APPDIR/usr/lib/x86_64-linux-gnu/libpulse.so.0" ]] || die "补包后仍缺少 libpulse.so.0。"
[[ -f "$APPDIR/usr/lib/x86_64-linux-gnu/pulseaudio/libpulsecommon-16.1.so" ]] || \
  die "补包后缺少 libpulsecommon-16.1.so。"

log "补入与 libpulse0 同版本的 libpulse-mainloop-glib0"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  "$LIBPULSE_GLIB_URL" \
  -o "$LIBPULSE_GLIB_DEB"
[[ "$(sha256sum "$LIBPULSE_GLIB_DEB" | awk '{print $1}')" == "$LIBPULSE_GLIB_SHA256" ]] || \
  die "libpulse-mainloop-glib0 SHA-256 校验失败。"
mkdir -p "$LIBPULSE_GLIB_EXTRACT"
(
  cd "$LIBPULSE_GLIB_EXTRACT"
  ar x "$LIBPULSE_GLIB_DEB"
)
pulse_glib_data_archive="$(find "$LIBPULSE_GLIB_EXTRACT" -maxdepth 1 -type f -name 'data.tar.*' -print -quit)"
[[ -n "$pulse_glib_data_archive" ]] || die "libpulse-mainloop-glib0 deb 中没有 data.tar.*。"
tar -xf "$pulse_glib_data_archive" -C "$APPDIR"
[[ -e "$APPDIR/usr/lib/x86_64-linux-gnu/libpulse-mainloop-glib.so.0" ]] || \
  die "补包后仍缺少 libpulse-mainloop-glib.so.0。"

# Debian 12 libpulse0 只要求 glibc >= 2.34；禁止未来误换成要求更高 glibc 的库。
if strings "$APPDIR/usr/lib/x86_64-linux-gnu/libpulse.so.0.24.2" | \
  grep -Eq 'GLIBC_2\.(3[5-9]|[4-9][0-9])'; then
  die "libpulse0 出现高于 GLIBC_2.34 的符号要求。"
fi

log "恢复用户已验证可用的中文/XCB AppRun 环境"
cat > "$APPDIR/AppRun" <<'APP_RUN'
#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"

export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh

export PATH="$HERE"/opt/XnView:"$HERE"/opt/XnView/lib:"$HERE"/opt/XnView/Plugins:"$HERE"/opt/XnView/qml:"$HERE"/usr:"$HERE"/usr/bin:"$HERE"/usr/lib:"$HERE"/usr/lib/x86_64-linux-gnu:"$HERE"/usr/lib/x86_64-linux-gnu/pulseaudio:"$HERE"/usr/plugins:"$HERE"/usr/share:"$HERE"/usr/translations:"$PATH"
export LD_LIBRARY_PATH="$HERE"/opt/XnView:"$HERE"/opt/XnView/lib:"$HERE"/opt/XnView/Plugins:"$HERE"/opt/XnView/qml:"$HERE"/usr:"$HERE"/usr/bin:"$HERE"/usr/lib:"$HERE"/usr/lib/x86_64-linux-gnu:"$HERE"/usr/lib/x86_64-linux-gnu/pulseaudio:"$HERE"/usr/plugins:"$HERE"/usr/share:"$HERE"/usr/translations:"${LD_LIBRARY_PATH:-}"
export QT_PLUGIN_PATH="$HERE"/opt/XnView:"$HERE"/opt/XnView/lib:"$HERE"/opt/XnView/Plugins:"$HERE"/opt/XnView/qml:"$HERE"/usr:"$HERE"/usr/bin:"$HERE"/usr/lib:"$HERE"/usr/plugins:"$HERE"/usr/share:"$HERE"/usr/translations:"${QT_PLUGIN_PATH:-}"
export QML_IMPORT_PATH="$HERE"/opt/XnView:"$HERE"/opt/XnView/lib:"$HERE"/opt/XnView/Plugins:"$HERE"/opt/XnView/qml:"$HERE"/usr:"$HERE"/usr/bin:"$HERE"/usr/lib:"$HERE"/usr/plugins:"$HERE"/usr/share:"$HERE"/usr/translations:"${QML_IMPORT_PATH:-}"
export QML2_IMPORT_PATH="$HERE"/opt/XnView:"$HERE"/opt/XnView/lib:"$HERE"/opt/XnView/Plugins:"$HERE"/opt/XnView/qml:"$HERE"/usr:"$HERE"/usr/bin:"$HERE"/usr/lib:"$HERE"/usr/plugins:"$HERE"/usr/share:"$HERE"/usr/translations:"${QML2_IMPORT_PATH:-}"
export XDG_DATA_DIRS="$HERE"/opt/XnView:"$HERE"/opt/XnView/lib:"$HERE"/opt/XnView/Plugins:"$HERE"/opt/XnView/qml:"$HERE"/usr:"$HERE"/usr/bin:"$HERE"/usr/lib:"$HERE"/usr/plugins:"$HERE"/usr/share:"$HERE"/usr/translations:"${XDG_DATA_DIRS:-}"

export QT_AUTO_SCREEN_SCALE_FACTOR=1
export QT_QPA_PLATFORM=xcb
export QT_FONT_DPI=96

exec "$HERE"/opt/XnView/XnView "$@"
APP_RUN
chmod 0755 "$APPDIR/AppRun"

# 不运行 linuxdeploy，也不从当前 Arch 构建机复制 Qt/GLib/glibc 系统层。

mapfile -d '' desktop_files < <(find "$APPDIR" -maxdepth 1 -type f -name '*.desktop' -print0)
[[ ${#desktop_files[@]} -ge 1 ]] || die "AppDir 根目录没有 desktop 文件。"
for desktop_file in "${desktop_files[@]}"; do
  desktop-file-validate "$desktop_file"
done

log "下载固定 appimagetool 并重新封装 AppImage"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  "$APPIMAGETOOL_URL" \
  -o "$APPIMAGETOOL"
[[ "$(sha256sum "$APPIMAGETOOL" | awk '{print $1}')" == "$APPIMAGETOOL_SHA256" ]] || \
  die "appimagetool SHA-256 校验失败。"
chmod 0755 "$APPIMAGETOOL"

ARCH=x86_64 \
APPIMAGE_EXTRACT_AND_RUN=1 \
"$APPIMAGETOOL" "$APPDIR" "$OUTFILE"
chmod 0755 "$OUTFILE"
[[ -s "$OUTFILE" ]] || die "输出 AppImage 为空。"
file "$OUTFILE" | grep -q 'ELF 64-bit' || die "输出文件不是 64 位 AppImage ELF。"

log "验证最终包的中文环境、翻译文件和 libpulse"
(
  cd "$VERIFY_DIR"
  "$OUTFILE" --appimage-extract >/dev/null
)
[[ -d "$VERIFY_ROOT" ]] || die "最终 AppImage 提取失败。"
[[ -x "$VERIFY_ROOT/AppRun" ]] || die "最终包缺少 AppRun。"
[[ -x "$VERIFY_ROOT/opt/XnView/XnView" ]] || die "最终包缺少 XnView 主程序。"
[[ -f "$VERIFY_ROOT/opt/XnView/language/xnview_zh_CN.qm" ]] || die "最终包缺少简体中文翻译。"
[[ -e "$VERIFY_ROOT/usr/lib/x86_64-linux-gnu/libpulse.so.0" ]] || die "最终包缺少 libpulse.so.0。"
[[ -e "$VERIFY_ROOT/usr/lib/x86_64-linux-gnu/libpulse-mainloop-glib.so.0" ]] || die "最终包缺少 libpulse-mainloop-glib.so.0。"
[[ -f "$VERIFY_ROOT/usr/lib/x86_64-linux-gnu/pulseaudio/libpulsecommon-16.1.so" ]] || \
  die "最终包缺少 libpulsecommon。"
grep -Fq 'export LANG=zh_CN.UTF-8' "$VERIFY_ROOT/AppRun" || die "最终 AppRun 缺少中文 LANG。"
grep -Fq 'export LANGUAGE=zh_CN:zh' "$VERIFY_ROOT/AppRun" || die "最终 AppRun 缺少中文 LANGUAGE。"
grep -Fq 'export QT_QPA_PLATFORM=xcb' "$VERIFY_ROOT/AppRun" || die "最终 AppRun 缺少 xcb 设置。"

log "检查 XnView 主程序能从包内解析 libpulse"
set +e
LD_LIBRARY_PATH="$VERIFY_ROOT/opt/XnView:$VERIFY_ROOT/opt/XnView/lib:$VERIFY_ROOT/opt/XnView/Plugins:$VERIFY_ROOT/opt/XnView/qml:$VERIFY_ROOT/usr/lib:$VERIFY_ROOT/usr/lib/x86_64-linux-gnu:$VERIFY_ROOT/usr/lib/x86_64-linux-gnu/pulseaudio" \
ldd "$VERIFY_ROOT/opt/XnView/XnView" > "$VERIFY_DIR/ldd.log" 2>&1
ldd_rc=$?
set -e
cat "$VERIFY_DIR/ldd.log"
[[ "$ldd_rc" -eq 0 ]] || die "XnView ldd 检查失败。"
grep -F 'libpulse.so.0 => ' "$VERIFY_DIR/ldd.log" | grep -Fq "$VERIFY_ROOT/usr/lib/x86_64-linux-gnu/libpulse.so.0" || \
  die "XnView 没有解析到包内 libpulse.so.0。"

LD_LIBRARY_PATH="$VERIFY_ROOT/opt/XnView:$VERIFY_ROOT/opt/XnView/lib:$VERIFY_ROOT/opt/XnView/Plugins:$VERIFY_ROOT/opt/XnView/qml:$VERIFY_ROOT/usr/lib:$VERIFY_ROOT/usr/lib/x86_64-linux-gnu:$VERIFY_ROOT/usr/lib/x86_64-linux-gnu/pulseaudio" \
ldd "$VERIFY_ROOT/opt/XnView/lib/libQt5Multimedia.so.5" > "$VERIFY_DIR/qt-multimedia-ldd.log" 2>&1
cat "$VERIFY_DIR/qt-multimedia-ldd.log"
grep -F 'libpulse.so.0 => ' "$VERIFY_DIR/qt-multimedia-ldd.log" | grep -Fq "$VERIFY_ROOT/usr/lib/x86_64-linux-gnu/libpulse.so.0" || \
  die "Qt5Multimedia 没有解析到包内 libpulse.so.0。"
grep -F 'libpulse-mainloop-glib.so.0 => ' "$VERIFY_DIR/qt-multimedia-ldd.log" | grep -Fq "$VERIFY_ROOT/usr/lib/x86_64-linux-gnu/libpulse-mainloop-glib.so.0" || \
  die "Qt5Multimedia 没有解析到包内 libpulse-mainloop-glib.so.0。"
if grep -Fq 'not found' "$VERIFY_DIR/qt-multimedia-ldd.log"; then
  die "Qt5Multimedia 仍存在未解析的共享库。"
fi
if grep -Fq 'not found' "$VERIFY_DIR/ldd.log"; then
  die "最终包仍存在未解析的共享库。"
fi

log "在隔离 HOME / XDG 目录中执行 Xvfb 冒烟测试"
mkdir -p "$SMOKE_HOME/中文目录测试" "$SMOKE_CONFIG" "$SMOKE_CACHE" "$SMOKE_RUNTIME"
chmod 0700 "$SMOKE_RUNTIME"

set +e
HOME="$SMOKE_HOME" \
XDG_CONFIG_HOME="$SMOKE_CONFIG" \
XDG_CACHE_HOME="$SMOKE_CACHE" \
XDG_RUNTIME_DIR="$SMOKE_RUNTIME" \
APPIMAGE_EXTRACT_AND_RUN=1 \
timeout 30s xvfb-run -a "$OUTFILE" "$SMOKE_HOME/中文目录测试" >"$SMOKE_LOG" 2>&1
smoke_rc=$?
set -e

cat "$SMOKE_LOG"
printf 'XnView MP smoke exit code: %s\n' "$smoke_rc"

if grep -Eqi \
  'Segmentation fault|Aborted|error while loading shared libraries|Cannot mix incompatible Qt libraries|Could not load the Qt platform plugin|no Qt platform plugin could be initialized|GLIBC_[0-9.]+.*not found' \
  "$SMOKE_LOG"; then
  die "XnView MP 冒烟测试检测到致命运行时错误。"
fi

if [[ "$smoke_rc" -ne 0 && "$smoke_rc" -ne 124 ]]; then
  die "XnView MP 在冒烟测试期间异常退出：$smoke_rc"
fi

log "构建验证完成"
sha256sum "$OUTFILE"
