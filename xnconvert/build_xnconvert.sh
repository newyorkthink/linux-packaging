#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
cd "$SCRIPT_DIR"

log() {
  printf '[XnConvert] %s\n' "$*"
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

HOST_ARCH="$(uname -m)"
readonly HOST_ARCH
[[ "$HOST_ARCH" == x86_64 ]] || die "当前仅支持 x86_64。"
command -v yay >/dev/null 2>&1 || die "构建环境缺少命令：yay"

readonly BASE_URL="https://download.xnview.com/versions/XnConvert"
readonly CHECKSUMS_URL="$BASE_URL/XnConvert-CHECKSUMS.txt"
readonly SOURCE_DIR="$SCRIPT_DIR/source"
readonly CHECKSUMS_FILE="$SOURCE_DIR/XnConvert-CHECKSUMS.txt"
readonly ARCHIVE_FILE="$SOURCE_DIR/XnConvert-linux-x64.tgz"
readonly EXTRACT_DIR="$SOURCE_DIR/extracted"
readonly APPDIR="$SCRIPT_DIR/AppDir"
readonly APP_INSTALL_DIR="$APPDIR/opt/XnConvert"
readonly DESKTOP_FILE="$SOURCE_DIR/XnConvert.desktop"
readonly CUSTOM_APPRUN="$SOURCE_DIR/AppRun"
readonly LINUXDEPLOY="$SOURCE_DIR/linuxdeploy-x86_64.AppImage"
readonly QT_PLUGIN="$SOURCE_DIR/linuxdeploy-plugin-qt-x86_64.AppImage"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly OUTFILE="$DIST_DIR/xnconvert.AppImage"
readonly VERIFY_DIR="$SCRIPT_DIR/verify"
readonly VERIFY_ROOT="$VERIFY_DIR/squashfs-root"
readonly SMOKE_HOME="$SCRIPT_DIR/smoke-home"
readonly SMOKE_CONFIG="$SCRIPT_DIR/smoke-config"
readonly SMOKE_CACHE="$SCRIPT_DIR/smoke-cache"
readonly SMOKE_RUNTIME="$SCRIPT_DIR/smoke-runtime"
readonly SMOKE_LOG="$SCRIPT_DIR/xnconvert-smoke.log"
readonly LDD_LOG="$SCRIPT_DIR/xnconvert-qxcb-ldd.log"

# 只清理 XnConvert 自己的构建、验证和隔离测试目录。
rm -rf \
  "$SOURCE_DIR" \
  "$APPDIR" \
  "$DIST_DIR" \
  "$VERIFY_DIR" \
  "$SMOKE_HOME" \
  "$SMOKE_CONFIG" \
  "$SMOKE_CACHE" \
  "$SMOKE_RUNTIME"
rm -f "$SMOKE_LOG" "$LDD_LOG"
mkdir -p "$SOURCE_DIR" "$EXTRACT_DIR" "$DIST_DIR" "$VERIFY_DIR"

# 安装构建、Qt5、XCB 依赖部署和 Xvfb 冒烟测试工具；这些依赖会由 linuxdeploy 收集进 AppImage。
yay -S --noconfirm --needed \
  coreutils curl desktop-file-utils file findutils gawk grep python tar \
  gtk3 libwebp qt5-base qt5-multimedia qt5-declarative qt5-svg qt5-translations gst-plugins-bad-libs \
  libx11 libxext libxi libxinerama libxrender libxcb \
  xcb-util xcb-util-image xcb-util-keysyms xcb-util-renderutil xcb-util-wm \
  libxkbcommon libxkbcommon-x11 fontconfig freetype2 libglvnd \
  xorg-server-xvfb xorg-xauth

for command_name in \
  awk cat chmod cp curl desktop-file-validate file find grep ldd mkdir python3 readlink sha256sum tar timeout xvfb-run; do
  command -v "$command_name" >/dev/null 2>&1 || \
    die "构建环境缺少命令：$command_name"
done

if command -v qmake-qt5 >/dev/null 2>&1; then
  QMAKE_BIN="$(command -v qmake-qt5)"
elif command -v qmake >/dev/null 2>&1; then
  QMAKE_BIN="$(command -v qmake)"
else
  die "构建环境缺少 Qt5 qmake。"
fi
readonly QMAKE_BIN
[[ "$($QMAKE_BIN -query QT_VERSION)" == 5.* ]] || die "linuxdeploy Qt 插件没有找到 Qt5 qmake。"

log "读取 XnConvert 官方校验文件并解析最新稳定 x86_64 TGZ"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  "$CHECKSUMS_URL" \
  -o "$CHECKSUMS_FILE"
[[ -s "$CHECKSUMS_FILE" ]] || die "官方校验文件为空。"

mapfile -t archive_meta < <(
  python3 - "$CHECKSUMS_FILE" <<'PY'
import re
import sys

pattern = re.compile(
    r"^(?P<sha>[0-9a-f]{64})  "
    r"(?P<name>XnConvert-(?P<version>[0-9]+(?:\.[0-9]+)+)-linux-x64\.tgz)$"
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
    raise SystemExit("官方校验文件中没有找到稳定的 x86_64 TGZ。")

_, version, name, sha256 = max(matches, key=lambda item: item[0])
print(version)
print(name)
print(sha256)
PY
)
[[ ${#archive_meta[@]} -eq 3 ]] || die "无法完整解析官方 TGZ 元数据。"
readonly VERSION="${archive_meta[0]}"
readonly ARCHIVE_NAME="${archive_meta[1]}"
readonly EXPECTED_SHA256="${archive_meta[2]}"
readonly ARCHIVE_URL="$BASE_URL/$ARCHIVE_NAME"

[[ "$VERSION" =~ ^[0-9]+(\.[0-9]+)+$ ]] || die "解析出的版本号异常：$VERSION"
[[ "$ARCHIVE_NAME" == "XnConvert-$VERSION-linux-x64.tgz" ]] || die "解析出的 TGZ 文件名异常：$ARCHIVE_NAME"
[[ "$EXPECTED_SHA256" =~ ^[0-9a-f]{64}$ ]] || die "解析出的 SHA-256 异常。"
[[ "$ARCHIVE_URL" == https://download.xnview.com/versions/XnConvert/XnConvert-*-linux-x64.tgz ]] || \
  die "解析出的下载 URL 异常：$ARCHIVE_URL"
printf 'XnConvert version: %s\nXnConvert source: %s\n' "$VERSION" "$ARCHIVE_URL"

log "下载并校验官方 TGZ"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  "$ARCHIVE_URL" \
  -o "$ARCHIVE_FILE"
[[ -s "$ARCHIVE_FILE" ]] || die "官方下载文件为空。"
ACTUAL_SHA256="$(sha256sum "$ARCHIVE_FILE" | awk '{print $1}')"
readonly ACTUAL_SHA256
[[ "$ACTUAL_SHA256" == "$EXPECTED_SHA256" ]] || die "官方 TGZ SHA-256 校验失败。"
printf 'XnConvert official TGZ SHA-256: %s\n' "$ACTUAL_SHA256"

tar -xzf "$ARCHIVE_FILE" -C "$EXTRACT_DIR"
mapfile -d '' app_binaries < <(find "$EXTRACT_DIR" -type f -name XnConvert -perm -u+x -print0)
[[ ${#app_binaries[@]} -eq 1 ]] || die "官方 TGZ 中 XnConvert 主程序数量异常：${#app_binaries[@]}"
readonly SOURCE_APP_BINARY="${app_binaries[0]}"
readonly SOURCE_APP_DIR="$(dirname "$SOURCE_APP_BINARY")"

# 保留官方 XnConvert 完整目录（自带 Qt、插件、语言文件等），作为旧工作包中的 /opt/XnConvert 基线。
mkdir -p "$APP_INSTALL_DIR"
cp -a "$SOURCE_APP_DIR/." "$APP_INSTALL_DIR/"
readonly APP_BINARY="$APP_INSTALL_DIR/XnConvert"
readonly APP_XCB_PLUGIN="$APP_INSTALL_DIR/lib/platforms/libqxcb.so"
readonly APP_ICON="$APP_INSTALL_DIR/xnconvert.png"
[[ -x "$APP_BINARY" ]] || die "AppDir 缺少 XnConvert 主程序。"
[[ -f "$APP_XCB_PLUGIN" ]] || die "官方目录缺少 Qt xcb 平台插件。"
[[ -f "$APP_ICON" ]] || die "官方目录缺少 xnconvert.png。"
[[ -f "$APP_INSTALL_DIR/language/xnview_zh_CN.qm" ]] || die "官方目录缺少简体中文翻译。"

# 恢复旧工作包中的 /usr/bin/xnconvert 启动包装器；AppRun 仍直接启动 /opt/XnConvert/XnConvert。
mkdir -p "$APPDIR/usr/bin"
cat > "$APPDIR/usr/bin/xnconvert" <<'EOF_WRAPPER'
#!/bin/sh

export LD_LIBRARY_PATH=/opt/XnConvert/lib
export QT_PLUGIN_PATH=/opt/XnConvert/lib

if [ $# -lt 1 ]; then
  /opt/XnConvert/XnConvert
else
  /opt/XnConvert/XnConvert $@
fi
EOF_WRAPPER
chmod 0755 "$APPDIR/usr/bin/xnconvert"

# 使用旧工作包的 desktop 信息，保持启动名称不变。
cat > "$DESKTOP_FILE" <<'EOF_DESKTOP'
[Desktop Entry]
Type=Application
Name=XnConvert
GenericName=Image batch converter
Comment=Batch convert images
Exec=xnconvert %U
TryExec=xnconvert
Terminal=false
Icon=xnconvert
Categories=Graphics;
StartupNotify=true
EOF_DESKTOP
desktop-file-validate "$DESKTOP_FILE"

# 逐字恢复旧工作包的中文环境、Qt/XCB 环境和启动路径。
cat > "$CUSTOM_APPRUN" <<'EOF_APPRUN'
#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"

export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh

export PATH="$HERE"/opt/XnConvert:"$HERE"/opt/XnConvert/lib:"$HERE"/opt/XnConvert/Plugins:"$HERE"/opt/XnConvert/qml:"$HERE"/usr:"$HERE"/usr/bin:"$HERE"/usr/lib:"$HERE"/usr/plugins:"$HERE"/usr/share:"$HERE"/usr/translations:"$PATH"
export LD_LIBRARY_PATH="$HERE"/opt/XnConvert:"$HERE"/opt/XnConvert/lib:"$HERE"/opt/XnConvert/Plugins:"$HERE"/opt/XnConvert/qml:"$HERE"/usr:"$HERE"/usr/bin:"$HERE"/usr/lib:"$HERE"/usr/plugins:"$HERE"/usr/share:"$HERE"/usr/translations:"$LD_LIBRARY_PATH"
export QT_PLUGIN_PATH="$HERE"/opt/XnConvert:"$HERE"/opt/XnConvert/lib:"$HERE"/opt/XnConvert/Plugins:"$HERE"/opt/XnConvert/qml:"$HERE"/usr:"$HERE"/usr/bin:"$HERE"/usr/lib:"$HERE"/usr/plugins:"$HERE"/usr/share:"$HERE"/usr/translations:"$QT_PLUGIN_PATH"
export QML_IMPORT_PATH="$HERE"/opt/XnConvert:"$HERE"/opt/XnConvert/lib:"$HERE"/opt/XnConvert/Plugins:"$HERE"/opt/XnConvert/qml:"$HERE"/usr:"$HERE"/usr/bin:"$HERE"/usr/lib:"$HERE"/usr/plugins:"$HERE"/usr/share:"$HERE"/usr/translations:"$QML_IMPORT_PATH"
export QML2_IMPORT_PATH="$HERE"/opt/XnConvert:"$HERE"/opt/XnConvert/lib:"$HERE"/opt/XnConvert/Plugins:"$HERE"/opt/XnConvert/qml:"$HERE"/usr:"$HERE"/usr/bin:"$HERE"/usr/lib:"$HERE"/usr/plugins:"$HERE"/usr/share:"$HERE"/usr/translations:"$QML2_IMPORT_PATH"
export XDG_DATA_DIRS="$HERE"/opt/XnConvert:"$HERE"/opt/XnConvert/lib:"$HERE"/opt/XnConvert/Plugins:"$HERE"/opt/XnConvert/qml:"$HERE"/usr:"$HERE"/usr/bin:"$HERE"/usr/lib:"$HERE"/usr/plugins:"$HERE"/usr/share:"$HERE"/usr/translations:"$XDG_DATA_DIRS"

export QT_AUTO_SCREEN_SCALE_FACTOR=1
export QT_QPA_PLATFORM=xcb
export QT_FONT_DPI=96 

exec "$HERE"/opt/XnConvert/XnConvert "$@"
EOF_APPRUN
chmod 0755 "$CUSTOM_APPRUN"

log "下载 linuxdeploy 与 Qt 插件"
curl -fL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 20 \
  https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage \
  -o "$LINUXDEPLOY"
curl -fL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 20 \
  https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage \
  -o "$QT_PLUGIN"
chmod 0755 "$LINUXDEPLOY" "$QT_PLUGIN"
file "$LINUXDEPLOY" | grep -q 'ELF 64-bit' || die "linuxdeploy 下载文件异常。"
file "$QT_PLUGIN" | grep -q 'ELF 64-bit' || die "linuxdeploy Qt 插件下载文件异常。"

# 旧工作包在 /usr/lib 中额外带了一套系统 Qt；这里仅用 Core/Gui 引导 linuxdeploy Qt 插件部署
# XCB 平台插件、Qt 翻译和其动态依赖。不要把系统全部 libQt5*.so.5 预先塞入 AppDir，
# 否则 Qt 插件会把无关的 SQL/MySQL 等插件一并扫描并要求额外数据库运行库。
readonly QT_LIB_DIR="$($QMAKE_BIN -query QT_INSTALL_LIBS)"
readonly QT_TRANSLATIONS_DIR="$($QMAKE_BIN -query QT_INSTALL_TRANSLATIONS)"
[[ -d "$QT_LIB_DIR" ]] || die "Qt5 库目录不存在：$QT_LIB_DIR"
[[ -d "$QT_TRANSLATIONS_DIR" ]] || die "Qt5 翻译目录不存在：$QT_TRANSLATIONS_DIR"
mkdir -p "$APPDIR/usr/translations"
cp -a "$QT_TRANSLATIONS_DIR/." "$APPDIR/usr/translations/"
[[ -f "$APPDIR/usr/translations/qtbase_zh_CN.qm" ]] || die "系统 Qt5 缺少简体中文 qtbase 翻译。"

qt_bundle_libraries=(
  "$QT_LIB_DIR/libQt5Core.so.5"
  "$QT_LIB_DIR/libQt5Gui.so.5"
)
for qt_library in "${qt_bundle_libraries[@]}"; do
  [[ -f "$qt_library" ]] || die "Qt5 引导库不存在：$qt_library"
done

linuxdeploy_args=(
  --appdir "$APPDIR"
  --desktop-file "$DESKTOP_FILE"
  --icon-file "$APP_ICON"
  --custom-apprun "$CUSTOM_APPRUN"
)
for qt_library in "${qt_bundle_libraries[@]}"; do
  linuxdeploy_args+=(--library "$qt_library")
done

linuxdeploy_args+=(--plugin qt --output appimage)

export PATH="$SOURCE_DIR:$PATH"
export QMAKE="$QMAKE_BIN"
export ARCH=x86_64
export LDAI_OUTPUT="$OUTFILE"
export APPIMAGE_EXTRACT_AND_RUN=1
# linuxdeploy-plugin-qt 内置 strip 不支持当前 Arch ELF 的 .relr.dyn；使用 linuxdeploy 的 NO_STRIP 开关跳过 strip。
NO_STRIP=1 "$LINUXDEPLOY" "${linuxdeploy_args[@]}"

[[ -s "$OUTFILE" ]] || die "输出 AppImage 为空。"
chmod 0755 "$OUTFILE"
file "$OUTFILE" | grep -q 'ELF 64-bit' || die "输出文件不是 64 位 AppImage ELF。"

log "验证 AppImage 内的旧工作包环境、中文翻译和 XCB 依赖"
(
  cd "$VERIFY_DIR"
  "$OUTFILE" --appimage-extract >/dev/null
)
[[ -d "$VERIFY_ROOT" ]] || die "AppImage 提取失败。"
[[ -x "$VERIFY_ROOT/AppRun" ]] || die "提取后的 AppImage 缺少可执行 AppRun。"
[[ -x "$VERIFY_ROOT/AppRun.wrapped" ]] || die "提取后的 AppImage 缺少 AppRun.wrapped。"
[[ -x "$VERIFY_ROOT/opt/XnConvert/XnConvert" ]] || die "提取后的 AppImage 缺少 XnConvert 主程序。"
[[ -f "$VERIFY_ROOT/opt/XnConvert/language/xnview_zh_CN.qm" ]] || die "提取后的 AppImage 缺少简体中文翻译。"
[[ -f "$VERIFY_ROOT/opt/XnConvert/lib/platforms/libqxcb.so" ]] || die "提取后的 AppImage 缺少官方 qxcb 插件。"
[[ -f "$VERIFY_ROOT/usr/plugins/platforms/libqxcb.so" ]] || die "linuxdeploy Qt 插件没有部署 qxcb 平台插件。"
[[ ! -e "$VERIFY_ROOT/usr/plugins/sqldrivers/libqsqlmysql.so" ]] || die "AppImage 不应包含无关的 MySQL Qt SQL 插件。"
[[ -f "$VERIFY_ROOT/usr/translations/qtbase_zh_CN.qm" ]] || die "提取后的 AppImage 缺少 Qt5 简体中文翻译。"

grep -Fxq 'export LANG=zh_CN.UTF-8' "$VERIFY_ROOT/AppRun.wrapped" || die "AppRun.wrapped 缺少中文 LANG。"
grep -Fxq 'export LANGUAGE=zh_CN:zh' "$VERIFY_ROOT/AppRun.wrapped" || die "AppRun.wrapped 缺少中文 LANGUAGE。"
grep -Fxq 'export QT_QPA_PLATFORM=xcb' "$VERIFY_ROOT/AppRun.wrapped" || die "AppRun.wrapped 没有固定使用 xcb。"

for required_lib in \
  libxcb-icccm.so.4 libxcb-image.so.0 libxcb-keysyms.so.1 libxcb-render-util.so.0 \
  libxcb-xkb.so.1 libxkbcommon-x11.so.0; do
  find "$VERIFY_ROOT/usr/lib" -maxdepth 1 \( -type f -o -type l \) -name "$required_lib*" -print -quit | grep -q . || \
    die "AppImage 缺少 XCB 运行依赖：$required_lib"
done

mapfile -d '' desktop_files < <(find "$VERIFY_ROOT" -maxdepth 1 \( -type f -o -type l \) -name '*.desktop' -print0)
[[ ${#desktop_files[@]} -ge 1 ]] || die "提取后的 AppImage 根目录没有 desktop 文件。"
for desktop_file in "${desktop_files[@]}"; do
  desktop-file-validate "$desktop_file"
done

BUNDLE_LD_LIBRARY_PATH="$VERIFY_ROOT/opt/XnConvert:$VERIFY_ROOT/opt/XnConvert/lib:$VERIFY_ROOT/opt/XnConvert/Plugins:$VERIFY_ROOT/opt/XnConvert/qml:$VERIFY_ROOT/usr/lib"
LD_LIBRARY_PATH="$BUNDLE_LD_LIBRARY_PATH" ldd "$VERIFY_ROOT/opt/XnConvert/lib/platforms/libqxcb.so" > "$LDD_LOG"
cat "$LDD_LOG"
if grep -q 'not found' "$LDD_LOG"; then
  die "打包后的官方 qxcb 插件仍有动态库缺失。"
fi

log "在隔离 HOME / XDG 目录中执行 Xvfb 冒烟测试"
mkdir -p "$SMOKE_HOME" "$SMOKE_CONFIG" "$SMOKE_CACHE" "$SMOKE_RUNTIME"
chmod 0700 "$SMOKE_RUNTIME"

set +e
HOME="$SMOKE_HOME" \
XDG_CONFIG_HOME="$SMOKE_CONFIG" \
XDG_CACHE_HOME="$SMOKE_CACHE" \
XDG_RUNTIME_DIR="$SMOKE_RUNTIME" \
APPIMAGE_EXTRACT_AND_RUN=1 \
timeout 30s xvfb-run -a "$OUTFILE" >"$SMOKE_LOG" 2>&1
smoke_rc=$?
set -e

cat "$SMOKE_LOG"
printf 'XnConvert smoke exit code: %s\n' "$smoke_rc"

if grep -Eqi \
  'Segmentation fault|Aborted|error while loading shared libraries|Cannot mix incompatible Qt libraries|Could not load the Qt platform plugin|no Qt platform plugin could be initialized|GLIBC_[0-9.]+.*not found' \
  "$SMOKE_LOG"; then
  die "XnConvert 冒烟测试检测到致命运行时错误。"
fi

if [[ "$smoke_rc" -ne 0 && "$smoke_rc" -ne 124 ]]; then
  die "XnConvert 在冒烟测试期间异常退出：$smoke_rc"
fi

log "构建验证完成"
sha256sum "$OUTFILE"
