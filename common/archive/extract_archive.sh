#!/usr/bin/env bash
set -Eeuo pipefail

ARCHIVE="${1:-}"
OUTPUT_DIR="${2:-}"

[[ -f "$ARCHIVE" && -n "$OUTPUT_DIR" ]] || {
  echo "用法：$0 <归档文件> <输出目录>" >&2
  exit 1
}
[[ "$OUTPUT_DIR" != / ]] || {
  echo "错误：禁止把归档解包到根目录。" >&2
  exit 1
}

mkdir -p "$OUTPUT_DIR"

# 归档格式判断和解包命令统一保留在公共入口；项目脚本只传入文件与目标目录。
case "$ARCHIVE" in
  *.deb)
    command -v dpkg-deb >/dev/null 2>&1 || {
      echo "错误：解包 DEB 需要 dpkg-deb。" >&2
      exit 1
    }
    dpkg-deb -x "$ARCHIVE" "$OUTPUT_DIR"
    ;;
  *.tar | *.tar.gz | *.tgz | *.tar.xz | *.txz | *.tar.bz2 | *.tbz2)
    command -v tar >/dev/null 2>&1 || {
      echo "错误：解包 tar 归档需要 tar。" >&2
      exit 1
    }
    tar -xf "$ARCHIVE" -C "$OUTPUT_DIR"
    ;;
  *)
    echo "错误：不支持的归档格式：$ARCHIVE" >&2
    exit 1
    ;;
esac
