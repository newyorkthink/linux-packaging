#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  echo "用法：$0 <HTTPS URL> <输出 DEB> <预期包名或空字符串> <架构> [--sha256 <摘要>] [--user-agent <标识>] [--url-version-regex <含首个版本捕获组的正则>] [--ipv4-fallback]" >&2
  exit 2
}

(( $# >= 4 )) || usage
URL="$1"
OUTPUT="$2"
PACKAGE="$3"
ARCHITECTURE="$4"
shift 4
HTTPS_URL='^https://[^/?#@[:space:][:cntrl:]]+([/?#][^[:space:][:cntrl:]]*)?$'
[[ "$URL" =~ $HTTPS_URL && "$OUTPUT" == *.deb && ! -d "$OUTPUT" &&
  ( -z "$PACKAGE" || "$PACKAGE" =~ ^[a-z0-9][a-z0-9+.-]*$ ) &&
  "$ARCHITECTURE" =~ ^[a-z0-9][a-z0-9-]*$ ]] || usage

SHA256=
USER_AGENT=
URL_VERSION_REGEX=
IPV4_FALLBACK=false
while (( $# > 0 )); do
  case "$1" in
    --sha256|--user-agent|--url-version-regex)
      (( $# >= 2 )) && [[ -n "$2" ]] || usage
      case "$1" in
        --sha256)
          [[ -z "$SHA256" && "$2" =~ ^[[:xdigit:]]{64}$ ]] || usage
          SHA256="$2"
          ;;
        --user-agent)
          [[ -z "$USER_AGENT" ]] || usage
          USER_AGENT="$2"
          ;;
        --url-version-regex)
          [[ -z "$URL_VERSION_REGEX" ]] || usage
          URL_VERSION_REGEX="$2"
          ;;
      esac
      shift 2
      ;;
    --ipv4-fallback)
      [[ "$IPV4_FALLBACK" == false ]] || usage
      IPV4_FALLBACK=true
      shift
      ;;
    *) usage ;;
  esac
done

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOWNLOAD="$SCRIPT_DIR/download_file.sh"
mkdir -p -- "$(dirname -- "$OUTPUT")"
STAGED="$(mktemp -- "$OUTPUT.part.XXXXXXXX.deb")"
trap 'rm -f -- "$STAGED"' EXIT

# 每次下载均通过现有公共入口，保留最后请求到达的 HTTPS URL。
if ! EFFECTIVE_URL="$("$DOWNLOAD" --print-effective-url "$URL" "$STAGED" "$SHA256" "$USER_AGENT")"; then
  [[ "$IPV4_FALLBACK" == true ]] || exit 1
  echo "常规下载失败，使用 IPv4 和 HTTP/1.1 重试。" >&2
  EFFECTIVE_URL="$("$DOWNLOAD" --print-effective-url --ipv4 --curl-retries 8 --curl-connect-timeout 60 "$URL" "$STAGED" "$SHA256" "$USER_AGENT" curl http1.1 3)"
fi

# 直接从下载到的 DEB 读取版本，校验失败时不替换调用方的文件。
"$SCRIPT_DIR/../archive/check_deb_metadata.sh" "$STAGED" "" "$PACKAGE" "$ARCHITECTURE"
VERSION="$(dpkg-deb -f "$STAGED" Version)"
dpkg --validate-version "$VERSION"

# 官网跳转地址含版本时一并核对，允许 DEB 带发行修订号。
if [[ -n "$URL_VERSION_REGEX" ]]; then
  if [[ "$EFFECTIVE_URL" =~ $URL_VERSION_REGEX ]]; then
    URL_VERSION="${BASH_REMATCH[1]:-}"
    [[ -n "$URL_VERSION" && ( "$VERSION" == "$URL_VERSION" || ( "$VERSION" == *-?* && "${VERSION%-*}" == "$URL_VERSION" ) ) ]] || {
      echo "错误：官方跳转 URL 的版本与 DEB 不一致。" >&2
      exit 1
    }
  elif (( $? == 2 )); then
    echo "错误：网址版本正则无效。" >&2
    exit 2
  fi
fi

mv -fT -- "$STAGED" "$OUTPUT"
printf '%s\n' "$VERSION"
