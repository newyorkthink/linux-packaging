#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 安装统一的 Arch AppImage 基础包
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base

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

# 读取本次实际安装的 Arch 包版本，并去掉仅用于 Arch 打包排序的 epoch / pkgrel。
NVTOP_PACKAGE_VERSION="$(pacman -Q nvtop | awk '{print $2}')"
NVTOP_VERSION="${NVTOP_PACKAGE_VERSION#*:}"
NVTOP_VERSION="${NVTOP_VERSION%-*}"
[[ -n "$NVTOP_VERSION" ]] || {
  echo "错误：无法解析 nvtop 版本。" >&2
  exit 1
}

quick-sharun /usr/bin/nvtop
quick-sharun --make-appimage

# 确认最终 AppImage 文件已经生成且不为空。
test -s ./dist/nvtop.AppImage

# 构建成功后输出统一的软件版本元数据。
printf '%s\n' "$NVTOP_VERSION" > ./dist/version.txt
