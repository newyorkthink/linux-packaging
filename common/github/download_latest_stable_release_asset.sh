#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RESOLVER="$SCRIPT_DIR/resolve_latest_stable_release_asset.sh"
DOWNLOAD_FILE="$SCRIPT_DIR/../download/download_file.sh"
REPO="${1:-}"
ASSET_TEMPLATE="${2:-}"
OUTPUT="${3:-}"

[[ -n "$REPO" && -n "$ASSET_TEMPLATE" && -n "$OUTPUT" ]] || {
  echo "用法：$0 <owner/repo> '<包含 {version} 的资产名模板>' <输出文件>" >&2
  exit 1
}
[[ -x "$RESOLVER" ]] || {
  echo "错误：稳定 Release 解析入口不存在或不可执行：$RESOLVER" >&2
  exit 1
}
[[ -x "$DOWNLOAD_FILE" ]] || {
  echo "错误：公共下载入口不存在或不可执行：$DOWNLOAD_FILE" >&2
  exit 1
}

# 统一解析正式 semver Release、唯一匹配资产和 GitHub SHA-256 digest。
mapfile -t RELEASE_META < <("$RESOLVER" "$REPO" "$ASSET_TEMPLATE")
[[ ${#RELEASE_META[@]} -eq 3 ]] || {
  echo "错误：无法解析唯一的正式 Release 资产元数据：$REPO / $ASSET_TEMPLATE" >&2
  exit 1
}

VERSION="${RELEASE_META[0]}"
ASSET_URL="${RELEASE_META[1]}"
ASSET_SHA256="${RELEASE_META[2]}"

# 下载并校验解析到的同一资产；下载日志写入 stderr，stdout 只返回版本供调用方复用。
"$DOWNLOAD_FILE" "$ASSET_URL" "$OUTPUT" "$ASSET_SHA256" >&2
printf '%s\n' "$VERSION"
