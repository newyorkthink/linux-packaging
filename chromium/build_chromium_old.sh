#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装官方软件包及运行依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" "chromium" qt6-base ibus fcitx5-gtk

# 清掉上次的打包目录。
"$SCRIPT_DIR/../common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir dist
rm -f -- chromium.desktop

# 整个程序目录原样放进 AppDir/bin。
CHROMIUM_DIR=/usr/lib/chromium
test -x "$CHROMIUM_DIR/chromium"
mkdir -p ./AppDir/bin
cp -a "$CHROMIUM_DIR"/. ./AppDir/bin/
cp -v /usr/share/applications/chromium.desktop ./chromium.desktop

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 使用系统里装好的图标。
export ICON="/usr/share/icons/hicolor/256x256/apps/chromium.png"
# 使用系统里装好的桌面入口文件。
export DESKTOP="./chromium.desktop"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME="chromium.AppImage"
# 让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS=chromium
# 这是 GTK 3 程序。输入模块由 quick-sharun 自己收集。
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export URUNTIME_PRELOAD=1
export STRACE_BINARY=chromium
export STRACE_FLAGS='about:blank --no-sandbox'

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" command /usr/bin/chromium --version-file "$HOME/version" --desktop "$DESKTOP" --field 2 -- --version)"

# 收集程序及其运行依赖。
quick-sharun ./AppDir/bin/* /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so /usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so

# 本仓库兼容处理：设置包内简体中文界面语言。
printf '%s\n' 'LANGUAGE=zh-CN' >> ./AppDir/.env

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" "dist/chromium.AppImage" "$VERSION" dist/version.txt
