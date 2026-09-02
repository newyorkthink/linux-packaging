#!/usr/bin/env bash
set -Eeuo pipefail

###### 初始化与构建环境 ######

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

WORK_DIR="$SCRIPT_DIR/.work"
APPDIR="$SCRIPT_DIR/AppDir"
DIST_DIR="$SCRIPT_DIR/dist"
OUTFILE="$DIST_DIR/moderncsv.AppImage"
ARCHIVE="$WORK_DIR/ModernCSV-Linux.tar.gz"
APPIMAGETOOL="$WORK_DIR/appimagetool-x86_64.AppImage"

rm -rf "$WORK_DIR" "$APPDIR" "$DIST_DIR"
mkdir -p "$WORK_DIR" "$APPDIR" "$DIST_DIR"

if command -v sudo >/dev/null 2>&1; then
  APT=(sudo apt-get)
else
  APT=(apt-get)
fi

"${APT[@]}" update
DEBIAN_FRONTEND=noninteractive "${APT[@]}" install -y --no-install-recommends \
  ca-certificates coreutils curl desktop-file-utils file findutils grep gzip sed tar \
  fcitx5-frontend-qt6 libfcitx5-qt6-1 libfcitx5utils2 \
  libx11-xcb1 libxcb-cursor0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
  libxcb-randr0 libxcb-render-util0 libxcb-render0 libxcb-shape0 libxcb-shm0 \
  libxcb-sync1 libxcb-util1 libxcb-xfixes0 libxcb-xinerama0 libxcb-xkb1 libxcb1 \
  libxkbcommon-x11-0 libxkbcommon0

for command_name in awk curl desktop-file-validate dpkg file find grep head ldd ldconfig readlink sed sha256sum sort tail tar; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "错误：缺少构建命令：$command_name" >&2
    exit 1
  }
done

###### 动态解析并下载官方稳定版 ######

# 官方 release 目录只选择形如 ModernCSV-Linux-v<数字版本>.tar.gz 的稳定版 Linux 归档。
RELEASE_INDEX="$WORK_DIR/release-index.html"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  --max-time 60 \
  https://www.moderncsv.com/release/ \
  -o "$RELEASE_INDEX"

mapfile -t RELEASE_ASSETS < <(
  grep -oE 'ModernCSV-Linux-v[0-9]+([.][0-9]+)+[.]tar[.]gz' "$RELEASE_INDEX" \
    | sort -uV
)
[[ "${#RELEASE_ASSETS[@]}" -gt 0 ]] || {
  echo "错误：官方 release 目录中没有找到稳定版 Linux 归档。" >&2
  exit 1
}

LATEST_ASSET="${RELEASE_ASSETS[${#RELEASE_ASSETS[@]}-1]}"
VERSION="${LATEST_ASSET#ModernCSV-Linux-v}"
VERSION="${VERSION%.tar.gz}"
[[ "$VERSION" =~ ^[0-9]+([.][0-9]+)+$ ]] || {
  echo "错误：解析出的 Modern CSV 版本格式异常：$VERSION" >&2
  exit 1
}

DOWNLOAD_URL="https://www.moderncsv.com/release/$LATEST_ASSET"
[[ "$DOWNLOAD_URL" =~ ^https://www[.]moderncsv[.]com/release/ModernCSV-Linux-v[0-9]+([.][0-9]+)+[.]tar[.]gz$ ]] || {
  echo "错误：Modern CSV 下载地址未通过域名和文件名校验：$DOWNLOAD_URL" >&2
  exit 1
}

printf 'Modern CSV stable version: %s\n' "$VERSION"
printf 'Modern CSV source: %s\n' "$DOWNLOAD_URL"

curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  "$DOWNLOAD_URL" \
  -o "$ARCHIVE"

tar -tzf "$ARCHIVE" >/dev/null
SOURCE_SHA256="$(sha256sum "$ARCHIVE" | awk '{print $1}')"
printf 'Modern CSV source SHA-256: %s\n' "$SOURCE_SHA256"
printf '%s\n' "$VERSION" > "$DIST_DIR/version.txt"
printf '%s  %s\n' "$SOURCE_SHA256" "$LATEST_ASSET" > "$DIST_DIR/source.sha256"

###### 解包并准备 AppDir ######

SOURCE_PARENT="$WORK_DIR/source"
mkdir -p "$SOURCE_PARENT"
tar -xzf "$ARCHIVE" -C "$SOURCE_PARENT"

mapfile -d '' -t SOURCE_DIRS < <(
  find "$SOURCE_PARENT" -mindepth 1 -maxdepth 1 -type d -name 'moderncsv*' -print0
)
[[ "${#SOURCE_DIRS[@]}" -eq 1 ]] || {
  echo "错误：官方归档顶层 moderncsv 目录数量异常：${#SOURCE_DIRS[@]}" >&2
  exit 1
}
SOURCE_DIR="${SOURCE_DIRS[0]}"

[[ -x "$SOURCE_DIR/moderncsv" ]] || {
  echo "错误：官方归档缺少 moderncsv 可执行文件。" >&2
  exit 1
}
[[ -f "$SOURCE_DIR/moderncsv.desktop" ]] || {
  echo "错误：官方归档缺少 moderncsv.desktop。" >&2
  exit 1
}
[[ -d "$SOURCE_DIR/icons/hicolor" ]] || {
  echo "错误：官方归档缺少 icons/hicolor。" >&2
  exit 1
}

# 保留官方程序本体和资源的原始相对布局。
mkdir -p "$APPDIR/opt/moderncsv"
cp -a "$SOURCE_DIR/." "$APPDIR/opt/moderncsv/"

###### 接入 Qt6 中文输入环境 ######

mapfile -d '' -t QT6_CORE_FILES < <(
  find "$APPDIR/opt/moderncsv" \( -type f -o -type l \) -name 'libQt6Core.so*' -print0
)
[[ "${#QT6_CORE_FILES[@]}" -gt 0 ]] || {
  echo "错误：当前官方稳定版未检测到 Qt6Core；为避免错误混用 Qt 输入法插件，本次构建停止。" >&2
  exit 1
}
QT_LIB_DIR="$(dirname "${QT6_CORE_FILES[0]}")"
QT_LIB_DIR_REL="${QT_LIB_DIR#"$APPDIR"/}"

mapfile -d '' -t QXCB_PLUGINS < <(
  find "$APPDIR/opt/moderncsv" \( -type f -o -type l \) -name 'libqxcb.so' -print0
)
[[ "${#QXCB_PLUGINS[@]}" -gt 0 ]] || {
  echo "错误：当前官方稳定版未找到 Qt XCB platform plugin。" >&2
  exit 1
}
QXCB_PLUGIN="${QXCB_PLUGINS[0]}"
QT_PLATFORM_DIR="$(dirname "$QXCB_PLUGIN")"
QT_PLUGIN_ROOT="$(dirname "$QT_PLATFORM_DIR")"
QT_PLATFORM_DIR_REL="${QT_PLATFORM_DIR#"$APPDIR"/}"
QT_PLUGIN_ROOT_REL="${QT_PLUGIN_ROOT#"$APPDIR"/}"

FCITX_PLUGIN="$(
  dpkg -L fcitx5-frontend-qt6 \
    | awk '/\/platforminputcontexts\/libfcitx5platforminputcontextplugin[.]so$/ && !found {print; found=1}'
)"
[[ -f "$FCITX_PLUGIN" ]] || {
  echo "错误：找不到 Fcitx5 Qt6 platform input context plugin。" >&2
  exit 1
}

mkdir -p "$QT_PLUGIN_ROOT/platforminputcontexts" "$APPDIR/usr/lib" "$APPDIR/usr/bin"
cp -a "$FCITX_PLUGIN" "$QT_PLUGIN_ROOT/platforminputcontexts/"

copy_runtime_library() {
  local soname="$1"
  local source_path target_path target_name
  source_path="$(ldconfig -p | awk -v name="$soname" '$1 == name && !found {print $NF; found=1}')"
  [[ -n "$source_path" && -e "$source_path" ]] || {
    echo "错误：找不到运行库：$soname" >&2
    exit 1
  }
  target_path="$(readlink -f "$source_path")"
  target_name="$(basename "$target_path")"
  cp -a "$target_path" "$APPDIR/usr/lib/$target_name"
  if [[ "$target_name" != "$soname" ]]; then
    ln -sf "$target_name" "$APPDIR/usr/lib/$soname"
  fi
}

# 只补 Fcitx5 Qt6 插件自身需要、且不应替换 Modern CSV 自带 Qt6 的运行库。
copy_runtime_library libFcitx5Qt6DBusAddons.so.1
copy_runtime_library libFcitx5Utils.so.2

# Qt XCB plugin 会依赖一组并非所有 Linux 桌面默认安装的 XCB helper。
# 这些库必须随 AppImage 提供，避免构建机有库而目标 Linux 实机缺库时出现
# “Could not load the Qt platform plugin "xcb" ... even though it was found”。
for qxcb_runtime in \
  libX11-xcb.so.1 \
  libxcb-cursor.so.0 \
  libxcb-icccm.so.4 \
  libxcb-image.so.0 \
  libxcb-keysyms.so.1 \
  libxcb-randr.so.0 \
  libxcb-render-util.so.0 \
  libxcb-render.so.0 \
  libxcb-shape.so.0 \
  libxcb-shm.so.0 \
  libxcb-sync.so.1 \
  libxcb-util.so.1 \
  libxcb-xfixes.so.0 \
  libxcb-xinerama.so.0 \
  libxcb-xkb.so.1 \
  libxcb.so.1 \
  libxkbcommon-x11.so.0 \
  libxkbcommon.so.0; do
  copy_runtime_library "$qxcb_runtime"
done

cat > "$APPDIR/usr/bin/moderncsv" <<EOF_WRAPPER
#!/usr/bin/env bash
set -Eeuo pipefail

HERE="\$(dirname "\$(readlink -f "\$0")")"
ROOT="\$(readlink -f "\$HERE/../..")"

export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export QT_QPA_PLATFORM=xcb
export QT_PLUGIN_PATH="\$ROOT/$QT_PLUGIN_ROOT_REL\${QT_PLUGIN_PATH:+:\$QT_PLUGIN_PATH}"
export QT_QPA_PLATFORM_PLUGIN_PATH="\$ROOT/$QT_PLATFORM_DIR_REL"
export LD_LIBRARY_PATH="\$ROOT/$QT_LIB_DIR_REL:\$ROOT/usr/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"

exec "\$ROOT/opt/moderncsv/moderncsv" "\$@"
EOF_WRAPPER
chmod +x "$APPDIR/usr/bin/moderncsv"

cat > "$APPDIR/AppRun" <<'EOF_APPRUN'
#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(dirname "$(readlink -f "$0")")"
exec "$ROOT/usr/bin/moderncsv" "$@"
EOF_APPRUN
chmod +x "$APPDIR/AppRun"

###### 准备桌面文件与图标 ######

mkdir -p "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor"
DESKTOP_FILE="$APPDIR/usr/share/applications/moderncsv.desktop"
cp -a "$APPDIR/opt/moderncsv/moderncsv.desktop" "$DESKTOP_FILE"

# 上游/AUR 当前使用 /opt/moderncsv/moderncsv；AppImage 内改为调用自身 wrapper，并继续强制 XCB。
# Desktop Entry 的 Version 表示规范版本而不是应用版本；上游写入应用版本时统一规范化为 1.0。
sed -E -i \
  -e 's|^Version=.*|Version=1.0|' \
  -e 's|^Exec=(env QT_QPA_PLATFORM=xcb )?/opt/moderncsv/moderncsv|Exec=moderncsv|' \
  -e 's|^Icon=.*|Icon=moderncsv|' \
  "$DESKTOP_FILE"
grep -Eq '^Version=1[.]0$' "$DESKTOP_FILE" || {
  echo "错误：无法规范化 desktop 文件的 Version 字段。" >&2
  exit 1
}
grep -Eq '^Exec=moderncsv([[:space:]]|$)' "$DESKTOP_FILE" || {
  echo "错误：无法识别上游 desktop 文件的 Exec 格式。" >&2
  exit 1
}
desktop-file-validate "$DESKTOP_FILE"
cp -a "$DESKTOP_FILE" "$APPDIR/moderncsv.desktop"
cp -a "$APPDIR/opt/moderncsv/icons/hicolor/." "$APPDIR/usr/share/icons/hicolor/"

ICON_SOURCE="$(
  find "$APPDIR/opt/moderncsv/icons/hicolor" -type f \
    \( -iname 'moderncsv.png' -o -iname 'moderncsv.svg' \) \
    -print \
    | sort -V \
    | tail -n 1
)"
[[ -f "$ICON_SOURCE" ]] || {
  echo "错误：找不到 Modern CSV 图标。" >&2
  exit 1
}
ICON_EXT="${ICON_SOURCE##*.}"
cp -a "$ICON_SOURCE" "$APPDIR/moderncsv.$ICON_EXT"
ln -s "moderncsv.$ICON_EXT" "$APPDIR/.DirIcon"

###### 输入法与动态库验证 ######

BUNDLED_FCITX_PLUGIN="$QT_PLUGIN_ROOT/platforminputcontexts/libfcitx5platforminputcontextplugin.so"
test -f "$BUNDLED_FCITX_PLUGIN"

MAIN_LDD="$(LD_LIBRARY_PATH="$QT_LIB_DIR:$APPDIR/usr/lib" ldd "$APPDIR/opt/moderncsv/moderncsv")"
printf '%s\n' "$MAIN_LDD"
if grep -Fq 'not found' <<<"$MAIN_LDD"; then
  echo "错误：Modern CSV 主程序存在缺失动态库。" >&2
  exit 1
fi

FCITX_LDD="$(LD_LIBRARY_PATH="$QT_LIB_DIR:$APPDIR/usr/lib" ldd "$BUNDLED_FCITX_PLUGIN")"
printf '%s\n' "$FCITX_LDD"
if grep -Fq 'not found' <<<"$FCITX_LDD"; then
  echo "错误：Fcitx5 Qt6 输入法插件存在缺失动态库。" >&2
  exit 1
fi

QXCB_LDD="$(LD_LIBRARY_PATH="$QT_LIB_DIR:$APPDIR/usr/lib" ldd "$QXCB_PLUGIN")"
printf '%s\n' "$QXCB_LDD"
if grep -Fq 'not found' <<<"$QXCB_LDD"; then
  echo "错误：Qt XCB platform plugin 存在缺失动态库。" >&2
  exit 1
fi

# 不能只要求 ldd “not found=0”：构建机自己的 /usr/lib 也可能让检查误通过。
# 对 XCB helper 依赖逐项确认，只要 qxcb 实际需要，就必须解析到当前 AppDir。
for qxcb_runtime in \
  libX11-xcb.so.1 \
  libxcb-cursor.so.0 \
  libxcb-icccm.so.4 \
  libxcb-image.so.0 \
  libxcb-keysyms.so.1 \
  libxcb-randr.so.0 \
  libxcb-render-util.so.0 \
  libxcb-render.so.0 \
  libxcb-shape.so.0 \
  libxcb-shm.so.0 \
  libxcb-sync.so.1 \
  libxcb-util.so.1 \
  libxcb-xfixes.so.0 \
  libxcb-xinerama.so.0 \
  libxcb-xkb.so.1 \
  libxcb.so.1 \
  libxkbcommon-x11.so.0 \
  libxkbcommon.so.0; do
  resolved_path="$(awk -v name="$qxcb_runtime" '$1 == name {print $3; exit}' <<<"$QXCB_LDD")"
  if [[ -n "$resolved_path" && "$resolved_path" != "$APPDIR/usr/lib/"* && "$resolved_path" != "$QT_LIB_DIR/"* ]]; then
    echo "错误：Qt XCB 依赖仍借用了构建机运行库：$qxcb_runtime => $resolved_path" >&2
    exit 1
  fi
done

###### 核心打包 ######

curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage \
  -o "$APPIMAGETOOL"
chmod +x "$APPIMAGETOOL"

ARCH=x86_64 \
VERSION="$VERSION" \
APPIMAGE_EXTRACT_AND_RUN=1 \
  "$APPIMAGETOOL" "$APPDIR" "$OUTFILE"

###### 测试与验证 ######

chmod +x "$OUTFILE"
test -s "$OUTFILE"
file "$OUTFILE" | grep -q 'ELF 64-bit'

VERIFY_DIR="$WORK_DIR/verify-appimage"
rm -rf "$VERIFY_DIR"
mkdir -p "$VERIFY_DIR"
(
  cd "$VERIFY_DIR"
  "$OUTFILE" --appimage-extract >/dev/null
)
VERIFY_ROOT="$VERIFY_DIR/squashfs-root"

test -x "$VERIFY_ROOT/AppRun"
test -x "$VERIFY_ROOT/usr/bin/moderncsv"
test -x "$VERIFY_ROOT/opt/moderncsv/moderncsv"
test -f "$VERIFY_ROOT/$QT_PLUGIN_ROOT_REL/platforminputcontexts/libfcitx5platforminputcontextplugin.so"
test -e "$VERIFY_ROOT/usr/lib/libFcitx5Qt6DBusAddons.so.1"
test -e "$VERIFY_ROOT/usr/lib/libFcitx5Utils.so.2"
test -e "$VERIFY_ROOT/usr/lib/libxcb-xinerama.so.0"
test -e "$VERIFY_ROOT/usr/lib/libxcb-icccm.so.4"
test -e "$VERIFY_ROOT/usr/lib/libxcb-image.so.0"
test -e "$VERIFY_ROOT/usr/lib/libxcb-keysyms.so.1"
test -e "$VERIFY_ROOT/usr/lib/libxcb-render-util.so.0"
test -e "$VERIFY_ROOT/usr/lib/libxcb-xkb.so.1"
test -e "$VERIFY_ROOT/usr/lib/libxkbcommon-x11.so.0"
grep -Fqx 'export LANG=zh_CN.UTF-8' "$VERIFY_ROOT/usr/bin/moderncsv"
grep -Fqx 'export LANGUAGE=zh_CN:zh' "$VERIFY_ROOT/usr/bin/moderncsv"
grep -Fqx 'export QT_QPA_PLATFORM=xcb' "$VERIFY_ROOT/usr/bin/moderncsv"
grep -Fqx 'Version=1.0' "$VERIFY_ROOT/moderncsv.desktop"

VERIFY_MAIN_LDD="$(LD_LIBRARY_PATH="$VERIFY_ROOT/$QT_LIB_DIR_REL:$VERIFY_ROOT/usr/lib" ldd "$VERIFY_ROOT/opt/moderncsv/moderncsv")"
if grep -Fq 'not found' <<<"$VERIFY_MAIN_LDD"; then
  echo "错误：最终 AppImage 中 Modern CSV 主程序存在缺失动态库。" >&2
  printf '%s\n' "$VERIFY_MAIN_LDD" >&2
  exit 1
fi

VERIFY_FCITX_LDD="$(LD_LIBRARY_PATH="$VERIFY_ROOT/$QT_LIB_DIR_REL:$VERIFY_ROOT/usr/lib" ldd "$VERIFY_ROOT/$QT_PLUGIN_ROOT_REL/platforminputcontexts/libfcitx5platforminputcontextplugin.so")"
if grep -Fq 'not found' <<<"$VERIFY_FCITX_LDD"; then
  echo "错误：最终 AppImage 中 Fcitx5 Qt6 输入法插件存在缺失动态库。" >&2
  printf '%s\n' "$VERIFY_FCITX_LDD" >&2
  exit 1
fi

VERIFY_QXCB_PLUGIN="$VERIFY_ROOT/$QT_PLATFORM_DIR_REL/libqxcb.so"
test -f "$VERIFY_QXCB_PLUGIN"
VERIFY_QXCB_LDD="$(LD_LIBRARY_PATH="$VERIFY_ROOT/$QT_LIB_DIR_REL:$VERIFY_ROOT/usr/lib" ldd "$VERIFY_QXCB_PLUGIN")"
printf '%s\n' "$VERIFY_QXCB_LDD"
if grep -Fq 'not found' <<<"$VERIFY_QXCB_LDD"; then
  echo "错误：最终 AppImage 中 Qt XCB platform plugin 存在缺失动态库。" >&2
  exit 1
fi

for qxcb_runtime in \
  libX11-xcb.so.1 \
  libxcb-cursor.so.0 \
  libxcb-icccm.so.4 \
  libxcb-image.so.0 \
  libxcb-keysyms.so.1 \
  libxcb-randr.so.0 \
  libxcb-render-util.so.0 \
  libxcb-render.so.0 \
  libxcb-shape.so.0 \
  libxcb-shm.so.0 \
  libxcb-sync.so.1 \
  libxcb-util.so.1 \
  libxcb-xfixes.so.0 \
  libxcb-xinerama.so.0 \
  libxcb-xkb.so.1 \
  libxcb.so.1 \
  libxkbcommon-x11.so.0 \
  libxkbcommon.so.0; do
  resolved_path="$(awk -v name="$qxcb_runtime" '$1 == name {print $3; exit}' <<<"$VERIFY_QXCB_LDD")"
  if [[ -n "$resolved_path" && "$resolved_path" != "$VERIFY_ROOT/usr/lib/"* && "$resolved_path" != "$VERIFY_ROOT/$QT_LIB_DIR_REL/"* ]]; then
    echo "错误：最终 AppImage 的 Qt XCB 依赖仍借用了宿主运行库：$qxcb_runtime => $resolved_path" >&2
    exit 1
  fi
done

###### 整理产物 ######

sha256sum "$OUTFILE"
