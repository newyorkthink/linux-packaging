#!/usr/bin/env bash
# Cursor：下载官方 x64 deb，把整个程序目录放进 AppDir/bin，再交给 quick-sharun。
# quick-sharun 自己生成 AppRun。这里不要写 AppRun.sh。

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 官方 deb 不经过包管理器，运行库要单独装。dpkg 用来解包。中文输入只装 GTK 3 这一套。
"$SCRIPT_DIR/../common/arch/install_packages.sh" \
  dpkg gtk3 fcitx5-gtk \
  libx11 libxrandr libxss libxext libxi libxtst libxkbfile \
  libxcomposite libxdamage libxfixes \
  mesa libglvnd libva libvdpau libva-intel-driver \
  alsa-lib pulseaudio pulseaudio-alsa pipewire-audio \
  libsecret libnotify lsof

# 清掉上次的打包目录。
rm -rf -- AppDir dist cursor-unpacked cursor.deb cursor.desktop co.anysphere.cursor.png
mkdir -p AppDir/bin dist

# 这个地址会跳到当前 x64 deb。
"$SCRIPT_DIR/../common/download/download_file.sh" \
  https://api2.cursor.sh/updates/download/golden/linux-x64-deb/cursor/latest \
  cursor.deb
"$SCRIPT_DIR/../common/archive/extract_archive.sh" cursor.deb cursor-unpacked

# 整个程序目录原样放进 AppDir/bin。
cp -a cursor-unpacked/usr/share/cursor/. AppDir/bin/

# 菜单和图标留在 AppDir 外面，由 quick-sharun 放进包。
cp cursor-unpacked/usr/share/applications/cursor.desktop cursor.desktop
cp cursor-unpacked/usr/share/pixmaps/co.anysphere.cursor.png co.anysphere.cursor.png

# 修正 desktop 文件，让 AppImage 入口直接调用 cursor。
sed -i \
  -e 's#^Exec=.*#Exec=cursor %U#' \
  -e 's#^Icon=.*#Icon=co.anysphere.cursor#' \
  cursor.desktop

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 成品里的应用名。
export APPNAME=Cursor
# 让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS=cursor
# 使用官方包中的图标。
export ICON="$SCRIPT_DIR/co.anysphere.cursor.png"
# 使用修正后的桌面入口文件。
export DESKTOP="$SCRIPT_DIR/cursor.desktop"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME=cursor.AppImage
# 这是 GTK 3 程序。输入模块、NSS 和 pkcs11 由 quick-sharun 自己收集。
export DEPLOY_GTK=1

# 版本写在官方 package.json 里，没有 Arch 包可读。
VERSION="$(awk -F'"' '/"version":/ {print $4; exit}' AppDir/bin/resources/app/package.json)"
printf '%s\n' "$VERSION" > ~/version
grep -q '^X-AppImage-Version=' cursor.desktop \
  || printf 'X-AppImage-Version=%s\n' "$VERSION" >> cursor.desktop

# hostname 不会被自动收进包。
quick-sharun AppDir/bin/* /usr/bin/hostname

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
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" \
  dist/cursor.AppImage "$VERSION" dist/version.txt
