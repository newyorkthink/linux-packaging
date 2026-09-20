#!/usr/bin/env bash
set -Eeuo pipefail

APPDIR="${1:-}"
cd -- "$(dirname -- "$APPDIR")"

# 第一次只让 linuxdeploy 创建空 AppDir 的基础目录；没有 desktop 时返回 1 属于正常结果。
set +e
export ARCH=x86_64; linuxdeploy --appdir AppDir --output appimage
set -e
