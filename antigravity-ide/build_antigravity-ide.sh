#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装 AUR 软件包及运行依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" antigravity-ide fcitx5-gtk libnss_nis bubblewrap gvfs librsvg libvdpau xcb-util-wm libxkbcommon-x11 gcc-libs

# 清掉上次的打包目录。
rm -rf -- AppDir dist antigravity-ide.tar.gz antigravity-ide-unpacked antigravity-ide.version
mkdir -p AppDir/bin dist

# 下载官方当前 tar 包。
"$SCRIPT_DIR/../common/download/download_html_linked_file.sh" \
  https://antigravity.google/download \
  '^https://edgedl[.]me[.]gvt1[.]com/edgedl/release2/[^[:space:]]+/stable/[0-9]+([.][0-9]+)+-[0-9]+/linux-x64/Antigravity%20IDE[.]tar[.]gz$' antigravity-ide.tar.gz \
  --version-regex '/stable/([0-9]+([.][0-9]+)+)-[0-9]+/linux-x64/' --version-file antigravity-ide.version

# 解包官方 tar 包。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" antigravity-ide.tar.gz antigravity-ide-unpacked

# 整个程序目录原样放进 AppDir/bin。
cp -a "antigravity-ide-unpacked/Antigravity IDE/." AppDir/bin/

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 成品里的应用名。
export APPNAME="Antigravity IDE"
# 包里的真实程序名。
export MAIN_BIN=antigravity-ide
# 让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS=antigravity-ide
# 使用系统里装好的图标。
export ICON=/usr/share/pixmaps/antigravity-ide.png
# 使用系统里装好的桌面入口文件。
export DESKTOP=/usr/share/applications/antigravity-ide.desktop
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME=antigravity-ide.AppImage
# 这是 GTK 3 程序。输入模块由 quick-sharun 自己收集。
export DEPLOY_GTK=1
# 复用官方代码：部署 OpenGL 运行依赖。
export DEPLOY_OPENGL=1
# 复用官方代码：部署 Vulkan 运行依赖。
export DEPLOY_VULKAN=1

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" text antigravity-ide.version)"

# 复用官方代码：收集程序及运行时加载的 NSS 模块。
quick-sharun ./AppDir/bin/* /usr/lib/libnss_nis.so* /usr/lib/libnsl.so* /usr/lib/libnss_mdns*_minimal.so*

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
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" dist/antigravity-ide.AppImage "$VERSION" dist/version.txt
