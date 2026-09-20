#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOWNLOAD_FILE="$SCRIPT_DIR/download_file.sh"

METADATA_URL="${1:-}"
VERSION_JQ_FILTER="${2:-}"
ASSET_URL_JQ_FILTER="${3:-}"
ASSET_URL_REGEX="${4:-}"
FILENAME_TEMPLATE="${5:-}"
EXPECTED_PACKAGE="${6:-}"
EXPECTED_ARCHITECTURE="${7:-}"
OUTPUT="${8:-}"

[[ -n "$METADATA_URL" && -n "$VERSION_JQ_FILTER" && -n "$ASSET_URL_JQ_FILTER" &&
   -n "$ASSET_URL_REGEX" && -n "$FILENAME_TEMPLATE" && -n "$EXPECTED_PACKAGE" &&
   -n "$EXPECTED_ARCHITECTURE" && -n "$OUTPUT" ]] || {
  echo "用法：$0 <元数据 URL> <版本 jq> <资产 URL jq> <允许 URL 正则> <文件名模板> <DEB 包名> <架构> <输出 DEB>" >&2
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

METADATA_FILE="$(mktemp)"

# 退出时只删除本次元数据查询产生的临时文件。
cleanup() {
  rm -f -- "$METADATA_FILE"
}
trap cleanup EXIT

# 下载官方 JSON 元数据，由调用方提供 jq 过滤器提取已规范化版本与实际资产 URL。
"$DOWNLOAD_FILE" "$METADATA_URL" "$METADATA_FILE"
VERSION="$(jq -er "$VERSION_JQ_FILTER // empty" "$METADATA_FILE")"
ASSET_URL="$(jq -er "$ASSET_URL_JQ_FILTER // empty" "$METADATA_FILE")"

[[ -n "$VERSION" && "$VERSION" != *'/'* ]] || {
  echo "错误：元数据返回了无效版本：$VERSION" >&2
  exit 1
}
[[ "$ASSET_URL" =~ $ASSET_URL_REGEX ]] || {
  echo "错误：资产 URL 不符合调用方允许范围：$ASSET_URL" >&2
  exit 1
}

EXPECTED_FILENAME="${FILENAME_TEMPLATE//\{version\}/$VERSION}"
[[ "${ASSET_URL##*/}" == "$EXPECTED_FILENAME" ]] || {
  echo "错误：资产 URL 文件名与版本模板不一致：$ASSET_URL" >&2
  exit 1
}

# 上游未提供摘要时仍复用统一 HTTPS 下载入口；随后核对 DEB 类型和调用方指定的包元数据。
"$DOWNLOAD_FILE" "$ASSET_URL" "$OUTPUT"
file "$OUTPUT" | grep -q 'Debian binary package' || {
  echo "错误：下载文件不是 Debian 软件包：$OUTPUT" >&2
  exit 1
}
[[ "$(dpkg-deb -f "$OUTPUT" Package)" == "$EXPECTED_PACKAGE" ]] || {
  echo "错误：DEB 包名不符合预期：$OUTPUT" >&2
  exit 1
}
[[ "$(dpkg-deb -f "$OUTPUT" Version)" == "$VERSION" ]] || {
  echo "错误：DEB 版本与元数据版本不一致：$OUTPUT" >&2
  exit 1
}
[[ "$(dpkg-deb -f "$OUTPUT" Architecture)" == "$EXPECTED_ARCHITECTURE" ]] || {
  echo "错误：DEB 架构不符合预期：$OUTPUT" >&2
  exit 1
}

# stdout 只返回实际版本，便于调用方直接用于最终版本元数据；本地摘要写入 stderr。
sha256sum "$OUTPUT" >&2
printf '%s\n' "$VERSION"
