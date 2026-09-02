#!/usr/bin/env bash
set -e

rm -rf AppDir dist || true

ARCH="$(uname -m)"
export ARCH

export STARTUPWMCLASS=moderncsv
export ICON=/opt/moderncsv/moderncsv.png
export DESKTOP=/usr/share/applications/moderncsv.desktop
export OUTPATH=./dist
export OUTNAME="moderncsv.AppImage"
export DEPLOY_OPENGL=1

yay -S --noconfirm moderncsv-bin qt6-base qt6-5compat fcitx5-qt openssl mesa libglvnd

quick-sharun /usr/bin/moderncsv

cat >> AppDir/.env <<'EOF_ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
QT_QPA_PLATFORM=xcb
EOF_ENV

quick-sharun --make-appimage
