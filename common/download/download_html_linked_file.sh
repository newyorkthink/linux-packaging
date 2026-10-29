#!/usr/bin/env bash
set -Eeuo pipefail

# 下载 HTTPS 页面，按调用方给出的正则选出唯一资源链接，再下载该文件。
# 页面地址、正则和输出路径都由调用方传入。

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOWNLOAD_FILE="$SCRIPT_DIR/download_file.sh"

# 显示公共页面下载入口的参数用法。
usage() {
  echo "用法：$0 <HTTPS 页面> <资源 URL 正则> <输出文件> [SHA-256] [--version-regex <版本正则> --version-file <版本文件>]" >&2
  exit 1
}

# 保留 Bash 正则匹配状态，区分未匹配和语法错误。
check_version_regex() {
  [[ "" =~ $1 ]]
}

PAGE_URL="${1:-}"
LINK_REGEX="${2:-}"
OUTPUT="${3:-}"
EXPECTED_SHA256=
VERSION_REGEX=
VERSION_FILE=

[[ -n "$PAGE_URL" && -n "$LINK_REGEX" && -n "$OUTPUT" ]] || usage
[[ "$PAGE_URL" == https://* ]] || {
  echo "错误：页面只允许 HTTPS：$PAGE_URL" >&2
  exit 1
}

# 保留可选摘要参数，并解析成对使用的版本输出选项。
shift 3
if (( $# > 0 )) && [[ "$1" != --* ]]; then
  EXPECTED_SHA256="$1"
  shift
fi
while (( $# > 0 )); do
  case "$1" in
    --version-regex|--version-file)
      (( $# >= 2 )) && [[ -n "$2" ]] || usage
      if [[ "$1" == --version-regex ]]; then
        [[ -z "$VERSION_REGEX" ]] || usage
        VERSION_REGEX="$2"
      else
        [[ -z "$VERSION_FILE" ]] || usage
        VERSION_FILE="$2"
      fi
      shift 2
      ;;
    *) usage ;;
  esac
done
if [[ -n "$VERSION_REGEX" || -n "$VERSION_FILE" ]]; then
  [[ -n "$VERSION_REGEX" && -n "$VERSION_FILE" ]] || usage
  regex_status=0
  check_version_regex "$VERSION_REGEX" || regex_status=$?
  if (( regex_status == 2 )); then
    echo "错误：版本正则不是有效的 Bash 扩展正则表达式。" >&2
    exit 1
  fi
  if [[ "$(realpath -m -- "$OUTPUT")" == "$(realpath -m -- "$VERSION_FILE")" ]]; then
    echo "错误：下载文件与版本文件不能使用相同路径。" >&2
    exit 1
  fi
fi

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

# 从选中的资源链接提取版本，不改变原有的链接筛选规则。
if [[ -n "$VERSION_REGEX" ]]; then
  if [[ "${LINKS[0]}" =~ $VERSION_REGEX ]]; then
    VERSION="${BASH_REMATCH[1]:-}"
  else
    echo "错误：资源 URL 不匹配版本正则。" >&2
    exit 1
  fi
  [[ -n "$VERSION" && "$VERSION" != *[[:space:]]* ]] || {
    echo "错误：版本正则的第一个捕获组为空或包含空白字符。" >&2
    exit 1
  }
fi

echo "下载：${LINKS[0]}" >&2
if [[ -n "$EXPECTED_SHA256" ]]; then
  "$DOWNLOAD_FILE" "${LINKS[0]}" "$OUTPUT" "$EXPECTED_SHA256"
else
  "$DOWNLOAD_FILE" "${LINKS[0]}" "$OUTPUT"
fi

# 文件成功下载并通过可选校验后，再保存版本。
if [[ -n "$VERSION_FILE" ]]; then
  printf '%s\n' "$VERSION" > "$VERSION_FILE"
fi
