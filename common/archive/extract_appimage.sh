#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE="${1:-}"
OUTPUT="${2:-}"
[[ -f "$IMAGE" && -n "$OUTPUT" && "$OUTPUT" != / ]] || {
  echo "用法：$0 <官方 AppImage> <目标目录>" >&2
  exit 1
}

# 官方 Type 2 AppImage 自带解包入口；在独立临时目录执行，避免覆盖其他项目。
IMAGE="$(readlink -f -- "$IMAGE")"
mkdir -p "$OUTPUT"
OUTPUT="$(cd -- "$OUTPUT" && pwd)"
(
  cd "$OUTPUT"
  "$IMAGE" --appimage-extract >/dev/null
)
[[ -x "$OUTPUT/squashfs-root/AppRun" ]] || {
  echo "错误：官方 AppImage 缺少 AppRun。" >&2
  exit 1
}
