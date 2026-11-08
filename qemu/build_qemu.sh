#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 安装统一的 Arch AppImage 基础包
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
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

QEMU_PACKAGE_VERSION="$(pacman -Q qemu-desktop | awk '{print $2}')"
QEMU_VERSION="${QEMU_PACKAGE_VERSION#*:}"
QEMU_VERSION="${QEMU_VERSION%-*}"
if [ -z "$QEMU_VERSION" ]; then
  echo "错误：无法解析 QEMU 版本。" >&2
  exit 1
fi

###### 核心打包 ######

# 按 pkgforge-dev/QEMU-AppImage 的官方形式直接收集 QEMU 程序、GTK 等模块和数据文件。
# remote-viewer 是本目录额外提供的 SPICE 客户端；AppRun 完全由 quick-sharun 生成。
quick-sharun \
  /usr/bin/qemu-* \
  /usr/lib/qemu/*.so \
  /usr/bin/remote-viewer \
  /usr/share/qemu

###### 补充简体中文翻译 ######

# 翻译域为 virt-viewer，与 remote-viewer 程序名不同，需在 quick-sharun 裁剪后补回。
install -Dm644 /usr/share/locale/zh_CN/LC_MESSAGES/virt-viewer.mo AppDir/share/locale/zh_CN/LC_MESSAGES/virt-viewer.mo

# 设置 AppImage 内的简体中文界面偏好，不改宿主 LANG、LC_ALL 或输入法配置。
printf '%s\n' 'LANGUAGE=zh_CN' >> AppDir/.env

###### 生成固定名称产物 ######

quick-sharun --make-appimage

printf '%s\n' "$QEMU_VERSION" > "$OUTPATH/version.txt"
