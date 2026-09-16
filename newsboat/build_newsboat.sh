#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

rm -rf AppDir || true
rm -f "$SCRIPT_DIR/newsboat.build.desktop"

ARCH="$(uname -m)"
export ARCH

export STARTUPWMCLASS=newsboat
export ICON=/usr/share/icons/hicolor/scalable/apps/newsboat.svg
export DESKTOP="$SCRIPT_DIR/newsboat.build.desktop"
export OUTPATH=./dist
export OUTNAME="newsboat.AppImage"

# 基本依赖
yay -S --noconfirm gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux zsync

# newsboat 及用户提供的依赖
yay -S --noconfirm newsboat curl hicolor-icon-theme json-c libxml2 sqlite stfl buku kitty perl python ruby asciidoctor git rust swig

VERSION="$(pacman -Q newsboat | awk '{print $2; exit}')"
if [[ -z "$VERSION" ]]; then
  echo "Error: failed to read newsboat package version." >&2
  exit 1
fi
cp -f "$SCRIPT_DIR/newsboat.desktop" "$DESKTOP"
if grep -q '^X-AppImage-Version=' "$DESKTOP"; then
  sed -i "s|^X-AppImage-Version=.*|X-AppImage-Version=$VERSION|" "$DESKTOP"
else
  printf 'X-AppImage-Version=%s\n' "$VERSION" >> "$DESKTOP"
fi
printf '%s\n' "$VERSION" > ~/version

quick-sharun /usr/bin/newsboat /usr/bin/podboat

quick-sharun --make-appimage
