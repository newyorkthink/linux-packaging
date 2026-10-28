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
"$SCRIPT_DIR/../common/arch/install_packages.sh" obs-studio fcitx5-qt

rm -rf -- AppDir dist
mkdir -p dist

export ARCH="$(uname -m)"
export ICON=/usr/share/icons/hicolor/256x256/apps/com.obsproject.Studio.png
export DESKTOP=/usr/share/applications/com.obsproject.Studio.desktop
export OUTPATH="$SCRIPT_DIR/dist"
export OUTNAME=obs-studio.AppImage
export DEPLOY_OPENGL=1
export DEPLOY_PIPEWIRE=1
export DEPLOY_PYTHON=1
export DEPLOY_QT=1
export DEPLOY_SDL=1
export DEPLOY_VULKAN=1
# 不加入 AnyLinux 的 self-updater hook。
unset ADD_HOOKS UPINFO GITHUB_REPOSITORY

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

# 打包成功后记下版本，去掉 epoch 和 pkgrel。
version="$(pacman -Q obs-studio | awk '{print $2}')"
version="${version#*:}"
version="${version%-*}"
printf '%s\n' "$version" > dist/version.txt
