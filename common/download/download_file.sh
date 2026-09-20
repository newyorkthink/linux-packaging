#!/usr/bin/env bash
set -Eeuo pipefail

URL="${1:-}"
OUTPUT="${2:-}"
EXPECTED_SHA256="${3:-}"

[[ -n "$URL" && -n "$OUTPUT" ]] || {
  echo "用法：$0 <HTTPS URL> <输出文件> [SHA-256]" >&2
  exit 1
}
[[ "$URL" == https://* ]] || {
  echo "错误：只允许从 HTTPS 地址下载：$URL" >&2
  exit 1
}

OUTPUT_DIR="$(dirname -- "$OUTPUT")"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd -- "$OUTPUT_DIR" && pwd)"
OUTPUT="$OUTPUT_DIR/$(basename -- "$OUTPUT")"
TEMP_FILE="$(mktemp "${OUTPUT}.part.XXXXXX")"

# 下载失败时删除未完成的临时文件，不覆盖原有完整文件。
cleanup() {
  rm -f -- "$TEMP_FILE"
}
trap cleanup EXIT

# 使用统一的失败、重试和超时参数下载到同目录临时文件。
curl --fail --location \
  --proto '=https' \
  --tlsv1.2 \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  --max-time 900 \
  --output "$TEMP_FILE" \
  "$URL"

# 上游提供 SHA-256 时必须在替换正式文件前完成校验。
if [[ -n "$EXPECTED_SHA256" ]]; then
  EXPECTED_SHA256="${EXPECTED_SHA256#sha256:}"
  [[ "$EXPECTED_SHA256" =~ ^[[:xdigit:]]{64}$ ]] || {
    echo "错误：无效的 SHA-256：$EXPECTED_SHA256" >&2
    exit 1
  }
  printf '%s  %s\n' "$EXPECTED_SHA256" "$TEMP_FILE" | sha256sum -c -
fi

# 校验成功后原子替换目标文件。
mv -f -- "$TEMP_FILE" "$OUTPUT"
trap - EXIT
