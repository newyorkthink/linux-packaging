#!/usr/bin/env bash
set -e

rm -rf AppDir || true

ARCH="$(uname -m)"
export ARCH

export ICON=/usr/share/icons/hicolor/scalable/apps/nvtop.svg
export DESKTOP=/usr/share/applications/nvtop.desktop
export OUTPATH=./dist
export OUTNAME="nvtop.AppImage"

# 基本依赖 (Basic dependencies)
yay -S --noconfirm gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux zsync

# nvtop 及用户提供的其他依赖
yay -S --noconfirm nvtop ncurses systemd-libs cmake git libdrm systemd gtest

quick-sharun /usr/bin/nvtop
quick-sharun --make-appimage
