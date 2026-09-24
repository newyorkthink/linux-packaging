#!/usr/bin/env bash
set -Eeuo pipefail

# 先下载官方 HTTPS 文件；仅在其未通过原 SHA-256 时查询同一 URL 的归档快照。
if (( $# < 3 || $# > 4 )); then
  echo "用法：$0 <官方 HTTPS URL> <输出文件> <SHA-256> [--deb]" >&2
  exit 2
fi

SOURCE_URL="$1"
OUTPUT="$2"
EXPECTED_SHA256="${3#sha256:}"
FORMAT="${4:-}"
DOWNLOAD_FILE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/download_file.sh"

[[ "$SOURCE_URL" == https://* && -n "$OUTPUT" ]] || {
  echo "错误：需要官方 HTTPS URL 和输出文件。" >&2
  exit 1
}
[[ "$EXPECTED_SHA256" =~ ^[[:xdigit:]]{64}$ ]] || {
  echo "错误：无效的 SHA-256：$EXPECTED_SHA256" >&2
  exit 1
}
[[ -z "$FORMAT" || "$FORMAT" == --deb ]] || {
  echo "错误：不支持的格式检查：$FORMAT" >&2
  exit 2
}
[[ -x "$DOWNLOAD_FILE" ]] || {
  echo "错误：公共下载入口不存在或不可执行：$DOWNLOAD_FILE" >&2
  exit 1
}

if "$DOWNLOAD_FILE" "$SOURCE_URL" "$OUTPUT" "$EXPECTED_SHA256"; then
  printf '已从官方来源取得并校验文件：%s\n' "$SOURCE_URL" >&2
else
  # 失败只回退到同一个官方 URL 的历史响应，任何候选文件仍必须通过原 SHA-256。
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
  "$DOWNLOAD_FILE" "$CDX_URL" "$CDX_JSON"
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
    if "$DOWNLOAD_FILE" "$ARCHIVE_URL" "$OUTPUT" "$EXPECTED_SHA256"; then
      ARCHIVE_MATCHED=true
      printf '已从同一官方 URL 的归档取得并校验文件：%s\n' "$timestamp" >&2
      break
    fi
    rm -f -- "$OUTPUT"
  done
  [[ "$ARCHIVE_MATCHED" == true ]] || {
    echo "错误：Internet Archive 快照均未通过原 SHA-256 校验。" >&2
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
printf '%s  %s\n' "$EXPECTED_SHA256" "$OUTPUT" | sha256sum -c - >/dev/null
