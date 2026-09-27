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
export OUTNAME=xephyr.AppImage
# CI 没有外层 X display，不能通过 strace 启动 Xephyr 扫描动态库。
export STRACE_MODE=0
# X server 编译时指定了系统 xkbcomp 的绝对路径；改用 AppImage 中的程序。
export PATH_MAPPING='/usr/bin/xkbcomp:${SHARUN_DIR}/bin/xkbcomp'

quick-sharun /usr/bin/Xephyr /usr/bin/xkbcomp

# Arch 的 /usr/share/X11/xkb 可能是符号链接，复制其实际内容。
mkdir -p AppDir/share/X11/xkb AppDir/share/licenses
cp -aL -- /usr/share/X11/xkb/. AppDir/share/X11/xkb/
for package in xorg-server-xephyr xorg-xkbcomp xkeyboard-config; do
  cp -a -- "/usr/share/licenses/$package" "AppDir/share/licenses/$package"
done

mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'ENVIRONMENT'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
ENVIRONMENT

# 无参数时打开 :99；用户传参时保留其 display、尺寸等选项。
# -no-host-grab 避免独占宿主键盘和鼠标，-xkbdir 使用包内键盘规则。
cat > AppDir/bin/90-xephyr-arguments.hook <<'HOOK'
if [ "$#" -eq 0 ]; then
  set -- :99 -screen 1600x900
fi
case "${1:-}" in
  :*) display="$1"; shift; set -- "$display" -xkbdir "${SHARUN_DIR}/share/X11/xkb" -nolisten tcp -no-host-grab "$@" ;;
  *) set -- -xkbdir "${SHARUN_DIR}/share/X11/xkb" -nolisten tcp -no-host-grab "$@" ;;
esac
HOOK

quick-sharun --make-appimage
test -s dist/xephyr.AppImage

version="$(pacman -Q xorg-server-xephyr | awk '{print $2}')"
version="${version#*:}"
version="${version%-*}"
printf '%s\n' "$version" > dist/version.txt
