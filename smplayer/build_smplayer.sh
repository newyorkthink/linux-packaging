#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装官方软件包及运行依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" smplayer glycin libheif xorg-server xorg-server-common xorg-server-xvfb fcitx5-qt libxcb xcb-util xcb-util-keysyms libxss extra-cmake-modules xcb-util-renderutil xcb-util-wm xcb-util-image xcb-util-cursor libxkbcommon-x11 mesa libglvnd giflib libpng libx11 libxft libxrender libxcomposite libxdamage libxfixes libxext libxinerama freetype2 libjpeg-turbo mpv mpv-mpris smplayer-skins smplayer-themes mplayer qt5-base zlib qt5-declarative libstdc++ libgcc glibc libdecor librsvg libjxl qt5-svg adwaita-qt5 pipewire pipewire-alsa

# 清掉上次的打包目录。
"$SCRIPT_DIR/../common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir dist

# 本程序专属处理：下载并校验官方 Python 版 yt-dlp。
"$SCRIPT_DIR/../common/github/download_latest_stable_named_asset.sh" yt-dlp/yt-dlp yt-dlp /usr/bin/yt-dlp

# 为 yt-dlp 设置执行权限。
chmod +x /usr/bin/yt-dlp

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS=smplayer
# 使用系统里装好的图标。
export ICON="/usr/share/icons/hicolor/scalable/apps/smplayer.svg"
# 使用系统里装好的桌面入口文件。
export DESKTOP="/usr/share/applications/smplayer.desktop"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME="smplayer.AppImage"
# 本程序专属处理：指定 Arch 的 Qt5 插件目录。
export QT_DIR=qt
# 本程序专属处理：为 yt-dlp 一并封装系统 Python。
export DEPLOY_PYTHON=1

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" pacman smplayer)"

# 收集程序及其运行依赖。
quick-sharun /usr/bin/smplayer /usr/bin/simple_web_server /usr/bin/mplayer /usr/bin/mpv /usr/bin/yt-dlp \
  /usr/share/smplayer /usr/lib/qt/plugins/platforminputcontexts/libibusplatforminputcontextplugin.so \
  /usr/lib/qt/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
ENV

# 本程序专属处理：固定数值解析 locale，使用 Qt5 深色主题。
cat >> AppDir/.env <<'ENV'
LC_ALL=
LC_NUMERIC=C
QT_STYLE_OVERRIDE=Adwaita-Dark
ENV

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" "dist/smplayer.AppImage" "$VERSION" dist/version.txt
