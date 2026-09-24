#!/usr/bin/env bash
set -Eeuo pipefail

# 只清理调用方明确列出的项目一级目录；--skip-create 指定清理后留空的目录。
if (( $# < 3 )) || [[ "${2:-}" != --skip-create ]]; then
  echo "用法：$0 <项目根目录> --skip-create <仅清理的目录名> <清理并创建的目录名> [...]" >&2
  exit 2
fi

[[ "$(uname -m)" == x86_64 ]] || {
  echo "错误：只支持 x86_64。" >&2
  exit 1
}

PROJECT_DIR="$(cd -- "$1" && pwd -P)"
[[ "$PROJECT_DIR" != / ]] || {
  echo "错误：项目根目录不能是 /。" >&2
  exit 1
}
shift 2

# 先验证全部参数，再执行任何删除，防止部分清理后才发现不安全的路径。
for name in "$@"; do
  [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ && "$name" != . && "$name" != .. ]] || {
    echo "错误：只能清理项目根目录下的一级目录：$name" >&2
    exit 1
  }
done

for name in "$@"; do
  rm -rf -- "$PROJECT_DIR/$name"
done
shift
for name in "$@"; do
  mkdir -p -- "$PROJECT_DIR/$name"
done
