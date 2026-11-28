#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" --base
# 安装官方软件包及运行依赖。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" "simplescreenrecorder" fcitx5-qt qt6ct kvantum lxqt-qtplugin glycin libheif xorg-server xorg-server-common xorg-server-xvfb ffmpeg alsa-lib jack2 libpulse libx11 libxext libxfixes libxi libxinerama glu gtk-update-icon-cache libglvnd mesa egl-wayland libxcb xcb-util xcb-util-keysyms libxss extra-cmake-modules xcb-util-renderutil xcb-util-wm xcb-util-image xcb-util-cursor libxkbcommon-x11 wl-clipboard

# 清掉上次的打包目录。
"$SCRIPT_DIR/../Common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir dist


# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 本程序专属处理：让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS="simplescreenrecorder"
# 使用系统里装好的图标。
export ICON="/usr/share/icons/hicolor/256x256/apps/simplescreenrecorder.png"
# 使用系统里装好的桌面入口文件。
export DESKTOP="/usr/share/applications/be.maartenbaert.simplescreenrecorder.desktop"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME="simplescreenrecorder.AppImage"
# 本程序专属处理：沿用现有 OpenGL 运行库部署配置。
export DEPLOY_OPENGL=1
# 官方包依赖 qt6-base，打包时打入 Qt。
export DEPLOY_QT=1

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../Common/build/read_app_version.sh" pacman "simplescreenrecorder")"

# 收集程序及其运行依赖。
quick-sharun /usr/bin/simplescreenrecorder

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
ENV

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../Common/build/save_appimage_version.sh" "dist/simplescreenrecorder.AppImage" "$VERSION" dist/version.txt
