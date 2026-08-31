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
  ar awk cat chmod cp curl desktop-file-validate file find grep ldd mkdir mv python3 readelf \
  readlink sed sha256sum strings tar timeout xvfb-run; do
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
[[ -e "$APPDIR/AppRun" ]] || die "官方 AppImage 缺少 AppRun。"

# 上游 1.11.x 的 AppImage 内部目录布局可能调整；不再硬编码 /opt/XnView。
mapfile -d '' xnview_bins < <(
  find "$APPDIR" -type f -perm -u+x -name 'XnView' -print0
)
if [[ ${#xnview_bins[@]} -eq 0 ]]; then
  mapfile -d '' xnview_bins < <(
    find "$APPDIR" -type f -perm -u+x \( -iname 'xnview' -o -iname 'xnviewmp' \) -print0
  )
fi
[[ ${#xnview_bins[@]} -ge 1 ]] || die "官方 AppImage 中没有找到 XnView 主程序。"
XNVIEW_BIN="${xnview_bins[0]}"
XNVIEW_REL="${XNVIEW_BIN#"$APPDIR"/}"
readonly XNVIEW_BIN XNVIEW_REL
printf 'XnView executable: %s\n' "$XNVIEW_REL"

mapfile -d '' zh_cn_files < <(find "$APPDIR" -type f -name 'xnview_zh_CN.qm' -print0)
[[ ${#zh_cn_files[@]} -ge 1 ]] || die "官方包缺少简体中文翻译文件 xnview_zh_CN.qm。"
ZH_CN_REL="${zh_cn_files[0]#"$APPDIR"/}"
readonly ZH_CN_REL
printf 'XnView zh_CN translation: %s\n' "$ZH_CN_REL"

mapfile -d '' qt_multimedia_files < <(find "$APPDIR" -type f -name 'libQt5Multimedia.so.5*' -print0)
[[ ${#qt_multimedia_files[@]} -ge 1 ]] || die "官方包缺少 libQt5Multimedia.so.5。"
QT_MULTIMEDIA_REL="${qt_multimedia_files[0]#"$APPDIR"/}"
QT_MULTIMEDIA_DIR_REL="$(dirname "$QT_MULTIMEDIA_REL")"
readonly QT_MULTIMEDIA_REL QT_MULTIMEDIA_DIR_REL
printf 'XnView QtMultimedia: %s\n' "$QT_MULTIMEDIA_REL"

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

# 把 PulseAudio client libraries 放进 XnView 自己的 Qt library 目录。
# 这样继续沿用上游 AppRun / RPATH 的库搜索方式，不依赖目标系统的 libpulse，也不需要改 Qt/GLib。
QT_LIBRARY_DIR="$APPDIR/$QT_MULTIMEDIA_DIR_REL"
readonly QT_LIBRARY_DIR
cp -a "$APPDIR/usr/lib/x86_64-linux-gnu"/libpulse.so.0* "$QT_LIBRARY_DIR/"
cp -a "$APPDIR/usr/lib/x86_64-linux-gnu"/libpulse-mainloop-glib.so.0* "$QT_LIBRARY_DIR/"
cp -a "$APPDIR/usr/lib/x86_64-linux-gnu/pulseaudio/libpulsecommon-16.1.so" "$QT_LIBRARY_DIR/"
[[ -e "$QT_LIBRARY_DIR/libpulse.so.0" ]] || die "XnView Qt library 目录仍缺少 libpulse.so.0。"
[[ -e "$QT_LIBRARY_DIR/libpulse-mainloop-glib.so.0" ]] || die "XnView Qt library 目录仍缺少 libpulse-mainloop-glib.so.0。"
[[ -f "$QT_LIBRARY_DIR/libpulsecommon-16.1.so" ]] || die "XnView Qt library 目录仍缺少 libpulsecommon。"

# Debian 12 libpulse0 只要求 glibc >= 2.34；禁止未来误换成要求更高 glibc 的库。
if strings "$APPDIR/usr/lib/x86_64-linux-gnu/libpulse.so.0.24.2" | \
  grep -Eq 'GLIBC_2\.(3[5-9]|[4-9][0-9])'; then
  die "libpulse0 出现高于 GLIBC_2.34 的符号要求。"
fi

log "在官方 AppRun 外层恢复旧包已验证可用的中文/XCB 环境"
# 保留上游原本的启动逻辑，只在最外层增加旧工作包使用的中文 locale 和 XCB 设置。
# 这样不会再依赖上游 AppImage 内部目录是否是 /opt/XnView。
cp -a "$APPDIR/AppRun" "$APPDIR/AppRun.original"
cat > "$APPDIR/AppRun" <<'APP_RUN'
#!/usr/bin/env bash
set -e

HERE="$(dirname "$(readlink -f "${0}")")"

export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh

export QT_AUTO_SCREEN_SCALE_FACTOR=1
export QT_QPA_PLATFORM=xcb
export QT_FONT_DPI=96

exec "$HERE/AppRun.original" "$@"
APP_RUN
chmod 0755 "$APPDIR/AppRun"
[[ -x "$APPDIR/AppRun.original" ]] || chmod 0755 "$APPDIR/AppRun.original"

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
[[ -e "$VERIFY_ROOT/AppRun.original" ]] || die "最终包缺少上游原始 AppRun。"
[[ -x "$VERIFY_ROOT/$XNVIEW_REL" ]] || die "最终包缺少 XnView 主程序：$XNVIEW_REL"
[[ -f "$VERIFY_ROOT/$ZH_CN_REL" ]] || die "最终包缺少简体中文翻译：$ZH_CN_REL"
[[ -e "$VERIFY_ROOT/usr/lib/x86_64-linux-gnu/libpulse.so.0" ]] || die "最终包缺少 libpulse.so.0。"
[[ -e "$VERIFY_ROOT/usr/lib/x86_64-linux-gnu/libpulse-mainloop-glib.so.0" ]] || die "最终包缺少 libpulse-mainloop-glib.so.0。"
[[ -f "$VERIFY_ROOT/usr/lib/x86_64-linux-gnu/pulseaudio/libpulsecommon-16.1.so" ]] || \
  die "最终包缺少 libpulsecommon。"
[[ -e "$VERIFY_ROOT/$QT_MULTIMEDIA_DIR_REL/libpulse.so.0" ]] || die "最终 Qt library 目录缺少 libpulse.so.0。"
[[ -e "$VERIFY_ROOT/$QT_MULTIMEDIA_DIR_REL/libpulse-mainloop-glib.so.0" ]] || \
  die "最终 Qt library 目录缺少 libpulse-mainloop-glib.so.0。"
[[ -f "$VERIFY_ROOT/$QT_MULTIMEDIA_DIR_REL/libpulsecommon-16.1.so" ]] || \
  die "最终 Qt library 目录缺少 libpulsecommon。"
grep -Fq 'export LANG=zh_CN.UTF-8' "$VERIFY_ROOT/AppRun" || die "最终 AppRun 缺少中文 LANG。"
grep -Fq 'export LANGUAGE=zh_CN:zh' "$VERIFY_ROOT/AppRun" || die "最终 AppRun 缺少中文 LANGUAGE。"
grep -Fq 'export QT_QPA_PLATFORM=xcb' "$VERIFY_ROOT/AppRun" || die "最终 AppRun 缺少 xcb 设置。"

log "检查 QtMultimedia 优先解析包内 PulseAudio client libraries"
QT_VERIFY_LIBRARY_DIR="$VERIFY_ROOT/$QT_MULTIMEDIA_DIR_REL"
readonly QT_VERIFY_LIBRARY_DIR
LD_LIBRARY_PATH="$QT_VERIFY_LIBRARY_DIR" \
ldd "$VERIFY_ROOT/$QT_MULTIMEDIA_REL" > "$VERIFY_DIR/qt-multimedia-ldd.log" 2>&1
cat "$VERIFY_DIR/qt-multimedia-ldd.log"
grep -F 'libpulse.so.0 => ' "$VERIFY_DIR/qt-multimedia-ldd.log" | grep -Fq "$QT_VERIFY_LIBRARY_DIR/libpulse.so.0" || \
  die "Qt5Multimedia 没有解析到 XnView 包内 libpulse.so.0。"
grep -F 'libpulse-mainloop-glib.so.0 => ' "$VERIFY_DIR/qt-multimedia-ldd.log" | grep -Fq "$QT_VERIFY_LIBRARY_DIR/libpulse-mainloop-glib.so.0" || \
  die "Qt5Multimedia 没有解析到 XnView 包内 libpulse-mainloop-glib.so.0。"
if grep -Fq 'not found' "$VERIFY_DIR/qt-multimedia-ldd.log"; then
  die "Qt5Multimedia 仍存在未解析的共享库。"
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
