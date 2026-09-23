#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 安装统一的 Arch AppImage 基础包
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
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

# 读取本次实际安装的 Arch 包版本，并去掉仅用于 Arch 打包排序的 epoch / pkgrel。
NEWSBOAT_PACKAGE_VERSION="$(pacman -Q newsboat | awk '{print $2}')"
NEWSBOAT_VERSION="${NEWSBOAT_PACKAGE_VERSION#*:}"
NEWSBOAT_VERSION="${NEWSBOAT_VERSION%-*}"
[[ -n "$NEWSBOAT_VERSION" ]] || {
  echo "错误：无法解析 Newsboat 版本。" >&2
  exit 1
}

quick-sharun /usr/bin/newsboat /usr/bin/podboat

quick-sharun --make-appimage

# 确认最终 AppImage 文件已经生成且不为空。
test -s ./dist/newsboat.AppImage

# 构建成功后输出统一的软件版本元数据。
printf '%s\n' "$NEWSBOAT_VERSION" > ./dist/version.txt
