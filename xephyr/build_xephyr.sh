#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装官方软件包及运行依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" xorg-server-xephyr xorg-xkbcomp xkeyboard-config adwaita-icon-theme

# 清掉上次的打包目录。
rm -rf -- AppDir dist
mkdir -p dist

# 本仓库兼容处理：为缺少桌面入口的 Xephyr 生成临时 desktop 文件。
desktop_dir="$(mktemp -d)"
trap 'rm -rf -- "$desktop_dir"' EXIT
cat > "$desktop_dir/Xephyr.desktop" <<'DESKTOP_ENTRY'
[Desktop Entry]
Type=Application
Name=Xephyr
Comment=Nested X server
Exec=Xephyr
Icon=video-display-symbolic
Categories=System;Utility;
Terminal=false
DESKTOP_ENTRY

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 使用系统里装好的图标。
export ICON=/usr/share/icons/Adwaita/symbolic/devices/video-display-symbolic.svg
# 使用构建时生成的桌面入口。
export DESKTOP="$desktop_dir/Xephyr.desktop"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME=Xephyr.AppImage
# 本仓库兼容处理：在没有外层 X 显示的构建环境中关闭启动跟踪。
export STRACE_MODE=0
# 本仓库兼容处理：将 X server 编译时使用的 xkbcomp 和 XKB 路径映射到包内。
export PATH_MAPPING='
/usr/bin/xkbcomp:${SHARUN_DIR}/bin/xkbcomp
/usr/share/X11/xkb:${SHARUN_DIR}/share/X11/xkb
'

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" pacman xorg-server-xephyr)"

# 收集程序及其运行依赖。
quick-sharun /usr/bin/Xephyr /usr/bin/xkbcomp

# 本仓库兼容处理：跟随 XKB 目录的符号链接，将实际键盘布局资源复制到包内。
mkdir -p AppDir/share/X11/xkb AppDir/share/licenses
cp -aL -- /usr/share/X11/xkb/. AppDir/share/X11/xkb/
# 将所用 Arch 软件包的许可证一并放入包内。
for package in xorg-server-xephyr xorg-xkbcomp xkeyboard-config; do
  cp -a -- "/usr/share/licenses/$package" "AppDir/share/licenses/$package"
done

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" dist/Xephyr.AppImage "$VERSION" dist/version.txt
