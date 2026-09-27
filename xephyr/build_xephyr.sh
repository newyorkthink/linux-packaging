#!/usr/bin/env bash
# 将 Arch 官方 Xephyr 和键盘布局资源封装为嵌套 X server AppImage。
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
"$SCRIPT_DIR/../common/arch/install_packages.sh" \
  xorg-server-xephyr xorg-xkbcomp xkeyboard-config adwaita-icon-theme

rm -rf -- AppDir dist
mkdir -p dist

# Xephyr 上游包不带 desktop 和图标；构建时使用通用显示器图标。
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

export ARCH="$(uname -m)"
export ICON=/usr/share/icons/Adwaita/symbolic/devices/video-display-symbolic.svg
export DESKTOP="$desktop_dir/Xephyr.desktop"
export OUTPATH="$SCRIPT_DIR/dist"
export OUTNAME=Xephyr.AppImage
# CI 没有外层 X display，不能通过 strace 启动 Xephyr 扫描动态库。
export STRACE_MODE=0
# X server 编译时使用的 xkbcomp 和 XKB 路径映射到 AppImage 内。
export PATH_MAPPING='
/usr/bin/xkbcomp:${SHARUN_DIR}/bin/xkbcomp
/usr/share/X11/xkb:${SHARUN_DIR}/share/X11/xkb
'

quick-sharun /usr/bin/Xephyr /usr/bin/xkbcomp

# Arch 的 /usr/share/X11/xkb 可能是符号链接，复制其实际内容。
mkdir -p AppDir/share/X11/xkb AppDir/share/licenses
cp -aL -- /usr/share/X11/xkb/. AppDir/share/X11/xkb/
for package in xorg-server-xephyr xorg-xkbcomp xkeyboard-config; do
  cp -a -- "/usr/share/licenses/$package" "AppDir/share/licenses/$package"
done

quick-sharun --make-appimage

version="$("$SCRIPT_DIR/../common/arch/get_package_version.sh" xorg-server-xephyr)"
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" \
  dist/Xephyr.AppImage "$version" dist/version.txt
