#!/usr/bin/env bash
set -Eeuo pipefail

APPDIR="$1"
KITTY_DIR="$APPDIR/usr/lib/kitty.app"

# GLFW 扩展由运行时加载，保留这项检查，避免遗漏主程序版本查询不会加载的组件。
test -f "$KITTY_DIR/lib/kitty-extensions/kitty.glfw-x11.so"

# kitty 官方二进制包不包含 libxcb-xkb，部分宿主机也不会预装该库。
cp -a /usr/lib/libxcb-xkb.so.1* "$KITTY_DIR/lib/"

# 使用 Arch 官方 kitty-terminfo 包提供的已编译数据库。
# 不再从 kitty 内部提取、下载源码或调用 tic。
TERMINFO_DIR="$KITTY_DIR/share/terminfo"
TERMINFO_FILE="$TERMINFO_DIR/x/xterm-kitty"

mkdir -p "$TERMINFO_DIR/x"
cp -a /usr/share/terminfo/x/xterm-kitty "$TERMINFO_FILE"

# 在构建环境中提前检查 X11 GLFW 扩展是否仍存在未解析依赖。
if LD_LIBRARY_PATH="$KITTY_DIR/lib" \
  ldd "$KITTY_DIR/lib/kitty-extensions/kitty.glfw-x11.so" \
  | grep -q 'not found'; then
  echo "错误：kitty X11 扩展仍存在未打包的动态库：" >&2
  LD_LIBRARY_PATH="$KITTY_DIR/lib" \
    ldd "$KITTY_DIR/lib/kitty-extensions/kitty.glfw-x11.so" >&2
  exit 1
fi

ICON_FILE="$(find "$KITTY_DIR/share/icons/hicolor" -type f \
  \( -name 'kitty.png' -o -name 'kitty.svg' \) \
  -print | sort -V | tail -n 1)"

cp "$KITTY_DIR/share/applications/kitty.desktop" \
  "$APPDIR/kitty.desktop"

# 避免桌面环境在挂载 AppImage 前检查宿主机中的 kitty。
sed -i '/^TryExec=/d' "$APPDIR/kitty.desktop"

case "$ICON_FILE" in
  *.svg)
    cp "$ICON_FILE" "$APPDIR/kitty.svg"
    ;;
  *)
    cp "$ICON_FILE" "$APPDIR/kitty.png"
    ;;
esac
