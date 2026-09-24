#!/usr/bin/env bash
set -Eeuo pipefail

# 固定资产名的正式 Release：下载与摘要验证共用既有公共入口，保留同一资产 ID 的认证回退。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO="${1:-}"
ASSET_NAME="${2:-}"
OUTPUT="${3:-}"
EXPECTED_DEB_PACKAGE="${4:-}"
EXPECTED_DEB_ARCH="${5:-}"

[[ "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ && "$ASSET_NAME" =~ ^[A-Za-z0-9_.-]+$ && -n "$OUTPUT" ]] || {
  echo "用法：$0 <owner/repo> <固定资产名> <输出文件> [DEB 包名] [DEB 架构]" >&2
  exit 2
}
[[ -z "$EXPECTED_DEB_PACKAGE" && -z "$EXPECTED_DEB_ARCH" || -n "$EXPECTED_DEB_PACKAGE" && -n "$EXPECTED_DEB_ARCH" ]] || {
  echo "错误：DEB 包名和架构必须同时提供。" >&2
  exit 2
}

# shellcheck source=common/github/github_api.sh
source "$SCRIPT_DIR/github_api.sh"
RELEASE_JSON="$(mktemp)"
cleanup() { rm -f -- "$RELEASE_JSON"; }
trap cleanup EXIT
github_api_get "https://api.github.com/repos/$REPO/releases/latest" "$RELEASE_JSON"

# 每次只接受最新正式 semver Release 中唯一的指定资产和官方 SHA-256。
mapfile -t META < <(jq -r --arg name "$ASSET_NAME" '
  select(.draft == false and .prerelease == false)
  | select((.tag_name // "") | test("^v?[0-9]+\\.[0-9]+\\.[0-9]+$"))
  | [.assets[]? | select(.name == $name)] as $assets
  | select(($assets | length) == 1)
  | select(($assets[0].digest // "") | test("^sha256:[0-9a-fA-F]{64}$"))
  | .tag_name, $assets[0].browser_download_url, ($assets[0].id | tostring), ($assets[0].digest | sub("^sha256:"; "") | ascii_downcase)
' "$RELEASE_JSON")
(( ${#META[@]} == 4 )) || {
  echo "错误：最新正式 Release 缺少唯一且带官方 SHA-256 的资产：$REPO / $ASSET_NAME" >&2
  exit 1
}
VERSION="${META[0]#v}"
ASSET_URL="${META[1]}"
ASSET_ID="${META[2]}"
ASSET_SHA256="${META[3]}"
[[ "$ASSET_URL" == "https://github.com/$REPO/releases/download/"*"/$ASSET_NAME" && "$ASSET_ID" =~ ^[0-9]+$ ]] || {
  echo "错误：Release 资产地址或 ID 不符合预期：$REPO / $ASSET_NAME" >&2
  exit 1
}

# 直链失败才用同一资产 ID 和 Actions 凭据回退；两条路径均在交付前校验官方摘要。
if ! "$SCRIPT_DIR/../download/download_file.sh" "$ASSET_URL" "$OUTPUT" "$ASSET_SHA256" >&2; then
  AUTH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
  [[ -n "$AUTH_TOKEN" ]] || {
    echo "错误：直链下载失败，且缺少 GH_TOKEN 或 GITHUB_TOKEN。" >&2
    exit 1
  }
  OUTPUT_DIR="$(dirname -- "$OUTPUT")"
  mkdir -p -- "$OUTPUT_DIR"
  OUTPUT_DIR="$(cd -- "$OUTPUT_DIR" && pwd -P)"
  OUTPUT="$OUTPUT_DIR/$(basename -- "$OUTPUT")"
  TEMP_FILE="$(mktemp "${OUTPUT}.part.XXXXXX")"
  cleanup() { rm -f -- "$RELEASE_JSON" "$TEMP_FILE"; }
  curl --fail --show-error --location --proto '=https' --tlsv1.2 \
    --retry 3 --retry-delay 2 --connect-timeout 20 --max-time 900 \
    -H 'Accept: application/octet-stream' \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    "https://api.github.com/repos/$REPO/releases/assets/$ASSET_ID" -o "$TEMP_FILE"
  printf '%s  %s\n' "$ASSET_SHA256" "$TEMP_FILE" | sha256sum -c - >&2
  mv -f -- "$TEMP_FILE" "$OUTPUT"
fi

if [[ -n "$EXPECTED_DEB_PACKAGE" ]]; then
  [[ "$(dpkg-deb -f "$OUTPUT" Package)" == "$EXPECTED_DEB_PACKAGE" ]] || {
    echo "错误：DEB 包名不符合预期：$OUTPUT" >&2
    exit 1
  }
  [[ "$(dpkg-deb -f "$OUTPUT" Architecture)" == "$EXPECTED_DEB_ARCH" ]] || {
    echo "错误：DEB 架构不符合预期：$OUTPUT" >&2
    exit 1
  }
fi

# stdout 只返回本次官方 Release 版本。
printf '%s\n' "$VERSION"
