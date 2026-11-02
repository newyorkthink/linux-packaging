#!/usr/bin/env bash
set -Eeuo pipefail

URL="${1:-}"
OUTPUT="${2:-}"
EXPECTED_CHECKSUM="${3:-}"
USER_AGENT="${4:-}"

[[ -n "$URL" && -n "$OUTPUT" ]] || {
  echo "用法：$0 <HTTPS URL> <输出文件> [SHA-256 或 sha512:<摘要>] [User-Agent]" >&2
  exit 1
}
[[ "$URL" == https://* ]] || {
  echo "错误：只允许从 HTTPS 地址下载：$URL" >&2
  exit 1
}

# 客户端标识由调用方指定，拒绝把换行内容带入请求头。
[[ "$USER_AGENT" != *$'\r'* && "$USER_AGENT" != *$'\n'* ]] || {
  echo "错误：User-Agent 不得包含换行符。" >&2
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

# 按需传入客户端标识；未指定时保留 curl 默认行为。
CURL_USER_AGENT_ARGS=()
if [[ -n "$USER_AGENT" ]]; then
  CURL_USER_AGENT_ARGS=(--user-agent "$USER_AGENT")
fi

# 使用统一的失败、重试和超时参数下载到同目录临时文件。
curl --fail --location \
  --proto '=https' \
  --tlsv1.2 \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  --max-time 900 \
  "${CURL_USER_AGENT_ARGS[@]}" \
  --output "$TEMP_FILE" \
  "$URL"

# 上游提供摘要时必须在替换正式文件前完成校验；无前缀继续按 SHA-256 处理。
if [[ -n "$EXPECTED_CHECKSUM" ]]; then
  case "$EXPECTED_CHECKSUM" in
    sha512:*)
      EXPECTED_CHECKSUM="${EXPECTED_CHECKSUM#sha512:}"
      [[ "$EXPECTED_CHECKSUM" =~ ^[[:xdigit:]]{128}$ ]] || {
        echo "错误：无效的 SHA-512：$EXPECTED_CHECKSUM" >&2
        exit 1
      }
      printf '%s  %s\n' "$EXPECTED_CHECKSUM" "$TEMP_FILE" | sha512sum -c -
      ;;
    *)
      EXPECTED_CHECKSUM="${EXPECTED_CHECKSUM#sha256:}"
      [[ "$EXPECTED_CHECKSUM" =~ ^[[:xdigit:]]{64}$ ]] || {
        echo "错误：无效的 SHA-256：$EXPECTED_CHECKSUM" >&2
        exit 1
      }
      printf '%s  %s\n' "$EXPECTED_CHECKSUM" "$TEMP_FILE" | sha256sum -c -
      ;;
  esac
fi

# 校验成功后原子替换目标文件。
mv -f -- "$TEMP_FILE" "$OUTPUT"
trap - EXIT
