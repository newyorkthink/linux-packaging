#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

###### 设置 AppImage 元数据 ######

export ARCH="$(uname -m)"
export DESKTOP="$SCRIPT_DIR/qemu.desktop"
export ICON="$SCRIPT_DIR/qemu.svg"
export OUTPATH="./dist"
export OUTNAME="qemu.AppImage"
export STRACE_MODE=0

###### 准备 Arch Linux 构建环境 ######

yay -S --noconfirm base-devel git wget curl jq binutils patchelf file coreutils findutils \
  grep sed gawk tar gzip xz unzip rsync util-linux appstream-glib \
  desktop-file-utils zsync ca-certificates

yay -S --noconfirm qemu-desktop qemu-tools qemu-ui-gtk virt-viewer

###### 核心打包 ######

# 按 pkgforge-dev/QEMU-AppImage 的官方形式直接收集 QEMU 程序、GTK 等模块和数据文件。
# remote-viewer 是本目录额外提供的 SPICE 客户端；AppRun 完全由 quick-sharun 生成。
quick-sharun \
  /usr/bin/qemu-* \
  /usr/lib/qemu/*.so \
  /usr/bin/remote-viewer \
  /usr/share/qemu

###### 生成固定名称产物 ######

quick-sharun --make-appimage
