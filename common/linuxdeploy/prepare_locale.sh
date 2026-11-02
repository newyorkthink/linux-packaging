#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

LOCALE_SOURCE="${1:-}"
CHARMAP="${2:-}"
OUTPUT_DIR="${3:-}"

# locale 源名称、字符集和完整输出目录均由调用方指定。
if (( $# != 3 )) || [[ -z "$LOCALE_SOURCE" || -z "$CHARMAP" || -z "$OUTPUT_DIR" ]]; then
  echo "用法：$0 <locale 源名称> <字符集> <完整输出目录>" >&2
  exit 1
fi

# 使用明确的输出路径，拒绝向根目录写入 locale 文件。
OUTPUT_DIR="$(readlink -m -- "$OUTPUT_DIR")"
[[ "$OUTPUT_DIR" != / ]] || {
  echo "错误：禁止向根目录生成 locale。" >&2
  exit 1
}

# 创建 locale 输出目录的父目录，不修改宿主机的 locale 配置。
mkdir -p -- "$(dirname -- "$OUTPUT_DIR")"

# 按独立目录生成 locale 数据，供应用 AppRun 通过 LOCPATH 使用。
localedef --no-archive -i "$LOCALE_SOURCE" -f "$CHARMAP" "$OUTPUT_DIR"
