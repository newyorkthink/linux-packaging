#!/usr/bin/env bash
# OBS Studio：安装官方包，把 /usr/bin/obs 和会被临时加载的模块交给 quick-sharun。
# quick-sharun 自己生成 AppRun。这里不要写 AppRun.sh。

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、Qt、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 应用本身。包管理器会拉入它声明的依赖。中文输入只装 Qt6 这一套。
# 构建时缺少 Qt 主题插件，补上 qt6ct、kvantum 和 lxqt-qtplugin。
"$SCRIPT_DIR/../common/arch/install_packages.sh" obs-studio fcitx5-qt qt6ct kvantum lxqt-qtplugin

# 清掉上次的打包目录。dist 留给这次的 AppImage 和版本文件，AppDir 由 quick-sharun 生成。
rm -rf -- AppDir dist
mkdir -p dist

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 使用官方包中的图标作为 AppImage 图标。
export ICON=/usr/share/icons/hicolor/256x256/apps/com.obsproject.Studio.png
# 使用官方包中的桌面入口文件。
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

# 模块、模块数据和录制程序不是主程序的动态库依赖，同一次传入。
quick-sharun /usr/bin/obs /usr/bin/obs-ffmpeg-mux \
  /usr/lib/obs-modules /usr/share/obs

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

# 打包成功后用公共脚本记下版本，去掉 epoch 和 pkgrel。
version="$("$SCRIPT_DIR/../common/arch/get_package_version.sh" obs-studio)"
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" \
  dist/obs-studio.AppImage "$version" dist/version.txt
