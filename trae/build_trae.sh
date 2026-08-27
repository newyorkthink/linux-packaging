#!/usr/bin/env bash
set -e

rm -rf AppDir dist trae.desktop trae.png \
  /tmp/aur-trae /tmp/trae-extract /tmp/trae.tar.gz || true

ARCH="$(uname -m)"

if [ "$ARCH" != "x86_64" ]; then
  echo "Error: this script only supports x86_64 / linux-x64."
  exit 1
fi

export ARCH

# 安装基础打包工具和依赖
yay -S --noconfirm gcc base-devel git curl wget tar gzip binutils patchelf coreutils \
  appstream-glib desktop-file-utils util-linux zsync \
  xorg-server xorg-server-common xorg-server-xvfb

# 安装 Trae / Electron 运行相关依赖。
# 依赖以 AUR trae 为基线，并补充 X11 / OpenGL / PipeWire / IBus，方便 quick-sharun 收集运行库。
yay -S --noconfirm nss alsa-lib gtk3 at-spi2-core libsecret libxkbfile zeromq \
  libappindicator-gtk3 libnotify libxss libxtst shared-mime-info xdg-utils \
  gcc-libs glibc lsof inetutils \
  libx11 libxext libxi libxrandr libxkbcommon \
  libxcomposite libxdamage libxfixes mesa libglvnd libva libvdpau \
  pulseaudio pulseaudio-alsa pipewire-audio \
  ibus

# 直接读取 AUR trae 当前 PKGBUILD，避免把 Trae 版本和下载地址写死在仓库里。
for attempt in 1 2 3; do
  rm -rf /tmp/aur-trae
  if git -c http.version=HTTP/1.1 clone --depth=1 https://aur.archlinux.org/trae.git /tmp/aur-trae; then
    break
  fi
  if [ "$attempt" -eq 3 ]; then
    echo "Error: failed to clone AUR trae repository."
    exit 1
  fi
  sleep 5
done

PKGBUILD=/tmp/aur-trae/PKGBUILD

if [ ! -f "$PKGBUILD" ]; then
  echo "Error: AUR trae PKGBUILD not found."
  exit 1
fi

VERSION="$(sed -nE 's/^pkgver=([^[:space:]]+).*/\1/p' "$PKGBUILD" | head -n 1)"
PKGREL="$(sed -nE 's/^pkgrel=([^[:space:]]+).*/\1/p' "$PKGBUILD" | head -n 1)"
TARBALL_LINK="$(sed -nE 's#^source_x86_64=.*::(https://[^\"]+).*#\1#p' "$PKGBUILD" | head -n 1)"
B2SUM="$(sed -nE "s/^b2sums_x86_64=\\('([^']+)'.*/\\1/p" "$PKGBUILD" | head -n 1)"

if [ -z "$VERSION" ] || [ -z "$PKGREL" ] || [ -z "$TARBALL_LINK" ]; then
  echo "Error: failed to resolve Trae version or x64 download URL from AUR PKGBUILD."
  exit 1
fi

TARBALL_LINK="${TARBALL_LINK//\$\{pkgver\}/$VERSION}"
TARBALL_LINK="${TARBALL_LINK//\$\{pkgrel\}/$PKGREL}"

echo "Trae version: $VERSION-$PKGREL"
echo "Trae x64 tarball URL: $TARBALL_LINK"

mkdir -p ./AppDir/bin ./dist /tmp/trae-extract
wget --retry-connrefused --tries=30 "$TARBALL_LINK" -O /tmp/trae.tar.gz

# AUR 提供了 x86_64 b2 校验值时同步校验上游 tar 包。
if [ -n "$B2SUM" ] && [ "$B2SUM" != "SKIP" ]; then
  printf '%s  %s\n' "$B2SUM" /tmp/trae.tar.gz | b2sum -c -
fi

tar -xzf /tmp/trae.tar.gz -C /tmp/trae-extract

# 当前 AUR tar 包为 Electron 应用目录；同时兼容未来增加一层顶级目录的情况。
TRAE_ROOT=/tmp/trae-extract
if [ ! -f "$TRAE_ROOT/resources/app/resources/linux/code.png" ]; then
  TRAE_BINARY="$(find "$TRAE_ROOT" -maxdepth 2 -type f -name trae | head -n 1 || true)"
  if [ -z "$TRAE_BINARY" ]; then
    echo "Error: extracted Trae executable not found."
    exit 1
  fi
  TRAE_ROOT="$(dirname "$TRAE_BINARY")"
fi

cp -a "$TRAE_ROOT"/. ./AppDir/bin/

if [ ! -f ./AppDir/bin/trae ]; then
  echo "Error: ./AppDir/bin/trae not found after extraction."
  exit 1
fi
chmod +x ./AppDir/bin/trae

# 与 AUR trae 保持一致，移除会和系统 gcc-libs 冲突的 ckg 自带运行库。
rm -f \
  ./AppDir/bin/resources/app/modules/ckg/binary/libstdc++.so.6 \
  ./AppDir/bin/resources/app/modules/ckg/binary/libgcc_s.so.1

# AUR 已提供 desktop；只在构建目录复制并修正 AppImage 入口，不额外维护重复文件。
if [ ! -f /tmp/aur-trae/trae.desktop ]; then
  echo "Error: AUR trae.desktop not found."
  exit 1
fi
cp -v /tmp/aur-trae/trae.desktop ./trae.desktop

if [ ! -f ./AppDir/bin/resources/app/resources/linux/code.png ]; then
  echo "Error: Trae icon not found: ./AppDir/bin/resources/app/resources/linux/code.png"
  exit 1
fi
cp -v ./AppDir/bin/resources/app/resources/linux/code.png ./trae.png

sed -i \
  -e 's#^Exec=.*#Exec=trae %U#' \
  -e 's#^Icon=.*#Icon=trae#' \
  ./trae.desktop

if ! grep -q '^X-AppImage-Version=' ./trae.desktop; then
  echo "X-AppImage-Version=$VERSION" >> ./trae.desktop
fi

echo "$VERSION" > ~/version

export APPNAME=Trae
export STARTUPWMCLASS="$(sed -n 's/^StartupWMClass=//p' ./trae.desktop | head -n 1)"
export STARTUPWMCLASS="${STARTUPWMCLASS:-trae}"
export ICON=./trae.png
export DESKTOP=./trae.desktop
export OUTPATH=./dist
export OUTNAME="trae.AppImage"
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export DEPLOY_PIPEWIRE=1

# 使用与 VS Code / Cursor 相同的 quick-sharun Electron 打包路径，并补齐输入法、NSS、hostname、ZeroMQ。
quick-sharun \
  ./AppDir/bin/* \
  /usr/bin/hostname \
  /usr/lib/libnss* \
  /usr/lib/libsoftokn3.so \
  /usr/lib/libfreeblpriv3.so \
  /usr/lib/pkcs11/* \
  /usr/lib/libzmq.so* \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so

quick-sharun --make-appimage
