#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

###### quick-sharun 构建环境 ######

if [[ ! -e /etc/arch-release ]]; then
  if [[ "${GITHUB_ACTIONS:-}" == "true" && -n "${GITHUB_WORKSPACE:-}" ]] && command -v docker >/dev/null 2>&1; then
    exec docker run --rm \
      -e CI="${CI:-true}" \
      -e GITHUB_ACTIONS=true \
      -e GITHUB_WORKSPACE=/workspace \
      -v "$GITHUB_WORKSPACE:/workspace" \
      -w /workspace/moderncsv \
      ghcr.io/pkgforge-dev/archlinux:latest \
      bash ./build_moderncsv.sh
  fi

  echo "错误：Modern CSV 使用 quick-sharun 打包，实际打包阶段必须在 Arch Linux 环境运行。" >&2
  exit 1
fi

if [[ "$EUID" -eq 0 ]]; then
  PACMAN=(pacman)
else
  command -v sudo >/dev/null 2>&1 || {
    echo "错误：当前 Arch Linux 构建环境不是 root，且缺少 sudo。" >&2
    exit 1
  }
  PACMAN=(sudo pacman)
fi

"${PACMAN[@]}" -Syu --noconfirm --needed \
  base-devel binutils ca-certificates curl dbus desktop-file-utils file findutils gawk git grep gzip patchelf sed strace tar wget \
  xorg-xauth xorg-server-xvfb zsync \
  qt6-base fcitx5-qt openssl

WORK_DIR="$SCRIPT_DIR/.work"
APPDIR="$SCRIPT_DIR/AppDir"
DIST_DIR="$SCRIPT_DIR/dist"

rm -rf "$WORK_DIR" "$APPDIR" "$DIST_DIR"
mkdir -p "$WORK_DIR" "$DIST_DIR"

###### 下载并解包官方稳定版 ######

RELEASE_INDEX="$WORK_DIR/release-index.html"
curl -fsSL https://www.moderncsv.com/release/ -o "$RELEASE_INDEX"

ASSET="$(grep -oE 'ModernCSV-Linux-v[0-9]+([.][0-9]+)+[.]tar[.]gz' "$RELEASE_INDEX" | sort -uV | tail -n 1)"
[[ -n "$ASSET" ]] || {
  echo "错误：没有从 Modern CSV 官方 Release 目录解析到 Linux 稳定版。" >&2
  exit 1
}

VERSION="${ASSET#ModernCSV-Linux-v}"
VERSION="${VERSION%.tar.gz}"
ARCHIVE="$WORK_DIR/$ASSET"

curl -fL --retry 3 "https://www.moderncsv.com/release/$ASSET" -o "$ARCHIVE"
mkdir -p "$WORK_DIR/source"
tar -xzf "$ARCHIVE" -C "$WORK_DIR/source"

SOURCE_DIR="$(find "$WORK_DIR/source" -mindepth 1 -maxdepth 1 -type d -name 'moderncsv*' -print -quit)"
test -x "$SOURCE_DIR/moderncsv"
test -f "$SOURCE_DIR/moderncsv.desktop"
test -f "$SOURCE_DIR/moderncsv.png"
find "$SOURCE_DIR/lib" -name 'libQt6Core.so*' -print -quit | grep -q .

if find "$SOURCE_DIR/lib" -name 'libQt5*.so*' -print -quit | grep -q .; then
  echo "错误：Modern CSV 主运行库目录检测到 Qt5，禁止与 Qt6 混装。" >&2
  exit 1
fi

###### 准备 desktop 与 Qt6 输入上下文 ######

DESKTOP="$WORK_DIR/moderncsv.desktop"
cp -a "$SOURCE_DIR/moderncsv.desktop" "$DESKTOP"
sed -i \
  -e 's/^Version=.*/Version=1.0/' \
  -e 's|^Exec=.*|Exec=moderncsv|' \
  -e 's|^Icon=.*|Icon=moderncsv|' \
  "$DESKTOP"
desktop-file-validate "$DESKTOP"

SYSTEM_QT_INPUT_DIR="/usr/lib/qt6/plugins/platforminputcontexts"
for input_plugin in \
  libcomposeplatforminputcontextplugin.so \
  libfcitx5platforminputcontextplugin.so \
  libibusplatforminputcontextplugin.so; do
  test -f "$SYSTEM_QT_INPUT_DIR/$input_plugin" || {
    echo "错误：Arch Linux Qt6 构建环境缺少输入上下文插件：$input_plugin" >&2
    exit 1
  }
done

###### 使用 Arch Linux quick-sharun 构建 ######

QUICK_SHARUN="$WORK_DIR/quick-sharun"
curl -fsSL https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/quick-sharun.sh -o "$QUICK_SHARUN"
chmod +x "$QUICK_SHARUN"

export APPDIR
export DESKTOP
export ICON="$SOURCE_DIR/moderncsv.png"
export OUTPATH="$DIST_DIR"
export OUTNAME="moderncsv.AppImage"
export DEPLOY_QT=1
export QT_DIR=qt6
export QT_LOCATION=/usr/lib/qt6

LD_LIBRARY_PATH="$SOURCE_DIR/lib" \
QT_QPA_PLATFORM=xcb \
  "$QUICK_SHARUN" "$SOURCE_DIR/moderncsv"

APPDIR_QT_INPUT_DIR="$APPDIR/lib/qt6/plugins/platforminputcontexts"
for input_plugin in \
  libcomposeplatforminputcontextplugin.so \
  libfcitx5platforminputcontextplugin.so \
  libibusplatforminputcontextplugin.so; do
  test -f "$APPDIR_QT_INPUT_DIR/$input_plugin" || {
    echo "错误：quick-sharun AppDir 缺少 Qt6 输入上下文插件：$input_plugin" >&2
    exit 1
  }
done

if find "$APPDIR" -name 'libQt5*.so*' -print -quit | grep -q .; then
  echo "错误：quick-sharun AppDir 中检测到 Qt5 运行库，禁止与 Qt6 混装。" >&2
  exit 1
fi

cat >> "$APPDIR/.env" <<'EOF_ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
QT_QPA_PLATFORM=xcb
EOF_ENV

"$QUICK_SHARUN" --make-appimage

###### 验证最终 AppImage ######

test -s "$DIST_DIR/moderncsv.AppImage"
chmod +x "$DIST_DIR/moderncsv.AppImage"

VERIFY_DIR="$WORK_DIR/verify-appimage"
mkdir -p "$VERIFY_DIR"
(
  cd "$VERIFY_DIR"
  "$DIST_DIR/moderncsv.AppImage" --appimage-extract >/dev/null
)
VERIFY_ROOT="$VERIFY_DIR/squashfs-root"
VERIFY_QT_INPUT_DIR="$VERIFY_ROOT/lib/qt6/plugins/platforminputcontexts"

for input_plugin in \
  libcomposeplatforminputcontextplugin.so \
  libfcitx5platforminputcontextplugin.so \
  libibusplatforminputcontextplugin.so; do
  test -f "$VERIFY_QT_INPUT_DIR/$input_plugin" || {
    echo "错误：最终 AppImage 缺少 Qt6 输入上下文插件：$input_plugin" >&2
    exit 1
  }
done

if find "$VERIFY_ROOT" -name 'libQt5*.so*' -print -quit | grep -q .; then
  echo "错误：最终 AppImage 中检测到 Qt5 运行库，禁止与 Qt6 混装。" >&2
  exit 1
fi

###### 整理产物 ######

printf '%s\n' "$VERSION" > "$DIST_DIR/version.txt"
SOURCE_SHA256="$(sha256sum "$ARCHIVE" | awk '{print $1}')"
printf '%s  %s\n' "$SOURCE_SHA256" "$ASSET" > "$DIST_DIR/source.sha256"
