#!/usr/bin/env bash
set -Eeuo pipefail

# 先下载官方 HTTPS 文件；仅在其未通过原摘要时查询同一 URL 的归档快照。
if (( $# < 3 )); then
  echo "用法：$0 <官方 HTTPS URL> <输出文件> <SHA-256 或 sha512:摘要> [--deb] [--user-agent <客户端标识>]" >&2
  exit 2
fi

SOURCE_URL="$1"
OUTPUT="$2"
EXPECTED_CHECKSUM="$3"
CHECKSUM_COMMAND=sha256sum
CHECKSUM_NAME=SHA-256
FORMAT=""
USER_AGENT=""
shift 3

# 兼容旧接口显式传入的空格式参数。
if (( $# == 1 )) && [[ -z "$1" ]]; then
  shift
fi

# 可选格式检查和客户端标识可以组合，旧参数保持兼容。
while (( $# > 0 )); do
  case "$1" in
    --deb)
      [[ -z "$FORMAT" ]] || {
        echo "错误：--deb 不得重复指定。" >&2
        exit 2
      }
      FORMAT=--deb
      shift
      ;;
    --user-agent)
      if (( $# < 2 )) || [[ -z "${2:-}" || "${2:-}" == --* || -n "$USER_AGENT" ]]; then
        echo "错误：--user-agent 需要一个非空客户端标识，且不得重复指定。" >&2
        exit 2
      fi
      USER_AGENT="$2"
      shift 2
      ;;
    *)
      echo "错误：不支持的参数：$1" >&2
      exit 2
      ;;
  esac
done

# 在发起下载前检查客户端标识，避免无效请求进入归档回退。
[[ "$USER_AGENT" != *$'\r'* && "$USER_AGENT" != *$'\n'* ]] || {
  echo "错误：User-Agent 不得包含换行符。" >&2
  exit 2
}
DOWNLOAD_FILE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/download_file.sh"

[[ "$SOURCE_URL" == https://* && -n "$OUTPUT" ]] || {
  echo "错误：需要官方 HTTPS URL 和输出文件。" >&2
  exit 1
}
# 无前缀或 sha256: 保持原 SHA-256 语义，SHA-512 必须显式指定算法。
if [[ "$EXPECTED_CHECKSUM" == sha512:* ]]; then
  EXPECTED_CHECKSUM="${EXPECTED_CHECKSUM#sha512:}"
  CHECKSUM_COMMAND=sha512sum
  CHECKSUM_NAME=SHA-512
  CHECKSUM_PATTERN='^[[:xdigit:]]{128}$'
else
  EXPECTED_CHECKSUM="${EXPECTED_CHECKSUM#sha256:}"
  CHECKSUM_PATTERN='^[[:xdigit:]]{64}$'
fi
[[ "$EXPECTED_CHECKSUM" =~ $CHECKSUM_PATTERN ]] || {
  echo "错误：无效的 $CHECKSUM_NAME：$EXPECTED_CHECKSUM" >&2
  exit 1
}
DOWNLOAD_CHECKSUM="$EXPECTED_CHECKSUM"
[[ "$CHECKSUM_NAME" == SHA-256 ]] || DOWNLOAD_CHECKSUM="sha512:$EXPECTED_CHECKSUM"
[[ -z "$FORMAT" || "$FORMAT" == --deb ]] || {
  echo "错误：不支持的格式检查：$FORMAT" >&2
  exit 2
}
[[ -x "$DOWNLOAD_FILE" ]] || {
  echo "错误：公共下载入口不存在或不可执行：$DOWNLOAD_FILE" >&2
  exit 1
}

if "$DOWNLOAD_FILE" "$SOURCE_URL" "$OUTPUT" "$DOWNLOAD_CHECKSUM" "$USER_AGENT"; then
  printf '已从官方来源取得并校验文件：%s\n' "$SOURCE_URL" >&2
else
  # 失败只回退到同一个官方 URL 的历史响应，任何候选文件仍必须通过原摘要。
  rm -f -- "$OUTPUT"
  SOURCE_URL_ENCODED="$(jq -rn --arg value "$SOURCE_URL" '$value|@uri')"
  [[ -n "$SOURCE_URL_ENCODED" ]] || {
    echo "错误：无法编码官方 URL，不能查询 Internet Archive。" >&2
    exit 1
  }
  CDX_URL="https://web.archive.org/cdx/search/cdx?url=${SOURCE_URL_ENCODED}&output=json&fl=timestamp,original,statuscode,mimetype,digest&filter=statuscode:200&limit=20&sort=reverse"
  CDX_JSON="$(mktemp "${OUTPUT}.cdx.XXXXXX")"
  cleanup() {
    rm -f -- "$CDX_JSON"
  }
  trap cleanup EXIT
  "$DOWNLOAD_FILE" "$CDX_URL" "$CDX_JSON" "" "$USER_AGENT"
  jq -e 'type == "array" and length > 1' "$CDX_JSON" >/dev/null || {
    echo "错误：Internet Archive 未返回可用快照列表。" >&2
    exit 1
  }

  mapfile -t WAYBACK_TIMESTAMPS < <(
    jq -r '.[1:][]? | if type == "array" then .[0] // empty else empty end' "$CDX_JSON"
  )
  (( ${#WAYBACK_TIMESTAMPS[@]} > 0 )) || {
    echo "错误：Internet Archive 中没有找到官方 URL 的可用快照。" >&2
    exit 1
  }

  ARCHIVE_MATCHED=false
  for timestamp in "${WAYBACK_TIMESTAMPS[@]}"; do
    [[ "$timestamp" =~ ^[0-9]{14}$ ]] || continue
    ARCHIVE_URL="https://web.archive.org/web/${timestamp}id_/${SOURCE_URL}"
    if "$DOWNLOAD_FILE" "$ARCHIVE_URL" "$OUTPUT" "$DOWNLOAD_CHECKSUM" "$USER_AGENT"; then
      ARCHIVE_MATCHED=true
      printf '已从同一官方 URL 的归档取得并校验文件：%s\n' "$timestamp" >&2
      break
    fi
    rm -f -- "$OUTPUT"
  done
  [[ "$ARCHIVE_MATCHED" == true ]] || {
    echo "错误：Internet Archive 快照均未通过原 $CHECKSUM_NAME 校验。" >&2
    exit 1
  }
fi

[[ -s "$OUTPUT" ]] || {
  echo "错误：下载文件不存在或为空：$OUTPUT" >&2
  exit 1
}
if [[ "$FORMAT" == --deb ]]; then
  file "$OUTPUT" | grep -qi 'Debian binary package' || {
    echo "错误：下载内容不是有效的 Debian 软件包：$OUTPUT" >&2
    exit 1
  }
fi
printf '%s  %s\n' "$EXPECTED_CHECKSUM" "$OUTPUT" | "$CHECKSUM_COMMAND" -c - >/dev/null
