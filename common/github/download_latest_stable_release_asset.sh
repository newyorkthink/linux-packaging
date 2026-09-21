#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RESOLVER="$SCRIPT_DIR/resolve_latest_stable_release_asset.sh"
DOWNLOAD_FILE="$SCRIPT_DIR/../download/download_file.sh"
REPO="${1:-}"
ASSET_TEMPLATE="${2:-}"
OUTPUT="${3:-}"
EXPECTED_DEB_PACKAGE="${4:-}"
EXPECTED_DEB_ARCHITECTURE="${5:-}"

[[ -n "$REPO" && -n "$ASSET_TEMPLATE" && -n "$OUTPUT" ]] || {
  echo "用法：$0 <owner/repo> '<包含 {version} 的资产名模板>' <输出文件> [DEB 包名] [DEB 架构]" >&2
  exit 1
}
[[ -z "$EXPECTED_DEB_PACKAGE" == -z "$EXPECTED_DEB_ARCHITECTURE" ]] || {
  echo "错误：DEB 包名和架构必须同时提供。" >&2
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

# 下载并校验解析到的同一资产；下载日志写入 stderr。
"$DOWNLOAD_FILE" "$ASSET_URL" "$OUTPUT" "$ASSET_SHA256" >&2

# 调用方明确传入 DEB 包名和架构时，在公共入口统一核对包名、Release 版本和架构。
if [[ -n "$EXPECTED_DEB_PACKAGE" ]]; then
  [[ "$(dpkg-deb -f "$OUTPUT" Package)" == "$EXPECTED_DEB_PACKAGE" ]] || {
    echo "错误：DEB 包名不符合预期：$OUTPUT" >&2
    exit 1
  }
  [[ "$(dpkg-deb -f "$OUTPUT" Version)" == "$VERSION" ]] || {
    echo "错误：DEB 版本与 Release 版本不一致：$OUTPUT" >&2
    exit 1
  }
  [[ "$(dpkg-deb -f "$OUTPUT" Architecture)" == "$EXPECTED_DEB_ARCHITECTURE" ]] || {
    echo "错误：DEB 架构不符合预期：$OUTPUT" >&2
    exit 1
  }
fi

# stdout 只返回版本供调用方复用。
printf '%s\n' "$VERSION"
