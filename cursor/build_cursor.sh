#!/usr/bin/env bash
set -e

rm -rf AppDir usr opt etc debian-binary control.tar.* data.tar.* \
  cursor.desktop co.anysphere.cursor.png \
  /tmp/cursor.deb /tmp/cursor-download.log || true

ARCH="$(uname -m)"

if [ "$ARCH" != "x86_64" ]; then
  echo "Error: this script only supports x86_64 / linux-x64."
  exit 1
fi

export ARCH

DEB_ARCH=x64

# 安装基础打包工具和依赖
yay -S --noconfirm gcc base-devel wget curl tar gzip xz binutils patchelf coreutils \
  appstream-glib desktop-file-utils util-linux zsync \
  xorg-server xorg-server-common xorg-server-xvfb

# 安装 Cursor / Electron 运行相关依赖
# 补充 GTK3 / IBus / X11 / OpenGL / PipeWire 相关库，方便 quick-sharun 收集运行库。
yay -S --noconfirm inetutils libx11 libxrandr libxss nss \
  pulseaudio pulseaudio-alsa pipewire-audio \
  alsa-lib gtk3 libsecret libnotify shared-mime-info xdg-utils \
  gcc-libs glibc lsof \
  libxext libxi libxtst libxkbcommon libxkbfile \
  libxcomposite libxdamage libxfixes mesa libglvnd libva libvdpau libva-intel-driver \
  ibus

export APPNAME=Cursor
export STARTUPWMCLASS=cursor
export ICON=./co.anysphere.cursor.png
export DESKTOP=./cursor.desktop
export OUTPATH=./dist
export OUTNAME="cursor.AppImage"
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export DEPLOY_PIPEWIRE=1

# 下载官方 Cursor x64 deb 包
DEB_SOURCE="https://cursor.com/download"
DEB_LINK="$(wget --retry-connrefused --tries=30 "$DEB_SOURCE" -O - \
  | sed 's/[()",{} ]/\n/g' \
  | grep -E "https.*download.*linux.*${DEB_ARCH}.*deb" \
  | head -n 1 || true)"

if [ -z "$DEB_LINK" ]; then
  echo "Error: failed to resolve Cursor x64 deb download URL."
  exit 1
fi

echo "Cursor deb URL: $DEB_LINK"

mkdir -p ./AppDir ./dist

if ! wget --retry-connrefused --tries=30 "$DEB_LINK" -O /tmp/cursor.deb 2>/tmp/cursor-download.log; then
  cat /tmp/cursor-download.log
  exit 1
fi

ar xvf /tmp/cursor.deb

if [ -f ./data.tar.xz ]; then
  tar -xvf ./data.tar.xz
elif [ -f ./data.tar.zst ]; then
  tar -xvf ./data.tar.zst
elif [ -f ./data.tar.gz ]; then
  tar -xvf ./data.tar.gz
else
  echo "Error: data.tar.* not found in cursor.deb."
  exit 1
fi

mv -v ./usr ./AppDir/usr

# Cursor deb 解包后的实际路径是 AppDir/usr/share/cursor。
if [ -d ./AppDir/usr/share/cursor ]; then
  mv -v ./AppDir/usr/share/cursor ./AppDir/bin
else
  echo "Error: ./AppDir/usr/share/cursor not found."
  exit 1
fi

# 注意：desktop 和 icon 不要复制到 AppDir 根目录。
# quick-sharun 会根据 DESKTOP / ICON 自动添加到 AppDir。
if [ -f ./AppDir/usr/share/applications/cursor.desktop ]; then
  cp -v ./AppDir/usr/share/applications/cursor.desktop ./cursor.desktop
else
  echo "Error: cursor.desktop not found."
  exit 1
fi

if [ -f ./AppDir/usr/share/pixmaps/co.anysphere.cursor.png ]; then
  cp -v ./AppDir/usr/share/pixmaps/co.anysphere.cursor.png ./co.anysphere.cursor.png
else
  echo "Error: Cursor icon not found."
  exit 1
fi

# 修正 desktop 文件，让 AppImage 入口直接调用 cursor。
sed -i \
  -e 's#^Exec=.*#Exec=cursor %U#' \
  -e 's#^Icon=.*#Icon=co.anysphere.cursor#' \
  ./cursor.desktop

# 尽量提取版本号，方便记录。
VERSION=""
if [ -f ./AppDir/bin/resources/app/package.json ]; then
  VERSION="$(awk -F'"' '/"version":/ {print $4; exit}' ./AppDir/bin/resources/app/package.json || true)"
fi

if [ -n "$VERSION" ]; then
  echo "$VERSION" > ~/version
  echo "Cursor version: $VERSION"

  if ! grep -q '^X-AppImage-Version=' ./cursor.desktop; then
    echo "X-AppImage-Version=$VERSION" >> ./cursor.desktop
  fi
fi

# 使用 quick-sharun 构建 AppDir，并补充 IBus GTK3 输入法模块和 NSS / hostname 相关运行项。
quick-sharun \
  ./AppDir/bin/* \
  /usr/bin/hostname \
  /usr/lib/libnss* \
  /usr/lib/libsoftokn3.so \
  /usr/lib/libfreeblpriv3.so \
  /usr/lib/pkcs11/* \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so

quick-sharun --make-appimage