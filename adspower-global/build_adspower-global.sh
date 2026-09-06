#!/usr/bin/env bash
set -Eeuo pipefail

###### 定位脚本目录，保证在仓库任意位置调用都固定在 adspower-global/ 目录内构建 ######
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

rm -rf source AppDir dist adspower-global.desktop adspower-global.png || true
mkdir -p source dist

ARCH="$(uname -m)"
if [ "$ARCH" != "x86_64" ]; then
  echo "Error: this script only supports x86_64." >&2
  exit 1
fi
export ARCH

export STARTUPWMCLASS="AdsPower Global"
export OUTPATH=./dist
export OUTNAME="adspower-global.AppImage"
export URUNTIME_PRELOAD=1

###### 准备构建环境：安装最小基础包 ######
yay -S --noconfirm base-devel git wget curl jq binutils patchelf file coreutils findutils \
  grep sed gawk tar gzip xz unzip rsync util-linux appstream-glib \
  desktop-file-utils zsync ca-certificates

###### 安装 AdsPower 官方 Linux 包所需的运行依赖 ######
# 依赖名称参考当前 AUR adspower-global 配方；AUR 仅作为依赖和文件布局参考，不作为程序二进制来源。
yay -S --noconfirm \
  alsa-lib at-spi2-core cairo dbus expat gcc-libs glib2 glibc gtk3 libcups libdrm \
  libx11 libxcb libxcomposite libxdamage libxext libxfixes libxkbcommon libxrandr \
  mesa nspr nss pango

###### 从 AdsPower 官方下载页动态获取当前 Linux x64 稳定版 ######
DOWNLOAD_PAGE_URL="https://www.adspower.com/download"
DOWNLOAD_PAGE="$(curl -fL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 20 --max-time 120 "$DOWNLOAD_PAGE_URL")"
PACKAGE_URL="$(printf '%s' "$DOWNLOAD_PAGE" | grep -oE 'https://version\.adspower\.net/software/linux-x64-global/[^"[:space:]]+/AdsPower-Global-[^"[:space:]]+-x64\.deb' | head -n1 || true)"
if [ -z "$PACKAGE_URL" ]; then
  echo "Error: failed to resolve the current AdsPower Linux x64 package URL." >&2
  exit 1
fi

PACKAGE_NAME="$(basename -- "$PACKAGE_URL")"
VERSION="$(printf '%s' "$PACKAGE_NAME" | sed -nE 's/^AdsPower-Global-([0-9]+(\.[0-9]+)+)-x64\.deb$/\1/p')"
if [ -z "$VERSION" ]; then
  echo "Error: failed to determine AdsPower version from $PACKAGE_NAME." >&2
  exit 1
fi
EXPECTED_URL="https://version.adspower.net/software/linux-x64-global/$VERSION/AdsPower-Global-$VERSION-x64.deb"
if [ "$PACKAGE_URL" != "$EXPECTED_URL" ]; then
  echo "Error: unexpected AdsPower Linux package URL: $PACKAGE_URL" >&2
  exit 1
fi

echo "AdsPower Global version: $VERSION"
echo "$VERSION" > ~/version

###### 下载并解包 AdsPower 官方 DEB ######
DEB="$SCRIPT_DIR/source/$PACKAGE_NAME"
EXTRACT_DIR="$SCRIPT_DIR/source/extracted"
ROOT_DIR="$EXTRACT_DIR/root"
mkdir -p "$EXTRACT_DIR" "$ROOT_DIR"

curl -fL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 20 --max-time 1800 \
  "$PACKAGE_URL" -o "$DEB"
if [ ! -s "$DEB" ]; then
  echo "Error: downloaded AdsPower package is empty." >&2
  exit 1
fi
if ! file "$DEB" | grep -q 'Debian binary package'; then
  echo "Error: downloaded AdsPower file is not a Debian package." >&2
  exit 1
fi
sha256sum "$DEB"

(
  cd "$EXTRACT_DIR"
  ar x "$DEB"
)
DATA_ARCHIVE="$(find "$EXTRACT_DIR" -maxdepth 1 -type f -name 'data.tar.*' -print -quit)"
if [ -z "$DATA_ARCHIVE" ]; then
  echo "Error: AdsPower DEB does not contain data.tar.*." >&2
  exit 1
fi
tar -xf "$DATA_ARCHIVE" -C "$ROOT_DIR"

###### 保留 AdsPower 官方 /opt 程序目录及资源 ######
SOURCE_APP_DIR="$ROOT_DIR/opt/AdsPower Global"
SOURCE_MAIN="$SOURCE_APP_DIR/adspower_global"
if [ ! -x "$SOURCE_MAIN" ]; then
  echo "Error: AdsPower main executable not found: $SOURCE_MAIN" >&2
  exit 1
fi
if ! file "$SOURCE_MAIN" | grep -q 'ELF 64-bit.*x86-64'; then
  echo "Error: AdsPower main executable is not an x86_64 ELF." >&2
  exit 1
fi

mkdir -p ./AppDir/shared/bin
cp -a "$SOURCE_APP_DIR"/. ./AppDir/shared/bin/

###### 准备官方 desktop 与图标，并改为 AppImage 内入口 ######
SOURCE_DESKTOP="$ROOT_DIR/usr/share/applications/adspower_global.desktop"
if [ ! -f "$SOURCE_DESKTOP" ]; then
  echo "Error: AdsPower desktop file not found." >&2
  exit 1
fi
cp -v "$SOURCE_DESKTOP" ./adspower-global.desktop
sed -i \
  -e 's|^Exec=.*|Exec=adspower_global %U|' \
  -e 's|^Icon=.*|Icon=adspower-global|' \
  ./adspower-global.desktop
if ! grep -q '^StartupWMClass=' ./adspower-global.desktop; then
  sed -i '/^\[Desktop Entry\]$/a StartupWMClass=AdsPower Global' ./adspower-global.desktop
fi
if ! grep -q '^X-AppImage-Version=' ./adspower-global.desktop; then
  sed -i "/^\[Desktop Entry\]$/a X-AppImage-Version=$VERSION" ./adspower-global.desktop
fi

ICON_SRC=""
for size in 1024 512 256 128 64 48 32 16; do
  candidate="$ROOT_DIR/usr/share/icons/hicolor/${size}x${size}/apps/adspower_global.png"
  if [ -f "$candidate" ]; then
    ICON_SRC="$candidate"
    break
  fi
done
if [ -z "$ICON_SRC" ]; then
  echo "Error: AdsPower icon not found under hicolor." >&2
  exit 1
fi
cp -v "$ICON_SRC" ./adspower-global.png

export DESKTOP=./adspower-global.desktop
export ICON=./adspower-global.png

###### 核心打包：保持官方程序内部布局，只让 quick-sharun 收集主程序运行依赖 ######
quick-sharun ./AppDir/shared/bin/adspower_global
quick-sharun --make-appimage
