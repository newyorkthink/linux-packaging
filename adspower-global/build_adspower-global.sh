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

# 仅在构建容器中探测主程序动态依赖，不把沙盒参数写入运行入口。
export STRACE_BINARY=adspower_global
export STRACE_FLAGS='--no-sandbox'

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

###### 补齐 Fcitx5 GTK3 中文输入模块 ######
# 现有构建日志只包含 GTK3 内置输入模块；补装 Fcitx5 GTK3 前端供 quick-sharun 自动收集。
yay -S --noconfirm fcitx5-gtk

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

# ICU 数据是 Chromium 初始化所必需的输入，缺失时立即停止构建。
if [ ! -s "$SOURCE_APP_DIR/icudtl.dat" ]; then
  echo "Error: AdsPower ICU data not found: $SOURCE_APP_DIR/icudtl.dat" >&2
  exit 1
fi

# sharun 启动时 /proc/self/exe 指向 bin 入口，ICU、locales 和 resources 必须位于此处。
# quick-sharun 会把真实 ELF 部署到 shared/bin，并在 bin 中生成对应启动入口。
mkdir -p ./AppDir/bin
# 完整保留官方应用资源和随包运行库的相对布局。
cp -a "$SOURCE_APP_DIR"/. ./AppDir/bin/

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

###### 核心打包：部署主程序、辅助程序与随包运行库，资源保留在 bin 入口旁 ######
quick-sharun ./AppDir/bin/*

###### 固定 AppImage 内 AdsPower 的 Linux 界面语言为简体中文 ######
printf '%s\n' 'LANGUAGE=zh-CN' >> ./AppDir/.env

# 将完成依赖部署的 AppDir 封装为最终 AppImage。
quick-sharun --make-appimage
