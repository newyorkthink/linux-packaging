#!/usr/bin/env bash
set -Eeuo pipefail

URL="${1:-}"
OUTPUT="${2:-}"
EXPECTED_CHECKSUM="${3:-}"
USER_AGENT="${4:-}"
DOWNLOADER="${5:-curl}"
HTTP_VERSION="${6:-auto}"
CURL_RETRY_DELAY="${7:-2}"
CURL_DOH_FALLBACK_URL="${8:-}"

# 只有显式选择时使用其他下载器，原有调用继续使用 curl。
[[ "$DOWNLOADER" == curl || "$DOWNLOADER" == wget || "$DOWNLOADER" == aria2c ]] || {
  echo "错误：下载器只能为 curl、wget 或 aria2c。" >&2
  exit 2
}

[[ -n "$URL" && -n "$OUTPUT" ]] || {
  echo "用法：$0 <HTTPS URL> <输出文件> [SHA-256、sha512:<摘要> 或 blake2b:<摘要>] [User-Agent] [curl|wget|aria2c] [auto|http1.1] [curl 重试间隔秒数，0 为指数退避] [DNS 备用解析 HTTPS URL]" >&2
  exit 1
}
[[ "$URL" == https://* ]] || {
  echo "错误：只允许从 HTTPS 地址下载：$URL" >&2
  exit 1
}

# 可选 HTTP 协议与重试间隔仅用于 curl；默认保持现有调用行为。
[[ "$HTTP_VERSION" == auto || "$HTTP_VERSION" == http1.1 ]] && [[ "$CURL_RETRY_DELAY" =~ ^[0-9]+$ ]] || {
  echo "错误：HTTP 协议只能为 auto 或 http1.1，重试间隔必须为非负整数。" >&2
  exit 2
}
[[ "$DOWNLOADER" == curl || ( "$HTTP_VERSION" == auto && "$CURL_RETRY_DELAY" == 2 ) ]] || {
  echo "错误：可选 HTTP 协议与重试间隔只适用于 curl。" >&2
  exit 2
}

# 仅在 curl 模式显式指定 HTTPS 服务时，允许 DNS 解析失败后的备用解析。
[[ -z "$CURL_DOH_FALLBACK_URL" ||
  ( "$DOWNLOADER" == curl && "$CURL_DOH_FALLBACK_URL" =~ ^https://[^[:space:]]+$ ) ]] || {
  echo "错误：DNS 备用解析只支持 curl，且服务地址必须是非空白的 HTTPS URL。" >&2
  exit 2
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
  if [[ "$DOWNLOADER" == aria2c ]]; then
    rm -f -- "${TEMP_FILE}.aria2"
  fi
}
trap cleanup EXIT

# 按需传入客户端标识；显式参数优先于下载器的默认或公共配置。
CURL_USER_AGENT_ARGS=()
if [[ -n "$USER_AGENT" ]]; then
  CURL_USER_AGENT_ARGS=(--user-agent "$USER_AGENT")
fi

# 仅在显式指定时强制 HTTP/1.1，不改变其他调用的协议协商。
CURL_PROTOCOL_ARGS=()
if [[ "$HTTP_VERSION" == http1.1 ]]; then
  CURL_PROTOCOL_ARGS=(--http1.1)
fi

# 使用指定下载器写入同目录临时文件，校验与原子替换共用后续流程。
if [[ "$DOWNLOADER" == wget ]]; then
  # 只接受直达 HTTPS 文件；重定向交由既有 curl 模式处理，不允许降级到 HTTP。
  timeout 900 wget --no-config --no-netrc --no-hsts --no-verbose \
    --max-redirect=0 --secure-protocol=TLSv1_2 \
    --tries=6 --retry-connrefused --retry-on-http-error=429,500,502,503,504 \
    --waitretry=2 --connect-timeout=20 --read-timeout=900 \
    "${CURL_USER_AGENT_ARGS[@]}" \
    --output-document "$TEMP_FILE" \
    "$URL"
elif [[ "$DOWNLOADER" == aria2c ]]; then
  # 只读取仓库内公共下载配置，不加载个人配置。
  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  ARIA2_CONFIG="$SCRIPT_DIR/../config/download/aria2.conf"
  [[ -f "$ARIA2_CONFIG" && -r "$ARIA2_CONFIG" ]] || {
    echo "错误：缺少可读的公共 aria2 下载配置：$ARIA2_CONFIG" >&2
    exit 1
  }
  # 直接下载单个文件，保留临时输出、总超时与后续原摘要校验。
  timeout 900 aria2c --conf-path "$ARIA2_CONFIG" --no-netrc \
    --allow-overwrite=true --auto-file-renaming=false \
    --follow-torrent=false --follow-metalink=false \
    "${CURL_USER_AGENT_ARGS[@]}" \
    --dir "$OUTPUT_DIR" --out "$(basename -- "$TEMP_FILE")" \
    "$URL"
  rm -f -- "${TEMP_FILE}.aria2"
else
  # 使用统一的失败、重试和超时参数下载到同目录临时文件。
  download_with_curl() {
    curl --fail --location \
      "${CURL_PROTOCOL_ARGS[@]}" \
      --proto '=https' \
      --tlsv1.2 \
      --retry 5 \
      --retry-all-errors \
      --retry-delay "$CURL_RETRY_DELAY" \
      --connect-timeout 20 \
      --max-time 900 \
      "${CURL_USER_AGENT_ARGS[@]}" \
      "$@" \
      --output "$TEMP_FILE" \
      "$URL"
  }

  # 先保留原请求；只有显式启用且退出码为 6 时，再使用 HTTPS 备用解析。
  if download_with_curl; then
    :
  else
    DOWNLOAD_STATUS=$?
    if [[ "$DOWNLOAD_STATUS" != 6 || -z "$CURL_DOH_FALLBACK_URL" ]]; then
      exit "$DOWNLOAD_STATUS"
    fi
    printf 'DNS 解析失败，改用 HTTPS 备用解析重试下载。\n' >&2
    download_with_curl --doh-url "$CURL_DOH_FALLBACK_URL"
  fi
fi

# 上游提供摘要时必须在替换正式文件前完成校验；无前缀继续按 SHA-256 处理。
if [[ -n "$EXPECTED_CHECKSUM" ]]; then
  case "$EXPECTED_CHECKSUM" in
    blake2b:*)
      EXPECTED_CHECKSUM="${EXPECTED_CHECKSUM#blake2b:}"
      [[ "$EXPECTED_CHECKSUM" =~ ^[[:xdigit:]]{128}$ ]] || {
        echo "错误：无效的 BLAKE2b-512：$EXPECTED_CHECKSUM" >&2
        exit 1
      }
      b2sum -c <(printf '%s  -\n' "$EXPECTED_CHECKSUM") < "$TEMP_FILE"
      ;;
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
