#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装官方软件包及运行依赖。
# 构建时缺少 Qt 主题插件，补上 qt6ct、kvantum 和 lxqt-qtplugin。
"$SCRIPT_DIR/../common/arch/install_packages.sh" obs-studio fcitx5-qt qt6ct kvantum lxqt-qtplugin

# 清掉上次的打包目录。
rm -rf -- AppDir dist
mkdir -p dist

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 使用系统里装好的图标。
export ICON=/usr/share/icons/hicolor/256x256/apps/com.obsproject.Studio.png
# 使用系统里装好的桌面入口文件。
export DESKTOP=/usr/share/applications/com.obsproject.Studio.desktop
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME=obs-studio.AppImage
# 官方包依赖 libglvnd，打包时打入 OpenGL。
export DEPLOY_OPENGL=1
# 官方包依赖 libpipewire，打包时打入 PipeWire。
export DEPLOY_PIPEWIRE=1
# 官方包依赖 Python，打包时打入 Python 运行时。
export DEPLOY_PYTHON=1
# 官方包依赖 qt6-base，打包时打入 Qt。
export DEPLOY_QT=1

# 模块、模块数据、脚本模块和录制程序不是主程序的动态库依赖，同一次传入。
# 收集程序及其运行依赖。
quick-sharun /usr/bin/obs /usr/bin/obs-ffmpeg-mux \
  /usr/lib/obs-modules /usr/share/obs /usr/lib/obs-scripting

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

# 读取本次打包使用的版本。
version="$("$SCRIPT_DIR/../common/arch/get_package_version.sh" obs-studio)"
# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" \
  dist/obs-studio.AppImage "$version" dist/version.txt
