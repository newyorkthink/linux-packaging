#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 安装统一的 Arch AppImage 基础包
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base

cd "$(dirname "$0")"

###### 清理旧构建目录 ######
rm -rf AppDir || true

###### 准备构建环境 ######
yay -S --noconfirm gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux glycin libheif zsync xorg-server xorg-server-common xorg-server-xvfb
yay -S --noconfirm wl-clipboard xclip fcitx5-qt egl-wayland libxcb xcb-util xcb-util-keysyms libxss extra-cmake-modules xcb-util-renderutil xcb-util-wm xcb-util-image \
  xcb-util-cursor libxkbcommon libxkbcommon-x11 mesa libglvnd \
  make pkgconf base-devel giflib libpng libx11 libxft libxrender \
  libxcomposite libxdamage libxfixes libxext libxinerama freetype2 libjpeg-turbo
yay -S --noconfirm freerdp libdecor alsa-plugins

FREERDP_PACKAGE_VERSION="$(pacman -Q freerdp | awk '{print $2}')"
FREERDP_VERSION="${FREERDP_PACKAGE_VERSION#*:}"
FREERDP_VERSION="${FREERDP_VERSION%-*}"
if [ -z "$FREERDP_VERSION" ]; then
  echo "错误：无法解析 FreeRDP 版本。" >&2
  exit 1
fi

###### 配置 AppImage 元数据与路径映射 ######
ARCH="$(uname -m)"
export ARCH

export STARTUPWMCLASS=xfreerdp3
export ICON=./freerdp.png
export DESKTOP=./freerdp.desktop
export OUTPATH=./dist
export OUTNAME="xfreerdp3.AppImage"
export PATH_MAPPING='/usr/lib/freerdp/server/proxy/plugins:${SHARUN_DIR}/lib/freerdp/server/proxy/plugins'

PROXY_PLUGIN_DIR=/usr/lib/freerdp/server/proxy/plugins
shopt -s nullglob
PROXY_PLUGINS=("$PROXY_PLUGIN_DIR"/*.so)
shopt -u nullglob

if (( ${#PROXY_PLUGINS[@]} == 0 )); then
  echo "No FreeRDP proxy plugins found in $PROXY_PLUGIN_DIR" >&2
  exit 1
fi

###### 核心打包 ######
quick-sharun /usr/bin/freerdp-proxy3 \
               /usr/bin/freerdp-shadow-cli3 \
               /usr/bin/sdl-freerdp3 \
               /usr/bin/sfreerdp-server3 \
               /usr/bin/sfreerdp3 \
               /usr/bin/winpr-hash3 \
               /usr/bin/winpr-makecert3 \
               /usr/bin/wlfreerdp3 \
               /usr/bin/xfreerdp3 \
               "${PROXY_PLUGINS[@]}"

###### 核对打包所需文件并生成产物 ######
for plugin in "${PROXY_PLUGINS[@]}"; do
  test -f "AppDir/lib/freerdp/server/proxy/plugins/${plugin##*/}"
done

test -f AppDir/lib/sharun-preload/path-mapping.so
grep -Fq '/usr/lib/freerdp/server/proxy/plugins:${SHARUN_DIR}/lib/freerdp/server/proxy/plugins' AppDir/.env

quick-sharun --make-appimage

printf '%s\n' "$FREERDP_VERSION" > ./dist/version.txt
