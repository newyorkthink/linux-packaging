#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GITHUB_API="$SCRIPT_DIR/github_api.sh"
REPO="${1:-}"
ASSET_TEMPLATE="${2:-}"

[[ -r "$GITHUB_API" ]] || {
  echo "错误：GitHub API 公共脚本不存在：$GITHUB_API" >&2
  exit 1
}
[[ "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || {
  echo "用法：$0 <owner/repo> '<包含 {version} 的资产名模板>'" >&2
  exit 1
}
[[ "$ASSET_TEMPLATE" == *'{version}'* ]] || {
  echo "错误：资产名模板必须包含 {version}：$ASSET_TEMPLATE" >&2
  exit 1
}

# shellcheck source=common/github/github_api.sh
source "$GITHUB_API"

for command_name in curl jq sort tail; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "错误：缺少必需命令：$command_name" >&2
    exit 1
  }
done

RELEASES_JSON="$(mktemp)"

# 删除当前解析过程产生的临时 Release 元数据。
cleanup() {
  rm -f -- "$RELEASES_JSON"
}
trap cleanup EXIT

# 读取最近 100 个 Release，避免只依赖 latest 指针或匿名 API 配额。
github_api_get "https://api.github.com/repos/$REPO/releases?per_page=100" "$RELEASES_JSON"

# 只保留正式 semver 标签、唯一匹配资产和有效 GitHub SHA-256 digest，再按版本排序。
CANDIDATE="$({
  jq -r --arg asset_template "$ASSET_TEMPLATE" '
    .[]
    | select(.draft != true and .prerelease != true)
    | ((.tag_name // "") | capture("^v?(?<version>[0-9]+(?:\\.[0-9]+)+)$")?) as $tag
    | select($tag != null)
    | ($asset_template | gsub("\\{version\\}"; $tag.version)) as $asset_name
    | [.assets[]? | select(.name == $asset_name)] as $assets
    | select(($assets | length) == 1)
    | ($assets[0].digest // "") as $digest
    | select($digest | test("^sha256:[0-9a-fA-F]{64}$"))
    | [$tag.version, $assets[0].browser_download_url, ($digest | sub("^sha256:"; "") | ascii_downcase)]
    | @tsv
  ' "$RELEASES_JSON"
} | sort -t $'\t' -k1,1V | tail -n 1)"

[[ -n "$CANDIDATE" ]] || {
  echo "错误：$REPO 没有符合模板的正式 Release 资产：$ASSET_TEMPLATE" >&2
  exit 1
}

IFS=$'\t' read -r VERSION ASSET_URL ASSET_SHA256 <<< "$CANDIDATE"
[[ "$VERSION" =~ ^[0-9]+([.][0-9]+)+$ ]] || {
  echo "错误：解析到无效版本：$VERSION" >&2
  exit 1
}
[[ "$ASSET_URL" == https://github.com/* ]] || {
  echo "错误：解析到非 GitHub HTTPS 资产：$ASSET_URL" >&2
  exit 1
}
[[ "$ASSET_SHA256" =~ ^[[:xdigit:]]{64}$ ]] || {
  echo "错误：解析到无效 SHA-256：$ASSET_SHA256" >&2
  exit 1
}

printf '%s\n%s\n%s\n' "$VERSION" "$ASSET_URL" "$ASSET_SHA256"
