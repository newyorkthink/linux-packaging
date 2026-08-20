#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

rm -rf AppDir || true

ARCH="$(uname -m)"
export ARCH

export STARTUPWMCLASS=newsboat
export ICON=/usr/share/icons/hicolor/scalable/apps/newsboat.svg
export DESKTOP="$SCRIPT_DIR/newsboat.desktop"
export OUTPATH=./dist
export OUTNAME="newsboat.AppImage"

# 基本依赖
yay -S --noconfirm gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux zsync

# newsboat 及用户提供的依赖
yay -S --noconfirm newsboat curl hicolor-icon-theme json-c libxml2 sqlite stfl buku kitty perl python ruby asciidoctor git rust swig

quick-sharun /usr/bin/newsboat /usr/bin/podboat

quick-sharun --make-appimage
