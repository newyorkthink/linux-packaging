#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装 AUR 软件包、运行依赖及 DEB 解包工具。
"$SCRIPT_DIR/../common/arch/install_packages.sh" cc-switch-bin fcitx5-gtk dpkg xorg-server xorg-server-common xorg-server-xvfb gtk3 libayatana-appindicator libdbusmenu-glib libdbusmenu-gtk3 webkit2gtk-4.1 libsoup3 glib-networking gsettings-desktop-schemas libsecret libnotify glibc gcc-libs zlib libx11 libxext libxi libxtst libxss libxrandr libxinerama libxcomposite libxdamage libxfixes libxkbcommon-x11 libxkbfile cairo fribidi freetype2 harfbuzz librsvg adwaita-icon-theme

# 清掉上次的打包目录。
rm -rf -- AppDir dist cc-switch.deb cc-switch-unpacked cc-switch.version
mkdir -p AppDir/bin dist

# 下载官方当前 DEB。
"$SCRIPT_DIR/../common/github/download_latest_stable_release_asset.sh" \
  farion1231/cc-switch 'CC-Switch-v{version}-Linux-x86_64.deb' \
  cc-switch.deb cc-switch amd64 > cc-switch.version

# 解包官方 DEB。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" cc-switch.deb cc-switch-unpacked

# 整个程序目录原样放进 AppDir/bin。
cp -a cc-switch-unpacked/usr/bin/. AppDir/bin/

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 成品里的应用名。
export APPNAME=cc-switch
# 包里的真实程序名。
export MAIN_BIN=cc-switch
# 让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS=cc-switch
# 使用系统里装好的图标。
export ICON=/usr/share/icons/hicolor/128x128/apps/cc-switch.png
# 使用系统里装好的桌面入口文件。
export DESKTOP="/usr/share/applications/CC Switch.desktop"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME=cc-switch.AppImage
# 这是 GTK 3 程序。输入模块由 quick-sharun 自己收集。
export DEPLOY_GTK=1

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" text cc-switch.version)"

# 收集程序及其运行依赖。
quick-sharun AppDir/bin/* /usr/lib/libayatana-appindicator3.so.1

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
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" dist/cc-switch.AppImage "$VERSION" dist/version.txt
