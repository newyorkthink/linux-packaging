#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOWNLOAD_FILE="$SCRIPT_DIR/download_file.sh"

USER_AGENT=
FILE_VERSION_REGEX=
ALLOW_MD5=false
ALLOW_DEB_REVISION=false
while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --user-agent|--filename-version)
      (( $# >= 2 )) && [[ -n "$2" ]] || { echo "错误：$1 缺少值。" >&2; exit 2; }
      if [[ "$1" == --user-agent ]]; then
        [[ -z "$USER_AGENT" ]] || { echo "错误：重复的 $1。" >&2; exit 2; }
        USER_AGENT="$2"
      else
        [[ -z "$FILE_VERSION_REGEX" ]] || { echo "错误：重复的 $1。" >&2; exit 2; }
        FILE_VERSION_REGEX="$2"
      fi
      shift 2
      ;;
    --allow-md5|--allow-deb-revision)
      if [[ "$1" == --allow-md5 ]]; then
        ALLOW_MD5=true
      else
        ALLOW_DEB_REVISION=true
      fi
      shift
      ;;
    *) echo "错误：未知 JSON DEB 下载选项：$1" >&2; exit 2 ;;
  esac
done

METADATA_URL="${1:-}"
VERSION_JQ_FILTER="${2:-}"
ASSET_URL_JQ_FILTER="${3:-}"
ASSET_URL_REGEX="${4:-}"
FILENAME_TEMPLATE="${5:-}"
EXPECTED_PACKAGE="${6:-}"
EXPECTED_ARCHITECTURE="${7:-}"
OUTPUT="${8:-}"
SHA256_JQ_FILTER="${9:-}"

[[ -n "$METADATA_URL" && -n "$VERSION_JQ_FILTER" && -n "$ASSET_URL_JQ_FILTER" &&
   -n "$ASSET_URL_REGEX" && -n "$FILENAME_TEMPLATE" && ( -n "$EXPECTED_PACKAGE" || -n "$FILE_VERSION_REGEX" ) &&
   -n "$EXPECTED_ARCHITECTURE" && -n "$OUTPUT" ]] || {
  echo "用法：$0 [--user-agent <标识>] [--filename-version <含首个版本捕获组的正则>] [--allow-md5] [--allow-deb-revision] <元数据 URL> <版本 jq> <资产 URL jq> <允许 URL 正则> <文件名模板> <DEB 包名> <架构> <输出 DEB> [摘要 jq]" >&2
  exit 1
}
[[ "$FILENAME_TEMPLATE" == *'{version}'* ]] || {
  echo "错误：文件名模板必须包含 {version} 占位符。" >&2
  exit 1
}
[[ -x "$DOWNLOAD_FILE" ]] || {
  echo "错误：公共下载入口不存在或不可执行：$DOWNLOAD_FILE" >&2
  exit 1
}

mkdir -p -- "$(dirname -- "$OUTPUT")"
METADATA_FILE="$(mktemp)"
STAGED=
cleanup() {
  rm -f -- "$METADATA_FILE"
  [[ -z "$STAGED" ]] || rm -f -- "$STAGED"
}
trap cleanup EXIT
STAGED="$(mktemp -- "$OUTPUT.part.XXXXXXXX.deb")"

# 从同一份官方 JSON 读取下载地址和版本。
"$DOWNLOAD_FILE" "$METADATA_URL" "$METADATA_FILE" "" "$USER_AGENT"
ASSET_URL="$(jq -er "$ASSET_URL_JQ_FILTER // empty" "$METADATA_FILE")"
[[ "$ASSET_URL" =~ $ASSET_URL_REGEX ]] || {
  echo "错误：资产 URL 不符合调用方允许范围：$ASSET_URL" >&2
  exit 1
}
ASSET_NAME="${ASSET_URL##*/}"
if [[ -n "$FILE_VERSION_REGEX" ]]; then
  # 文件名模式以调用方声明的捕获组为准，同时核对 JSON 可选版本字段。
  ASSET_NAME="${ASSET_URL%%[?#]*}"
  ASSET_NAME="${ASSET_NAME##*/}"
  if [[ ! "$ASSET_NAME" =~ $FILE_VERSION_REGEX || -z "${BASH_REMATCH[1]:-}" ]]; then
    echo "错误：无法从官方 DEB 文件名读取版本。" >&2
    exit 1
  fi
  VERSION="${BASH_REMATCH[1]}"
  METADATA_VERSION="$(jq -er "($VERSION_JQ_FILTER) // \"\" | tostring" "$METADATA_FILE")"
  [[ "$VERSION" =~ ^[0-9]+([.][0-9]+)+$ ]] || {
    echo "错误：DEB 文件名版本必须是点分数字。" >&2
    exit 1
  }
  if [[ -n "$METADATA_VERSION" ]]; then
    VERSION_PATTERN="${VERSION//./[.]}"
    [[ "$METADATA_VERSION" =~ (^|[^0-9.])$VERSION_PATTERN([^0-9.]|$) ]] || {
      echo "错误：JSON 与官方 DEB 文件名的版本不一致。" >&2
      exit 1
    }
  fi
else
  VERSION="$(jq -er "$VERSION_JQ_FILTER // empty" "$METADATA_FILE")"
fi
[[ -n "$VERSION" && "$VERSION" != *'/'* ]] || {
  echo "错误：官方 JSON 返回无效版本。" >&2
  exit 1
}
EXPECTED_FILENAME="${FILENAME_TEMPLATE//\{version\}/$VERSION}"
[[ "$ASSET_NAME" == $EXPECTED_FILENAME ]] || {
  echo "错误：官方 DEB 文件名与版本模板不一致：$ASSET_NAME" >&2
  exit 1
}

# 缺失或非法摘要直接失败；只有显式启用时才接受官方的旧式 MD5。
CHECKSUM=
if [[ -n "$SHA256_JQ_FILTER" ]]; then
  CHECKSUM="$(jq -er "$SHA256_JQ_FILTER // empty" "$METADATA_FILE")"
  if [[ -z "$CHECKSUM" ]]; then
    echo "错误：官方 JSON 返回空摘要。" >&2
    exit 1
  fi
  if [[ "$ALLOW_MD5" == true ]]; then
    CHECKSUM="${CHECKSUM#"${CHECKSUM%%[![:space:]]*}"}"
    CHECKSUM="${CHECKSUM%"${CHECKSUM##*[![:space:]]}"}"
    if [[ "$CHECKSUM" =~ ^[[:xdigit:]]{32}$ ]]; then
      CHECKSUM="md5:$CHECKSUM"
    elif [[ ! "$CHECKSUM" =~ ^(sha256:)?[[:xdigit:]]{64}$ ]]; then
      echo "错误：官方 JSON 未返回有效的 SHA-256 或 MD5。" >&2
      exit 1
    fi
  elif [[ "$CHECKSUM" == md5:* ]]; then
    echo "错误：MD5 需要显式使用 --allow-md5。" >&2
    exit 2
  fi
elif [[ "$ALLOW_MD5" == true ]]; then
  echo "错误：--allow-md5 要求提供官方摘要 jq 字段。" >&2
  exit 2
fi

"$DOWNLOAD_FILE" "$ASSET_URL" "$STAGED" "$CHECKSUM" "$USER_AGENT" >&2
[[ "$(file -b -- "$STAGED")" == *'Debian binary package'* ]] || {
  echo "错误：官方下载文件不是 Debian 软件包。" >&2
  exit 1
}
EXPECTED_VERSION="$VERSION"
if [[ "$ALLOW_DEB_REVISION" == true ]]; then
  EXPECTED_VERSION="$(dpkg-deb -f "$STAGED" Version)"
  dpkg --validate-version "$EXPECTED_VERSION"
  [[ "$EXPECTED_VERSION" == "$VERSION" || ( "$EXPECTED_VERSION" == *-?* && "${EXPECTED_VERSION%-*}" == "$VERSION" ) ]] || {
    echo "错误：DEB 包内版本与官网版本不一致。" >&2
    exit 1
  }
fi
"$SCRIPT_DIR/../archive/check_deb_metadata.sh" "$STAGED" "$EXPECTED_VERSION" "$EXPECTED_PACKAGE" "$EXPECTED_ARCHITECTURE"

mv -fT -- "$STAGED" "$OUTPUT"
sha256sum "$OUTPUT" >&2
printf '%s\n' "$VERSION"
