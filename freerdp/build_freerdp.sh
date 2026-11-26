#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装官方软件包及运行依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" "freerdp" glycin libheif xorg-server xorg-server-common xorg-server-xvfb wl-clipboard fcitx5-qt egl-wayland libxcb xcb-util xcb-util-keysyms libxss extra-cmake-modules xcb-util-renderutil xcb-util-wm xcb-util-image xcb-util-cursor libxkbcommon-x11 mesa libglvnd giflib libpng libx11 libxft libxrender libxcomposite libxdamage libxfixes libxext libxinerama freetype2 libjpeg-turbo libdecor alsa-plugins

# 清掉上次的打包目录。
"$SCRIPT_DIR/../common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir dist


# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 本程序专属处理：使用仓库提供的图标文件。
export ICON="$SCRIPT_DIR/freerdp.png"
# 使用仓库提供的桌面入口文件。
export DESKTOP="$SCRIPT_DIR/freerdp.desktop"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME="xfreerdp3.AppImage"
# 本程序专属处理：将代理插件系统目录映射到包内路径。
export PATH_MAPPING='/usr/lib/freerdp/server/proxy/plugins:${SHARUN_DIR}/lib/freerdp/server/proxy/plugins'

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" pacman "freerdp")"

# 本程序专属处理：定位 FreeRDP 代理插件目录并确认存在可打包的插件文件。
PROXY_PLUGIN_DIR=/usr/lib/freerdp/server/proxy/plugins
shopt -s nullglob
PROXY_PLUGINS=("$PROXY_PLUGIN_DIR"/*.so)
shopt -u nullglob
if (( ${#PROXY_PLUGINS[@]} == 0 )); then
  echo "No FreeRDP proxy plugins found in $PROXY_PLUGIN_DIR" >&2
  exit 1
fi

# 收集程序及其运行依赖。
quick-sharun /usr/bin/freerdp-proxy3 /usr/bin/freerdp-shadow-cli3 /usr/bin/sdl-freerdp3 /usr/bin/sfreerdp-server3 /usr/bin/sfreerdp3 /usr/bin/winpr-hash3 /usr/bin/winpr-makecert3 /usr/bin/wlfreerdp3 /usr/bin/xfreerdp3 "${PROXY_PLUGINS[@]}"

# 本程序专属处理：核对代理插件、path-mapping 预加载库及路径映射配置已写入 AppDir。
for plugin in "${PROXY_PLUGINS[@]}"; do
  test -f "AppDir/lib/freerdp/server/proxy/plugins/${plugin##*/}"
done
test -f AppDir/lib/sharun-preload/path-mapping.so
grep -Fq '/usr/lib/freerdp/server/proxy/plugins:${SHARUN_DIR}/lib/freerdp/server/proxy/plugins' AppDir/.env

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" "dist/xfreerdp3.AppImage" "$VERSION" dist/version.txt
