#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" --base
# 安装官方软件包及运行依赖。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" "i3-wm" xorg-server xorg-server-common xorg-server-xvfb i3status dmenu xss-lock perl-anyevent-i3 perl-json-xs xorg-xrandr xorg-xset xorg-xprop xorg-xmodmap xorg-xsetroot xorg-xmessage

# 清掉上次的打包目录。
"$SCRIPT_DIR/../Common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir dist


# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 本程序专属处理：让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS="i3"
# 使用系统里装好的图标。
export ICON="/usr/share/doc/i3/logo-30.png"
# 使用系统里装好的桌面入口文件。
export DESKTOP="/usr/share/applications/i3.desktop"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME="i3.AppImage"
# 本程序专属处理：将默认配置目录映射到包内路径。
export PATH_MAPPING='
/etc/i3:${SHARUN_DIR}/etc/i3
/etc/i3status.conf:${SHARUN_DIR}/etc/i3status.conf
'

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../Common/build/read_app_version.sh" pacman "i3-wm")"

# 收集程序及其运行依赖。
quick-sharun /usr/bin/i3 /usr/bin/i3bar /usr/bin/i3-config-wizard /usr/bin/i3-dmenu-desktop /usr/bin/i3-dump-log /usr/bin/i3-input /usr/bin/i3-migrate-config-to-v4 /usr/bin/i3-msg /usr/bin/i3-nagbar /usr/bin/i3-save-tree /usr/bin/i3-sensible-editor /usr/bin/i3-sensible-pager /usr/bin/i3-sensible-terminal /usr/bin/i3-with-shmlog /usr/bin/i3status /usr/bin/dmenu /usr/bin/dmenu_path /usr/bin/dmenu_run /usr/bin/stest /usr/bin/xss-lock

# 本程序专属处理：保留 i3 和 i3status 的默认配置。
mkdir -p AppDir/etc/i3
cp -a /etc/i3/. AppDir/etc/i3/
cp -a /etc/i3status.conf AppDir/etc/i3status.conf

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../Common/build/save_appimage_version.sh" "dist/i3.AppImage" "$VERSION" dist/version.txt
