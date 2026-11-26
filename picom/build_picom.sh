#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装官方软件包及运行依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" "picom" xorg-server xorg-server-common bash glibc gcc-libs libconfig libepoxy libev libglvnd pcre2 pixman libx11 libxext libxcb libxrender libxrandr libxinerama libxdamage libxfixes xcb-util-image xcb-util-renderutil xorg-xprop xorg-xwininfo

# 清掉上次的打包目录。
"$SCRIPT_DIR/../common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir dist


# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 使用系统里装好的图标。
export ICON="/usr/share/icons/hicolor/scalable/apps/compton.svg"
# 使用系统里装好的桌面入口文件。
export DESKTOP="/usr/share/applications/picom.desktop"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME="picom.AppImage"
# 本程序专属处理：部署 OpenGL 运行依赖。
export DEPLOY_OPENGL=1

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" pacman "picom")"

# 收集程序及其运行依赖。
quick-sharun /usr/bin/picom /usr/bin/picom-trans /usr/bin/picom-inspect /usr/bin/compton /usr/bin/compton-trans /usr/bin/xprop /usr/bin/xwininfo /etc/xdg/picom.conf

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" "dist/picom.AppImage" "$VERSION" dist/version.txt
