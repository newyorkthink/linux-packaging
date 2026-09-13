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

###### 校验 QEMU 程序与 GTK 模块 ######

required_binaries=(
  /usr/bin/qemu-system-x86_64
  /usr/bin/qemu-img
  /usr/bin/qemu-io
  /usr/bin/qemu-nbd
  /usr/bin/remote-viewer
)

for binary in "${required_binaries[@]}"; do
  if [[ ! -x "$binary" ]]; then
    echo "缺少必需程序：$binary" >&2
    exit 1
  fi
done

if [[ ! -f /usr/lib/qemu/ui-gtk.so ]]; then
  echo "缺少 QEMU GTK 显示模块：/usr/lib/qemu/ui-gtk.so" >&2
  exit 1
fi

###### 核心打包 ######

# 遵循 pkgforge-dev/QEMU-AppImage 的 quick-sharun 收集形式；
# 本目录只增加目标范围所需的 remote-viewer，并保留官方生成的 AppRun。
quick-sharun \
  /usr/bin/qemu-* \
  /usr/lib/qemu/*.so \
  /usr/bin/remote-viewer \
  /usr/share/qemu

if [[ ! -x AppDir/AppRun ]]; then
  echo "quick-sharun 未生成 AppRun。" >&2
  exit 1
fi

###### 生成固定名称产物 ######

quick-sharun --make-appimage
