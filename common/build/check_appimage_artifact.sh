#!/usr/bin/env bash
set -Eeuo pipefail

# 在应用自行决定检查顺序后，核对最终 AppImage 并写出发布用的 SHA-256 文件。
if (( $# != 2 )) || [[ -z "$1" || -z "$2" ]]; then
  echo "用法：$0 <最终 AppImage 路径> <SHA-256 文件路径>" >&2
  exit 2
fi

APPIMAGE="$1"
SHA256_FILE="$2"

[[ -x "$APPIMAGE" && -s "$APPIMAGE" ]] || {
  echo "错误：最终 AppImage 不存在、为空或不可执行：$APPIMAGE" >&2
  exit 1
}

sha256sum "$APPIMAGE" | tee "$SHA256_FILE"
