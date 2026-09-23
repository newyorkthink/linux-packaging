#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${1:-}" == --base ]]; then
  shift
  (( $# == 0 )) || {
    echo "用法：$0 --base 或 $0 <Arch 软件包名> [...]" >&2
    exit 1
  }
  PACKAGES=(
    base-devel git wget curl jq binutils patchelf file coreutils findutils
    grep sed gawk tar gzip xz unzip rsync util-linux appstream-glib
    desktop-file-utils zsync ca-certificates
  )
else
  (( $# > 0 )) || {
    echo "用法：$0 --base 或 $0 <Arch 软件包名> [...]" >&2
    exit 1
  }
  PACKAGES=("$@")
fi

# 标准 Arch 构建容器已由共享 Action 提供 yay，包安装逻辑统一放在公共入口。
command -v yay >/dev/null 2>&1 || {
  echo "错误：Arch 构建环境缺少 yay。" >&2
  exit 1
}
yay -S --noconfirm --needed "${PACKAGES[@]}"
