#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" --base
# 安装官方软件包及运行依赖。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" "keepassxc" fcitx5-qt qt6ct kvantum lxqt-qtplugin glycin libheif xorg-server xorg-server-common xorg-server-xvfb libxcb xcb-util xcb-util-keysyms libxss xcb-util-renderutil xcb-util-wm xcb-util-image xcb-util-cursor libxkbcommon-x11 mesa libglvnd qt6-base qt6-svg libxtst libvdpau libva libx11 libxext libxfixes libxi libxinerama adwaita-qt6 libsm libice libxrandr libxrender libxcursor libxcomposite libxdamage pcsclite

# 清掉上次的打包目录。
"$SCRIPT_DIR/../Common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir dist


# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 使用系统里装好的图标。
export ICON="/usr/share/icons/hicolor/scalable/apps/keepassxc.svg"
# 使用系统里装好的桌面入口文件。
export DESKTOP="/usr/share/applications/org.keepassxc.KeePassXC.desktop"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME="keepassxc.AppImage"
# 官方包依赖 qt6-base，打包时打入 Qt。
export DEPLOY_QT=1

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../Common/build/read_app_version.sh" pacman "keepassxc")"

# 收集程序及其运行依赖。
quick-sharun /usr/bin/keepassxc /usr/bin/keepassxc-cli /usr/bin/keepassxc-proxy /usr/bin/xclip /usr/bin/xclip-copyfile /usr/bin/xclip-cutfile /usr/bin/xclip-pastefile /usr/bin/xdotool /usr/lib/libXtst.so.6 /usr/lib/libxcb-xtest.so.0 /usr/lib/libpcsclite_real.so*

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
ENV

# 本程序专属处理：先改名保留原 sharun 硬链接，避免直接覆盖 keepassxc-proxy 时破坏其他启动入口。
mv -- AppDir/bin/keepassxc-proxy AppDir/bin/keepassxc-proxy.real
# 本程序专属处理：保留原代理二进制，仍由 sharun 加载包内依赖。
mv -- AppDir/shared/bin/keepassxc-proxy AppDir/shared/bin/keepassxc-proxy.real

# 本程序专属处理：保留原 bin 调用入口并转发到 .real 启动器，完整传递参数及标准输入输出。
cat > AppDir/bin/keepassxc-proxy <<'PROXY_BIN'
#!/bin/sh
# 本程序专属处理：通过原 sharun 启动器运行原代理程序。
exec "${0%/*}/keepassxc-proxy.real" "$@"
PROXY_BIN

# 本程序专属处理：让 Qt6 默认登记的 shared/bin 入口也经由 bin/.real 启动器加载包内依赖。
cat > AppDir/shared/bin/keepassxc-proxy <<'PROXY_SHARED'
#!/bin/sh
# 本程序专属处理：从浏览器调用位置转到包内 sharun 启动器。
exec "${0%/*}/../../bin/keepassxc-proxy.real" "$@"
PROXY_SHARED

# 本程序专属处理：为两个代理转发入口添加可执行权限。
chmod +x AppDir/bin/keepassxc-proxy AppDir/shared/bin/keepassxc-proxy

# 本程序专属处理：让 Qt6 按 shared/bin 真实路径查找资源时复用顶层 share 中的翻译和数据。
ln -sfnT ../share AppDir/shared/share

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../Common/build/save_appimage_version.sh" "dist/keepassxc.AppImage" "$VERSION" dist/version.txt
