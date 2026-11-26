#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装官方软件包及运行依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" "rofi" xorg-server xorg-server-common rofi-emoji bash cairo glibc libxcb libxkbcommon-x11 startup-notification wayland xcb-imdkit xcb-util xcb-util-cursor xcb-util-keysyms xcb-util-wm libva libvdpau

# 清掉上次的打包目录。
"$SCRIPT_DIR/../common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir dist


# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 本程序专属处理：让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS="rofi"
# 使用系统里装好的图标。
export ICON="/usr/share/icons/hicolor/scalable/apps/rofi.svg"
# 使用系统里装好的桌面入口文件。
export DESKTOP="/usr/share/applications/rofi.desktop"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME="rofi.AppImage"
# 本程序专属处理：部署 OpenGL 运行依赖。
export DEPLOY_OPENGL=1

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" pacman "rofi")"

# 收集程序及其运行依赖。
quick-sharun /usr/bin/rofi /usr/bin/rofi-sensible-terminal /usr/bin/rofi-theme-selector

mkdir -p AppDir/bin
# 文件内容复用官方代码：补充运行数据目录并在首次启动时复制内置主题。
cp "$SCRIPT_DIR/rofi-datadir.src.hook" AppDir/bin/rofi-datadir.src.hook

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" "dist/rofi.AppImage" "$VERSION" dist/version.txt
