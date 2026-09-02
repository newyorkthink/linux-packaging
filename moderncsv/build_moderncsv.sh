#!/usr/bin/env bash
set -e

rm -rf AppDir dist || true

ARCH="$(uname -m)"
export ARCH

export STARTUPWMCLASS=moderncsv
export ICON=./AppDir/bin/moderncsv.png
export DESKTOP=./AppDir/bin/moderncsv.desktop
export OUTPATH=./dist
export OUTNAME="moderncsv.AppImage"
export DEPLOY_OPENGL=1

# quick-sharun 通用基础依赖，其他 AppImage 的 quick-sharun 打包脚本可直接复用。
yay -S --noconfirm base-devel wget patchelf coreutils appstream-glib desktop-file-utils util-linux zsync strace xorg-server xorg-server-common xorg-server-xvfb

# 安装 Modern CSV 运行所需依赖。
yay -S --noconfirm qt6-base qt6-5compat fcitx5-qt openssl mesa libglvnd

mkdir -p AppDir/bin dist

# 下载官方 Linux tar 包；上游压缩包包含 moderncsvv2.4.3 顶层目录，解压时去掉这一层并保留全部官方文件。
wget --retry-connrefused --tries=30 \
  https://www.moderncsv.com/release/ModernCSV-Linux-v2.4.3.tar.gz \
  -O /tmp/ModernCSV-Linux.tar.gz

tar -xzf /tmp/ModernCSV-Linux.tar.gz -C AppDir/bin --strip-components=1

# 直接使用官方 moderncsv.desktop、moderncsv.png 和真实主程序，不额外生成 desktop / icon。
quick-sharun ./AppDir/bin/moderncsv

cat >> AppDir/.env <<'EOF_ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
QT_QPA_PLATFORM=xcb
EOF_ENV

quick-sharun --make-appimage
