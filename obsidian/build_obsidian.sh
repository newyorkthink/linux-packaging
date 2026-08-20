#!/usr/bin/env bash
set -e

rm -rf AppDir obsidian-* \
  obsidian.desktop obsidian.png \
  /tmp/obsidian.tar.gz || true

ARCH="$(uname -m)"

if [ "$ARCH" != "x86_64" ]; then
  echo "Error: this script only supports x86_64 / linux-x64."
  exit 1
fi

export ARCH

# 安装基础打包工具和依赖
yay -S --noconfirm gcc base-devel curl wget tar gzip binutils patchelf coreutils \
  appstream-glib desktop-file-utils util-linux zsync \
  xorg-server xorg-server-common xorg-server-xvfb

# 安装 Obsidian / Electron 运行相关依赖
# 补充 GTK3 / IBus / X11 / OpenGL / PipeWire 相关库，方便 quick-sharun 收集运行库。
yay -S --noconfirm at-spi2-core gtk3 libnotify libsecret libxss libxtst nss \
  util-linux-libs xdg-utils shared-mime-info alsa-lib \
  gcc-libs glibc lsof inetutils \
  libx11 libxext libxi libxrandr libxkbcommon libxkbfile \
  libxcomposite libxdamage libxfixes mesa libglvnd libva libvdpau \
  pulseaudio pulseaudio-alsa pipewire-audio \
  ibus

export APPNAME=Obsidian
export STARTUPWMCLASS=obsidian
export ICON=./obsidian.png
export DESKTOP=./obsidian.desktop
export OUTPATH=./dist
export OUTNAME="obsidian.AppImage"
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export DEPLOY_PIPEWIRE=1

# 下载官方 Obsidian Linux x64 tar 包
RELEASE_API="https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest"
RELEASE_JSON="$(wget --retry-connrefused --tries=30 -qO- "$RELEASE_API")"

VERSION="$(printf '%s\n' "$RELEASE_JSON" | awk -F'\"' '/"tag_name":/ {gsub(/^v/, "", $4); print $4; exit}')"

if [ -z "$VERSION" ]; then
  echo "Error: failed to resolve Obsidian latest version."
  exit 1
fi

TARBALL_LINK="$(printf '%s\n' "$RELEASE_JSON" \
  | awk -F'\"' '/browser_download_url/ && /obsidian-.*\.tar\.gz/ {print $4}' \
  | grep -E "/obsidian-${VERSION}\.tar\.gz$" \
  | head -n 1 || true)"

if [ -z "$TARBALL_LINK" ]; then
  echo "Error: failed to resolve Obsidian x64 tarball URL."
  exit 1
fi

echo "Obsidian version: $VERSION"
echo "Obsidian x64 tarball URL: $TARBALL_LINK"

mkdir -p ./AppDir/bin ./dist
wget --retry-connrefused --tries=30 "$TARBALL_LINK" -O /tmp/obsidian.tar.gz

tar -xzf /tmp/obsidian.tar.gz
OBSIDIAN_DIR="$(find . -maxdepth 1 -type d -name 'obsidian-*' | head -n 1)"

if [ -z "$OBSIDIAN_DIR" ]; then
  echo "Error: extracted obsidian-* directory not found."
  exit 1
fi

mv -v "$OBSIDIAN_DIR"/* ./AppDir/bin/

if [ ! -x ./AppDir/bin/obsidian ]; then
  chmod +x ./AppDir/bin/obsidian 2>/dev/null || true
fi

if [ ! -f ./AppDir/bin/resources/icon.png ]; then
  echo "Error: Obsidian icon not found: ./AppDir/bin/resources/icon.png"
  exit 1
fi

cp -v ./AppDir/bin/resources/icon.png ./obsidian.png

cat > ./obsidian.desktop <<EOF_DESKTOP
[Desktop Entry]
Name=Obsidian
Comment=Obsidian
Exec=obsidian %U
Terminal=false
Type=Application
Icon=obsidian
StartupWMClass=obsidian
MimeType=x-scheme-handler/obsidian;
Categories=Office;
X-AppImage-Version=$VERSION
EOF_DESKTOP

echo "$VERSION" > ~/version

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
