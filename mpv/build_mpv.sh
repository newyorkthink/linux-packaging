#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装官方软件包及运行依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" mpv mpv-mpris glycin libheif xorg-server xorg-server-common xorg-server-xvfb

# 清掉上次的打包目录。
rm -rf -- AppDir dist
mkdir -p dist

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 使用系统里装好的图标。
export ICON=/usr/share/icons/hicolor/scalable/apps/mpv.svg
# 使用系统里装好的桌面入口文件。
export DESKTOP=/usr/share/applications/mpv.desktop
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME=mpv.AppImage

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" pacman mpv)"

# 收集程序及其运行依赖。
quick-sharun /usr/bin/mpv

# 复用官方代码：固定运行时 locale。
echo 'LC_ALL=C.UTF-8' >> ./AppDir/.env

# 本仓库兼容处理：在依赖收集后下载并校验独立辅助程序。
mkdir -p AppDir/usr/bin
"$SCRIPT_DIR/../common/github/download_latest_stable_named_asset.sh" yt-dlp/yt-dlp yt-dlp_linux AppDir/usr/bin/yt-dlp
chmod +x AppDir/usr/bin/yt-dlp

# 文件内容复用官方代码：未传入参数时启用窗口模式。
mkdir -p AppDir/bin
cp "$SCRIPT_DIR/mpv-launch-gui.src.hook" AppDir/bin/mpv-launch-gui.src.hook

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" dist/mpv.AppImage "$VERSION" dist/version.txt
