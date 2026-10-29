#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装 AUR 软件包及运行依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" visual-studio-code-bin fcitx5-gtk libdbusmenu-glib libx11 libxext libxi libxrandr libxtst libxkbcommon libxcomposite libxdamage libxfixes mesa libglvnd libva libvdpau xorg-server xorg-server-common xorg-server-xvfb

# 清掉上次的打包目录。
rm -rf -- AppDir dist vscode.tar.gz vscode-unpacked
mkdir -p AppDir/bin dist

# 下载官方当前 tar 包。
"$SCRIPT_DIR/../common/download/download_file.sh" \
  'https://code.visualstudio.com/sha/download?build=stable&os=linux-x64' \
  vscode.tar.gz

# 解包官方 tar 包。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" vscode.tar.gz vscode-unpacked

# 整个程序目录原样放进 AppDir/bin。
cp -a vscode-unpacked/VSCode-linux-x64/. AppDir/bin/

# 准备协议入口目录。
mkdir -p AppDir/share/applications
# 使用系统里装好的协议入口文件。
cp -a /usr/share/applications/com.microsoft.VSCode.UrlHandler.desktop AppDir/share/applications/code-url-handler.desktop

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 成品里的应用名。
export APPNAME=Code
# 包里的真实程序名。
export MAIN_BIN=code
# 让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS=com.microsoft.VSCode
# 使用系统里装好的图标。
export ICON=/usr/share/pixmaps/vscode.png
# 使用系统里装好的桌面入口文件。
export DESKTOP=/usr/share/applications/com.microsoft.VSCode.desktop
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME=vscode.AppImage
# 这是 GTK 3 程序。输入模块由 quick-sharun 自己收集。
export DEPLOY_GTK=1
# 复用官方代码：部署 OpenGL 运行依赖。
export DEPLOY_OPENGL=1
# 复用官方代码：部署 Vulkan 运行依赖。
export DEPLOY_VULKAN=1

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" package-json AppDir/bin/resources/app/package.json --version-file "$HOME/version" --desktop "$DESKTOP" --desktop AppDir/share/applications/code-url-handler.desktop)"

# 复用官方代码：删除上游明确标为不需要保留的运行组件。
rm -rf ./AppDir/bin/resources/app/node_modules/@github/copilot-linuxmusl-x64

# 收集程序及其运行依赖。
quick-sharun AppDir/bin/*

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
ENV

# 文件内容复用官方代码：保留命令行入口、远程转发及启动检查。
cp -a "$SCRIPT_DIR/cli-router.hook" AppDir/bin/cli-router.hook

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" dist/vscode.AppImage "$VERSION" dist/version.txt
