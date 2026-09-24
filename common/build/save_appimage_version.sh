#!/usr/bin/env bash
set -Eeuo pipefail

# 确认最终 AppImage 已生成且非空，再把实际版本写入 version.txt。
if (( $# != 3 )) || [[ -z "$1" || -z "$2" || -z "$3" ]]; then
  echo "用法：$0 <最终 AppImage 路径> <版本号> <version.txt 路径>" >&2
  exit 2
fi

[[ -s "$1" ]] || {
  echo "错误：AppImage 未生成或为空：$1" >&2
  exit 1
}

printf '%s\n' "$2" > "$3"
