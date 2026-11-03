#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装官方软件包及运行依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" newsboat json-c libxml2 sqlite stfl buku kitty ruby asciidoctor rust swig

# 清掉上次的打包目录。
rm -rf -- AppDir dist
mkdir -p dist

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 保留原有的启动窗口类设置。
export STARTUPWMCLASS=newsboat
# 使用系统里装好的图标。
export ICON=/usr/share/icons/hicolor/scalable/apps/newsboat.svg
# 使用仓库提供的桌面入口文件。
export DESKTOP="$SCRIPT_DIR/newsboat.desktop"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME=newsboat.AppImage

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" pacman newsboat)"

# 收集程序及其运行依赖。
quick-sharun /usr/bin/newsboat /usr/bin/podboat

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" dist/newsboat.AppImage "$VERSION" dist/version.txt
