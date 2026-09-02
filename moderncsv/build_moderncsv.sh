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
QUICK_SHARUN="$WORK_DIR/quick-sharun"
DESKTOP_FILE="$WORK_DIR/moderncsv.desktop"

rm -rf "$WORK_DIR" "$APPDIR" "$DIST_DIR"
mkdir -p "$WORK_DIR" "$APPDIR" "$DIST_DIR"

if command -v sudo >/dev/null 2>&1; then
  APT=(sudo apt-get)
else
  APT=(apt-get)
fi

"${APT[@]}" update
DEBIAN_FRONTEND=noninteractive "${APT[@]}" install -y --no-install-recommends \
  build-essential binutils ca-certificates coreutils curl dbus-x11 desktop-file-utils \
  file findutils gawk grep gzip patchelf sed tar wget xauth xvfb zsync \
  qt6-base-dev libqt6network6t64 \
  fcitx5-frontend-qt6 libfcitx5-qt6-1 libfcitx5utils2 \
  libssl3t64

for command_name in awk cc curl desktop-file-validate file find grep ldd patchelf readlink sed sha256sum sort strings tar timeout wget xvfb-run; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "错误：缺少构建命令：$command_name" >&2
    exit 1
  }
done

###### 动态解析并下载官方稳定版 ######

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

###### 解包并核对官方 Qt6 运行时 ######

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
[[ -d "$SOURCE_DIR/lib" ]] || {
  echo "错误：官方归档缺少 Qt 运行库目录 lib。" >&2
  exit 1
}
find "$SOURCE_DIR/lib" \( -type f -o -type l \) -name 'libQt6Core.so*' -print -quit | grep -q . || {
  echo "错误：官方归档未检测到 Qt6Core。" >&2
  exit 1
}
if find "$SOURCE_DIR/lib" \( -type f -o -type l \) -name 'libQt5*.so*' -print -quit | grep -q .; then
  echo "错误：官方主运行库目录检测到 Qt5，停止构建，避免 Qt5/Qt6 混装。" >&2
  exit 1
fi

MAIN_LDD="$(LD_LIBRARY_PATH="$SOURCE_DIR/lib" ldd "$SOURCE_DIR/moderncsv")"
printf '%s\n' "$MAIN_LDD"
if grep -Fq 'not found' <<<"$MAIN_LDD"; then
  echo "错误：Modern CSV 官方程序存在缺失动态库。" >&2
  exit 1
fi
if grep -Fq 'libQt5' <<<"$MAIN_LDD"; then
  echo "错误：Modern CSV 主程序解析到了 Qt5 运行库。" >&2
  exit 1
fi
grep -Fq 'libQt6Core.so.6' <<<"$MAIN_LDD" || {
  echo "错误：Modern CSV 主程序没有解析到 Qt6Core。" >&2
  exit 1
}

###### 准备 Qt6 plugin 来源、desktop 与图标 ######

SYSTEM_QXCB="$(find /usr/lib -type f -path '*/qt6/plugins/platforms/libqxcb.so' -print -quit)"
[[ -f "$SYSTEM_QXCB" ]] || {
  echo "错误：找不到系统 Qt6 XCB platform plugin。" >&2
  exit 1
}
QT_LOCATION="$(dirname "$(dirname "$(dirname "$SYSTEM_QXCB")")")"
[[ -d "$QT_LOCATION/plugins" ]] || {
  echo "错误：Qt6 plugin 根目录不存在：$QT_LOCATION/plugins" >&2
  exit 1
}

SYSTEM_FCITX="$(find "$QT_LOCATION/plugins/platforminputcontexts" -type f -name 'libfcitx5platforminputcontextplugin.so' -print -quit 2>/dev/null || true)"
[[ -f "$SYSTEM_FCITX" ]] || {
  echo "错误：找不到 Fcitx5 Qt6 platform input context plugin。" >&2
  exit 1
}

SYSTEM_TLS="$(find "$QT_LOCATION/plugins/tls" -type f -name 'libqopensslbackend.so' -print -quit 2>/dev/null || true)"
[[ -f "$SYSTEM_TLS" ]] || {
  echo "错误：找不到 Qt6 OpenSSL TLS backend plugin。" >&2
  exit 1
}

for plugin in "$SYSTEM_QXCB" "$SYSTEM_FCITX" "$SYSTEM_TLS"; do
  PLUGIN_LDD="$(LD_LIBRARY_PATH="$SOURCE_DIR/lib" ldd "$plugin")"
  printf '%s\n' "$PLUGIN_LDD"
  if grep -Fq 'not found' <<<"$PLUGIN_LDD"; then
    echo "错误：Qt6 plugin 存在缺失动态库：$plugin" >&2
    exit 1
  fi
  if grep -Fq 'libQt5' <<<"$PLUGIN_LDD"; then
    echo "错误：Qt6 plugin 错误解析到了 Qt5：$plugin" >&2
    exit 1
  fi
done

cp -a "$SOURCE_DIR/moderncsv.desktop" "$DESKTOP_FILE"
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
  echo "错误：无法规范化 desktop 文件的 Exec 字段。" >&2
  exit 1
}
desktop-file-validate "$DESKTOP_FILE"

ICON_SOURCE="$SOURCE_DIR/moderncsv.png"
if [[ ! -f "$ICON_SOURCE" ]]; then
  ICON_SOURCE="$(find "$SOURCE_DIR/icons/hicolor" -type f \( -iname 'moderncsv.png' -o -iname 'moderncsv.svg' \) -print 2>/dev/null | sort -V | tail -n 1)"
fi
[[ -f "$ICON_SOURCE" ]] || {
  echo "错误：找不到 Modern CSV 图标。" >&2
  exit 1
}

###### 使用 quick-sharun 构建标准 AppDir ######

curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/quick-sharun.sh \
  -o "$QUICK_SHARUN"
chmod +x "$QUICK_SHARUN"
bash -n "$QUICK_SHARUN"

export APPDIR
export OUTPATH="$DIST_DIR"
export OUTNAME="moderncsv.AppImage"
export MAIN_BIN="moderncsv"
export DESKTOP="$DESKTOP_FILE"
export ICON="$ICON_SOURCE"
export DEPLOY_QT=1
export QT_DIR=qt6
export QT_LOCATION
export STRACE_BINARY=moderncsv
export STRACE_TIME=8

LD_LIBRARY_PATH="$SOURCE_DIR/lib" \
QT_QPA_PLATFORM=xcb \
QT_IM_MODULE=fcitx \
  "$QUICK_SHARUN" "$SOURCE_DIR/moderncsv"

test -x "$APPDIR/bin/moderncsv"
test -x "$APPDIR/shared/bin/moderncsv"
test -f "$APPDIR/bin/qt.conf"
test ! -e "$APPDIR/usr/bin/moderncsv"
find "$APPDIR/lib" \( -type f -o -type l \) -name 'libQt6Core.so*' -print -quit | grep -q .
find "$APPDIR/lib/qt6/plugins/platforms" -type f -name 'libqxcb.so' -print -quit | grep -q .
find "$APPDIR/lib/qt6/plugins/platforminputcontexts" -type f -name 'libfcitx5platforminputcontextplugin.so' -print -quit | grep -q .
find "$APPDIR/lib/qt6/plugins/tls" -type f -name 'libqopensslbackend.so' -print -quit | grep -q .
if find "$APPDIR" \( -type f -o -type l \) -name 'libQt5*.so*' -print -quit | grep -q .; then
  echo "错误：quick-sharun AppDir 中检测到 Qt5 运行库。" >&2
  exit 1
fi

# 中文 locale 与 XCB 只写入 sharun 的 .env，不再生成 usr/bin/moderncsv 手写启动 wrapper。
for env_line in \
  'LANG=zh_CN.UTF-8' \
  'LANGUAGE=zh_CN:zh' \
  'QT_QPA_PLATFORM=xcb'; do
  env_key="${env_line%%=*}"
  if [[ -f "$APPDIR/.env" ]]; then
    sed -i "/^${env_key}=/d" "$APPDIR/.env"
  fi
  printf '%s\n' "$env_line" >> "$APPDIR/.env"
done

if grep -Fq 'QT_PLUGIN_PATH=' "$APPDIR/.env"; then
  echo "错误：AppDir .env 不应使用 QT_PLUGIN_PATH；Qt plugin 应由 quick-sharun 生成的 qt.conf 定位。" >&2
  exit 1
fi

"$QUICK_SHARUN" --make-appimage

test -s "$OUTFILE"
chmod +x "$OUTFILE"
file "$OUTFILE" | grep -q 'ELF 64-bit'

###### 最终 AppImage 结构与启动验证 ######

VERIFY_DIR="$WORK_DIR/verify-appimage"
rm -rf "$VERIFY_DIR"
mkdir -p "$VERIFY_DIR"
(
  cd "$VERIFY_DIR"
  "$OUTFILE" --appimage-extract >/dev/null
)
VERIFY_ROOT="$VERIFY_DIR/squashfs-root"

test -x "$VERIFY_ROOT/AppRun"
test -x "$VERIFY_ROOT/bin/moderncsv"
test -x "$VERIFY_ROOT/shared/bin/moderncsv"
test -f "$VERIFY_ROOT/bin/qt.conf"
test ! -e "$VERIFY_ROOT/usr/bin/moderncsv"
test -f "$VERIFY_ROOT/.env"
find "$VERIFY_ROOT/lib" \( -type f -o -type l \) -name 'libQt6Core.so*' -print -quit | grep -q .
find "$VERIFY_ROOT/lib/qt6/plugins/platforms" -type f -name 'libqxcb.so' -print -quit | grep -q .
find "$VERIFY_ROOT/lib/qt6/plugins/platforminputcontexts" -type f -name 'libfcitx5platforminputcontextplugin.so' -print -quit | grep -q .
find "$VERIFY_ROOT/lib/qt6/plugins/tls" -type f -name 'libqopensslbackend.so' -print -quit | grep -q .
if find "$VERIFY_ROOT" \( -type f -o -type l \) -name 'libQt5*.so*' -print -quit | grep -q .; then
  echo "错误：最终 AppImage 中检测到 Qt5 运行库。" >&2
  exit 1
fi

grep -Fqx 'LANG=zh_CN.UTF-8' "$VERIFY_ROOT/.env"
grep -Fqx 'LANGUAGE=zh_CN:zh' "$VERIFY_ROOT/.env"
grep -Fqx 'QT_QPA_PLATFORM=xcb' "$VERIFY_ROOT/.env"
if grep -Fq 'QT_PLUGIN_PATH=' "$VERIFY_ROOT/.env"; then
  echo "错误：最终 AppImage .env 中不应存在 QT_PLUGIN_PATH。" >&2
  exit 1
fi

grep -Fqx 'Version=1.0' "$VERIFY_ROOT/moderncsv.desktop"
grep -Eq '^Exec=moderncsv([[:space:]]|$)' "$VERIFY_ROOT/moderncsv.desktop"

SMOKE_HOME="$WORK_DIR/smoke-home"
SMOKE_LOG="$WORK_DIR/smoke.log"
mkdir -p "$SMOKE_HOME"

set +e
HOME="$SMOKE_HOME" \
QT_IM_MODULE=fcitx \
QT_DEBUG_PLUGINS=1 \
APPIMAGE_EXTRACT_AND_RUN=1 \
timeout 20s xvfb-run -a "$OUTFILE" >"$SMOKE_LOG" 2>&1
SMOKE_RC=$?
set -e

cat "$SMOKE_LOG"

if grep -Eqi \
  'Plugin uses incompatible Qt library|libQt5|No functional TLS backend was found|No TLS backend is available|TLS initialization failed|Could not load the Qt platform plugin|no Qt platform plugin could be initialized|error while loading shared libraries|Cannot load library.*libfcitx5platforminputcontextplugin|Segmentation fault|Aborted' \
  "$SMOKE_LOG"; then
  echo "错误：最终 AppImage 启动 smoke test 检测到 Qt / Fcitx5 / TLS / 动态库错误。" >&2
  exit 1
fi

grep -Fq 'libfcitx5platforminputcontextplugin.so' "$SMOKE_LOG"
[[ "$SMOKE_RC" -eq 0 || "$SMOKE_RC" -eq 124 ]]

sha256sum "$OUTFILE"
