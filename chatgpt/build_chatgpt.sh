#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装 AUR 软件包、运行依赖及 DEB 解包工具。
"$SCRIPT_DIR/../common/arch/install_packages.sh" chatgpt-desktop dpkg fcitx5-gtk bubblewrap cups freetype2 libxi libxtst libxkbfile libva libvdpau wayland pipewire pipewire-audio libcap adwaita-icon-theme noto-fonts-cjk

# 清掉上次的打包目录。
rm -rf -- AppDir dist chatgpt.deb chatgpt-unpacked
mkdir -p AppDir/bin dist

# 下载官方当前 DEB。
"$SCRIPT_DIR/../common/aur/download_deb_source.sh" \
  chatgpt-desktop x86_64 \
  chatgpt.deb

# 解包官方 DEB。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" chatgpt.deb chatgpt-unpacked

# 整个程序目录原样放进 AppDir/bin。
cp -a chatgpt-unpacked/usr/lib/chatgpt/. AppDir/bin/

# 复用官方代码：移除随包附带的 Qt 兼容模块。
rm -f ./AppDir/bin/libqt*_shim.so

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 成品里的应用名。
export APPNAME=ChatGPT
# 包里的真实程序名。
export MAIN_BIN=ChatGPT
# 让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS=ChatGPT
# 使用系统里装好的图标。
export ICON=/usr/share/pixmaps/chatgpt.png
# 使用系统里装好的桌面入口文件。
export DESKTOP=/usr/share/applications/chatgpt.desktop
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME=chatgpt.AppImage
# 这是 GTK 3 程序。输入模块由 quick-sharun 自己收集。
export DEPLOY_GTK=1

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" package-json AppDir/bin/resources/linux-package-metadata.json)"

# 复用官方代码：收集程序及其运行依赖。
quick-sharun ./AppDir/bin/*

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
ENV

# 保留宿主命令的优先级，避免命令沙箱调用包内的 bwrap 包装器。
cat > AppDir/bin/15-chatgpt-host-bwrap.hook <<'HOOK'
export PATH="/usr/bin:/bin${PATH:+:$PATH}:$APPDIR/bin"
HOOK

# 保留原有的 Electron 启动兼容参数，不改变 Codex 命令沙箱。
cat > AppDir/bin/90-chatgpt-arguments.hook <<'HOOK'
set -- --no-sandbox --disable-setuid-sandbox "$@"
HOOK

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" dist/chatgpt.AppImage "$VERSION" dist/version.txt
