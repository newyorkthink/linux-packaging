#!/usr/bin/env bash
set -Eeuo pipefail

# 下载 HTTPS 页面，按调用方给出的正则选出唯一资源链接，再下载该文件。
# 页面地址、正则和输出路径都由调用方传入。

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOWNLOAD_FILE="$SCRIPT_DIR/download_file.sh"

PAGE_URL="${1:-}"
LINK_REGEX="${2:-}"
OUTPUT="${3:-}"
EXPECTED_SHA256="${4:-}"

[[ -n "$PAGE_URL" && -n "$LINK_REGEX" && -n "$OUTPUT" ]] || {
  echo "用法：$0 <HTTPS 页面> <资源 URL 正则> <输出文件> [SHA-256]" >&2
  exit 1
}
[[ "$PAGE_URL" == https://* ]] || {
  echo "错误：页面只允许 HTTPS：$PAGE_URL" >&2
  exit 1
}

PAGE_FILE="$(mktemp)"
cleanup() { rm -f -- "$PAGE_FILE"; }
trap cleanup EXIT

"$DOWNLOAD_FILE" "$PAGE_URL" "$PAGE_FILE"

mapfile -t LINKS < <(
  grep -oE 'https://[^[:space:]"'\''<>]+' "$PAGE_FILE" \
    | grep -xE "$LINK_REGEX" || true
)
if (( ${#LINKS[@]} != 1 )); then
  echo "错误：页面中符合正则的 HTTPS 链接不是唯一一个：${#LINKS[@]}。" >&2
  exit 1
fi

echo "下载：${LINKS[0]}" >&2
if [[ -n "$EXPECTED_SHA256" ]]; then
  "$DOWNLOAD_FILE" "${LINKS[0]}" "$OUTPUT" "$EXPECTED_SHA256"
else
  "$DOWNLOAD_FILE" "${LINKS[0]}" "$OUTPUT"
fi