#!/usr/bin/env bash
set -Eeuo pipefail

# 在调用方完成全部产物检查后，按原有顺序写入版本并输出成功提示。
if (( $# != 3 )) || [[ -z "$1" || -z "$2" ]]; then
  echo "用法：$0 <版本号> <version.txt 路径> <成功提示>" >&2
  exit 2
fi

VERSION="$1"
VERSION_FILE="$2"
SUCCESS_MESSAGE="$3"

printf '%s\n' "$VERSION" > "$VERSION_FILE"
echo "$SUCCESS_MESSAGE"
