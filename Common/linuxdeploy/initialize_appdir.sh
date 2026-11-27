#!/usr/bin/env bash
set -Eeuo pipefail

APPDIR="${1:-}"
LINUXDEPLOY="${2:-linuxdeploy}"
cd -- "$(dirname -- "$APPDIR")"

# 第一次只让 linuxdeploy 创建空 AppDir 的基础目录；没有 desktop 时返回 1 属于正常结果。
set +e
export APPIMAGE_EXTRACT_AND_RUN=1
export ARCH=x86_64; "$LINUXDEPLOY" --appdir AppDir --output appimage
set -e
