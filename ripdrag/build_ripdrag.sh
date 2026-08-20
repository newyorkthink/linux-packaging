#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

rm -rf AppDir || true
mkdir -p dist
rm -f dist/ripdrag-*-x86_64.AppImage

ARCH="$(uname -m)"
export ARCH
export OUTPATH=./dist
export MAIN_BIN=ripdrag
export DEPLOY_GTK=1
export DEPLOY_GDK=1
export DEPLOY_GLYCIN=1

# 安装编译、GTK4 运行组件和 AppImage 打包所需依赖。
yay -S --needed --noconfirm \
  base-devel \
  curl \
  desktop-file-utils \
  gdk-pixbuf2 \
  glycin \
  gtk4 \
  hicolor-icon-theme \
  librsvg \
  rust \
  shared-mime-info \
  xorg-server \
  xorg-server-common \
  xorg-server-xvfb

# 由 Cargo 直接安装 crates.io 上的最新稳定版，避免单独请求 crates.io API 被拒绝。
rm -rf /tmp/ripdrag-install
cargo install ripdrag \
  --locked \
  --root /tmp/ripdrag-install

RIPDRAG_BIN=/tmp/ripdrag-install/bin/ripdrag
test -x "$RIPDRAG_BIN"
VERSION_OUTPUT="$("$RIPDRAG_BIN" --version)"
printf '%s\n' "$VERSION_OUTPUT"
VERSION="${VERSION_OUTPUT##* }"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
  echo "错误：无法从 ripdrag --version 确认版本号：$VERSION_OUTPUT" >&2
  exit 1
fi
export VERSION
export OUTNAME="ripdrag-${VERSION}-x86_64.AppImage"

# ripdrag 上游没有提供可直接用于 AppImage 的 desktop 和图标，在构建时生成。
cat > /tmp/ripdrag.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=ripdrag
Comment=Drag and drop files to and from the terminal
Exec=ripdrag %F
Icon=ripdrag
Terminal=false
Categories=Utility;FileTools;
StartupNotify=true
DESKTOP

cat > /tmp/ripdrag.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <rect x="8" y="8" width="112" height="112" rx="22" fill="#24273a"/>
  <path d="M64 26v48m0 0 18-18M64 74 46 56" fill="none" stroke="#cad3f5" stroke-width="10" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M34 88h60" fill="none" stroke="#8aadf4" stroke-width="10" stroke-linecap="round"/>
</svg>
SVG

export DESKTOP=/tmp/ripdrag.desktop
export ICON=/tmp/ripdrag.svg

desktop-file-validate "$DESKTOP"

# 收集 ripdrag、GTK4、图像加载组件及其运行依赖并生成 AppImage。
quick-sharun "$RIPDRAG_BIN"

# 默认使用已经验证有效的 GTK4 Adwaita 黑色主题。
cat > AppDir/bin/00-ripdrag-dark-theme.hook <<'HOOK'
#!/bin/sh

export GTK_THEME=Adwaita:dark
HOOK
chmod +x AppDir/bin/00-ripdrag-dark-theme.hook

quick-sharun --make-appimage

APPIMAGE="$OUTPATH/$OUTNAME"
test -s "$APPIMAGE"
chmod +x "$APPIMAGE"
APPIMAGE_EXTRACT_AND_RUN=1 "$APPIMAGE" --version

echo "已生成：$APPIMAGE"
