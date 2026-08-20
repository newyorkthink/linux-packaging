#!/usr/bin/env bash
# 为 PySide6 Qt xcb 平台插件补齐 Kali Rolling 运行库；这些库仅供 Qt 使用。
set -Eeuo pipefail

readonly APPDIR="${1:?用法：$0 <AppDir>}"

log() {
  printf '[WinPodX Qt] %s\n' "$*"
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

[[ "$(uname -m)" == "x86_64" ]] || die "当前仅支持 x86_64。"
command -v docker >/dev/null 2>&1 || die "构建环境缺少 docker。"
[[ -d "$APPDIR" ]] || die "找不到 AppDir：$APPDIR"

mapfile -t qt_roots < <(find "$APPDIR/opt/python/lib" \
  -path '*/site-packages/PySide6/Qt' -type d -print)
[[ ${#qt_roots[@]} -eq 1 ]] || die "无法唯一定位 PySide6 Qt 运行时。"
readonly QT_ROOT="${qt_roots[0]}"
readonly QT_LIB_DIR="$QT_ROOT/lib"
readonly QXCB_PLUGIN="$QT_ROOT/plugins/platforms/libqxcb.so"
[[ -f "$QXCB_PLUGIN" ]] || die "AppImage 内缺少 Qt xcb 平台插件。"
[[ -d "$QT_LIB_DIR" ]] || die "AppImage 内缺少 PySide6 Qt/lib。"

# EGL、GL、glibc 和 FreeRDP 的 X11/XCB 集成库必须继续使用宿主版本。
find "$APPDIR/usr/lib" "$QT_LIB_DIR" -maxdepth 1 \( \
  -name 'libEGL.so*' -o \
  -name 'libGL.so*' -o \
  -name 'libGLX.so*' -o \
  -name 'libGLdispatch.so*' -o \
  -name 'libc.so*' -o \
  -name 'ld-linux*.so*' \
\) -delete 2>/dev/null || true

# 清除公共目录中的 Qt 专用副本，避免 xfreerdp 通过全局搜索路径加载它们。
find "$APPDIR/usr/lib" -maxdepth 1 \( \
  -name 'libxcb-cursor.so*' -o \
  -name 'libxcb-icccm.so*' -o \
  -name 'libxcb-image.so*' -o \
  -name 'libxcb-keysyms.so*' -o \
  -name 'libxcb-render-util.so*' -o \
  -name 'libxcb-util.so*' -o \
  -name 'libxcb-xkb.so*' -o \
  -name 'libxkbcommon-x11.so*' \
\) -delete 2>/dev/null || true

log "从 Kali Rolling 提取 Qt 私有 XCB 运行库"
docker run --rm \
  -v "$APPDIR:/AppDir" \
  kalilinux/kali-rolling bash -lc '
    set -Eeuo pipefail
    export DEBIAN_FRONTEND=noninteractive

    apt-get update >/dev/null
    apt-get install -y --no-install-recommends \
      libxcb-cursor0 \
      libxcb-icccm4 \
      libxcb-image0 \
      libxcb-keysyms1 \
      libxcb-render-util0 \
      libxcb-util1 \
      libxcb-xkb1 \
      libxkbcommon-x11-0 >/dev/null

    QT_ROOT="$(find /AppDir/opt/python/lib \
      -path "*/site-packages/PySide6/Qt" -type d -print -quit)"
    [[ -n "$QT_ROOT" ]]
    mkdir -p "$QT_ROOT/lib"

    for library in \
      /usr/lib/x86_64-linux-gnu/libxcb-cursor.so.0 \
      /usr/lib/x86_64-linux-gnu/libxcb-icccm.so.4 \
      /usr/lib/x86_64-linux-gnu/libxcb-image.so.0 \
      /usr/lib/x86_64-linux-gnu/libxcb-keysyms.so.1 \
      /usr/lib/x86_64-linux-gnu/libxcb-render-util.so.0 \
      /usr/lib/x86_64-linux-gnu/libxcb-util.so.1 \
      /usr/lib/x86_64-linux-gnu/libxcb-xkb.so.1 \
      /usr/lib/x86_64-linux-gnu/libxkbcommon-x11.so.0; do
      [[ -f "$library" ]] || {
        echo "缺少 Qt/XCB 运行库：$library" >&2
        exit 1
      }
      cp -Lf "$library" "$QT_ROOT/lib/$(basename "$library")"
    done
  '

for required_library in \
  libxcb-cursor.so.0 \
  libxcb-icccm.so.4 \
  libxcb-image.so.0 \
  libxcb-keysyms.so.1 \
  libxcb-render-util.so.0 \
  libxcb-util.so.1 \
  libxcb-xkb.so.1 \
  libxkbcommon-x11.so.0; do
  [[ -f "$QT_LIB_DIR/$required_library" ]] || \
    die "PySide6 Qt/lib 缺少 $required_library。"
  [[ ! -e "$APPDIR/usr/lib/$required_library" ]] || \
    die "AppDir/usr/lib 不应包含 Qt 私有库 $required_library。"
done

log "检查 Qt xcb 平台插件依赖"
dependencies="$(
  LD_LIBRARY_PATH="$QT_LIB_DIR:$APPDIR/usr/lib:$APPDIR/opt/python/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    ldd "$QXCB_PLUGIN"
)"
missing="$(awk '/=> not found/ {print $1}' <<<"$dependencies" | sort -u)"
[[ -z "$missing" ]] || die "Qt xcb 运行库仍有缺失：$missing"
for required_library in \
  libxcb-cursor.so.0 \
  libxcb-icccm.so.4 \
  libxcb-image.so.0 \
  libxcb-keysyms.so.1 \
  libxcb-render-util.so.0 \
  libxcb-util.so.1 \
  libxcb-xkb.so.1 \
  libxkbcommon-x11.so.0; do
  grep -F "$required_library => $QT_LIB_DIR/$required_library" <<<"$dependencies" >/dev/null || \
    die "Qt 未从私有目录加载 $required_library。"
done

log "Qt/XCB 运行库已补齐，并与 FreeRDP 隔离"
