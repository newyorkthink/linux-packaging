#!/usr/bin/env bash
set -e

SOURCE_DIR="$PWD/moderncsv-source"

rm -rf AppDir dist "$SOURCE_DIR" || true

ARCH="$(uname -m)"
export ARCH

export STARTUPWMCLASS=moderncsv
export ICON="$SOURCE_DIR/moderncsv.png"
export DESKTOP="$SOURCE_DIR/moderncsv.desktop"
export OUTPATH=./dist
export OUTNAME="moderncsv.AppImage"
export DEPLOY_OPENGL=1
export QT_LOCATION="$SOURCE_DIR"

# quick-sharun 通用基础依赖，其他 AppImage 的 quick-sharun 打包脚本可直接复用。
yay -S --noconfirm base-devel wget patchelf coreutils appstream-glib desktop-file-utils util-linux zsync strace xorg-server xorg-server-common xorg-server-xvfb

# 安装官方 Modern CSV Qt6 运行时所需的非 Qt 系统依赖，避免混入 Arch 当前 Qt6 运行库。
yay -S --noconfirm openssl mesa libglvnd libxkbcommon-x11 xcb-util xcb-util-cursor xcb-util-image xcb-util-keysyms xcb-util-renderutil xcb-util-wm xdg-utils

mkdir -p "$SOURCE_DIR" dist

# 下载并解压官方 Linux tar 包到 AppDir 外部的独立源目录。
wget --retry-connrefused --tries=30 \
  https://www.moderncsv.com/release/ModernCSV-Linux-v2.4.3.tar.gz \
  -O /tmp/ModernCSV-Linux.tar.gz

tar -xzf /tmp/ModernCSV-Linux.tar.gz -C "$SOURCE_DIR" --strip-components=1

# 使用官方自带 Qt6 运行库、插件、desktop、icon 和真实主程序。
quick-sharun "$SOURCE_DIR/moderncsv"

cat >> AppDir/.env <<'EOF_ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
QT_QPA_PLATFORM=xcb
EOF_ENV

# 启动级 smoke test，防止 Qt/动态链接器错误的产物继续发布。
SMOKE_RC=0
timeout 8s xvfb-run -a ./AppDir/AppRun >/tmp/moderncsv-smoke.log 2>&1 || SMOKE_RC=$?

if [[ "$SMOKE_RC" -ne 0 && "$SMOKE_RC" -ne 124 ]]; then
  cat /tmp/moderncsv-smoke.log
  exit "$SMOKE_RC"
fi

quick-sharun --make-appimage
