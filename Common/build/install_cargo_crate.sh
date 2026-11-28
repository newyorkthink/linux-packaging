#!/usr/bin/env bash
set -Eeuo pipefail

# crate 名只接受 registry 包名，安装目录由调用方显式指定。
if (( $# != 2 )) || [[ ! "$1" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ || -z "$2" ]]; then
  echo "用法：$0 <crate 名> <安装目录>" >&2
  exit 2
fi

# Cargo 和 crate 所需的系统依赖由构建环境提前准备。
if ! command -v cargo >/dev/null 2>&1; then
  echo '错误：构建环境未安装 Cargo。' >&2
  exit 1
fi

# 由 Cargo 选择版本、编译并安装到指定目录，透传其退出状态。
exec cargo install "$1" --locked --root="$2"
