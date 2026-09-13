#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

export ARCH="$(uname -m)"
export DESKTOP="$SCRIPT_DIR/qemu.desktop"
export ICON="$SCRIPT_DIR/qemu.svg"
export OUTPATH="./dist"
export OUTNAME="qemu.AppImage"
export STRACE_MODE=0

# 安装 quick-sharun / AppImage 打包所需的最小基础工具。
yay -S --noconfirm base-devel git wget curl jq binutils patchelf file coreutils findutils \
  grep sed gawk tar gzip xz unzip rsync util-linux appstream-glib \
  desktop-file-utils zsync ca-certificates

# 安装当前稳定版 QEMU 桌面组件、常用磁盘工具和 SPICE 客户端。
yay -S --noconfirm qemu-desktop qemu-tools virt-viewer

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

qemu_inputs=()
while IFS= read -r binary; do
  qemu_inputs+=("$binary")
done < <(find /usr/bin -maxdepth 1 \( -type f -o -type l \) -name 'qemu-*' -print | sort)

qemu_inputs+=(/usr/bin/remote-viewer)

for resource_dir in /usr/lib/qemu /usr/share/qemu; do
  if [[ -d "$resource_dir" ]]; then
    qemu_inputs+=("$resource_dir")
  fi
done

# 一次收集 QEMU 程序、工具、模块、固件数据和 remote-viewer 的真实运行依赖。
quick-sharun "${qemu_inputs[@]}"

if [[ ! -x AppDir/AppRun ]]; then
  echo "quick-sharun 未生成 AppRun。" >&2
  exit 1
fi

# 使用 QEMU 专用入口支持多工具分派，并保留 GTK 剪贴板参数兼容处理。
install -m 0755 "$SCRIPT_DIR/AppRun" AppDir/AppRun

# 生成固定名称的最终 AppImage。
quick-sharun --make-appimage
