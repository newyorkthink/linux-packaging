#!/usr/bin/env bash
set -Eeuo pipefail

# 显式请求时，在原有三行元数据后追加同一资产的 ID。
WITH_ASSET_ID=false
if [[ "${1:-}" == --with-asset-id ]]; then
  WITH_ASSET_ID=true
  shift
fi

# 仅在调用方显式指定时移除标签前缀，原有版本匹配规则保持不变。
TAG_PREFIX=""
RELEASE_TAG=""
if [[ "${1:-}" == --release-tag ]]; then
  if (( $# < 2 )) || [[ ! "$2" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
    echo "用法：$0 --release-tag <归档标签> <owner/repo> <固定资产名>" >&2
    exit 2
  fi
  RELEASE_TAG="$2"
  shift 2
elif [[ "${1:-}" == --tag-prefix ]]; then
  if (( $# < 2 )) || [[ -z "$2" || "$2" == *[[:space:]]* ]]; then
    echo "用法：$0 [--tag-prefix <非空标签前缀>] <owner/repo> '<固定资产名或含 {version} 的资产名模板>'" >&2
    exit 2
  fi
  TAG_PREFIX="$2"
  shift 2
fi

# 资产 ID 扩展只用于正式版本解析，其他模式继续使用原有输出格式。
if [[ "$WITH_ASSET_ID" == true && ( -n "$RELEASE_TAG" || "${3:-}" == --latest-with-checksum ) ]]; then
  echo "错误：--with-asset-id 不能与 --release-tag 或 --latest-with-checksum 一起使用。" >&2
  exit 2
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GITHUB_API="$SCRIPT_DIR/github_api.sh"
REPO="${1:-}"
ASSET_TEMPLATE="${2:-}"

[[ -r "$GITHUB_API" ]] || {
  echo "错误：GitHub API 公共脚本不存在：$GITHUB_API" >&2
  exit 1
}
[[ "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || {
  echo "用法：$0 <owner/repo> '<固定资产名或含 {version} 的资产名模板>'" >&2
  exit 1
}
[[ "$ASSET_TEMPLATE" == *'{version}'* || "$ASSET_TEMPLATE" =~ ^[A-Za-z0-9_.-]+$ ]] || {
  echo "错误：资产名必须是固定文件名或包含 {version} 的模板：$ASSET_TEMPLATE" >&2
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

# 指定非版本标签时，仅接受该 Release 中唯一的已上传资产及 GitHub 官方摘要。
if [[ -n "$RELEASE_TAG" ]]; then
  [[ $# == 2 && "$ASSET_TEMPLATE" =~ ^[A-Za-z0-9_.-]+$ ]] || {
    echo "错误：指定归档标签时必须提供单个固定资产名。" >&2
    exit 2
  }
  github_api_get "https://api.github.com/repos/$REPO/releases/tags/$RELEASE_TAG" "$RELEASES_JSON"
  jq -er --arg repo "$REPO" --arg tag "$RELEASE_TAG" --arg name "$ASSET_TEMPLATE" '
    select(type == "object" and .draft == false and .prerelease == false and .tag_name == $tag)
    | [.assets[]? | select(.name == $name and .state == "uploaded")] as $matches
    | select(($matches | length) == 1)
    | $matches[0] as $asset
    | select($asset.browser_download_url == ("https://github.com/" + $repo + "/releases/download/" + $tag + "/" + $name))
    | select(($asset.digest // "") | test("^sha256:[0-9a-fA-F]{64}$"))
    | select(($asset.id | type) == "number")
    | $asset.name, $asset.browser_download_url, ($asset.digest | sub("^sha256:"; "") | ascii_downcase), ($asset.id | tostring)
  ' "$RELEASES_JSON"
  exit
fi

# 显式启用时，在同一 latest 响应中定位主资产和官方校验清单。
if [[ "${3:-}" == --latest-with-checksum ]]; then
  [[ -z "$TAG_PREFIX" ]] || {
    echo "错误：--tag-prefix 不能与 --latest-with-checksum 一起使用。" >&2
    exit 2
  }
  CHECKSUM_NAME="${4:-}"
  [[ $# == 4 && "$CHECKSUM_NAME" =~ ^[A-Za-z0-9_.-]+$ ]] || {
    echo "用法：$0 <owner/repo> <资产名模板> --latest-with-checksum <校验清单资产名>" >&2
    exit 1
  }
  github_api_get "https://api.github.com/repos/$REPO/releases/latest" "$RELEASES_JSON"
  jq -er --arg repo "$REPO" --arg template "$ASSET_TEMPLATE" --arg checksum "$CHECKSUM_NAME" '
    def asset($name; $tag):
      [.assets[]? | select(.name == $name)]
      | select(length == 1) | .[0]
      | select(.browser_download_url == ("https://github.com/" + $repo + "/releases/download/" + $tag + "/" + $name))
      | select((.digest // "") | test("^sha256:[0-9a-fA-F]{64}$"));
    select(.draft == false and .prerelease == false)
    | .tag_name as $tag
    | select($tag | strings | test("^v[0-9][0-9A-Za-z._+-]*$"))
    | ($tag | ltrimstr("v")) as $version
    | ($template | gsub("\\{version\\}"; $version)) as $name
    | asset($name; $tag) as $main
    | asset($checksum; $tag) as $sums
    | $version, $main.browser_download_url, $main.digest, $sums.browser_download_url, $sums.digest, $tag, $name
  ' "$RELEASES_JSON"
  exit
fi

# 读取最近 100 个 Release，避免只依赖 latest 指针或匿名 API 配额。
github_api_get "https://api.github.com/repos/$REPO/releases?per_page=100" "$RELEASES_JSON"

# 只保留正式 semver 标签、唯一匹配资产和有效 GitHub SHA-256 digest，再按版本排序。
CANDIDATE="$({
  jq -r --arg asset_template "$ASSET_TEMPLATE" --arg tag_prefix "$TAG_PREFIX" --argjson with_asset_id "$WITH_ASSET_ID" '
    .[]
    | select(.draft != true and .prerelease != true)
    | ((.tag_name // "")
       | if $tag_prefix == "" then . else select(startswith($tag_prefix)) | ltrimstr($tag_prefix) end
       | capture("^v?(?<version>[0-9]+(?:\\.[0-9]+)+)$")?) as $tag
    | select($tag != null)
    | ($asset_template | gsub("\\{version\\}"; $tag.version)) as $asset_name
    | [.assets[]? | select(.name == $asset_name)] as $assets
    | select(($assets | length) == 1)
    | ($assets[0].digest // "") as $digest
    | select($digest | test("^sha256:[0-9a-fA-F]{64}$"))
    | ([$tag.version, $assets[0].browser_download_url, ($digest | sub("^sha256:"; "") | ascii_downcase)]
       + (if $with_asset_id then [($assets[0].id | tostring)] else [] end))
    | @tsv
  ' "$RELEASES_JSON"
} | sort -t $'\t' -k1,1V | tail -n 1)"

[[ -n "$CANDIDATE" ]] || {
  echo "错误：$REPO 没有符合模板的正式 Release 资产：$ASSET_TEMPLATE" >&2
  exit 1
}

IFS=$'\t' read -r VERSION ASSET_URL ASSET_SHA256 ASSET_ID <<< "$CANDIDATE"
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

# 在输出前核对可选资产 ID，避免返回不完整的认证回退元数据。
if [[ "$WITH_ASSET_ID" == true && ! "$ASSET_ID" =~ ^[1-9][0-9]*$ ]]; then
  echo "错误：解析到无效资产 ID：$ASSET_ID" >&2
  exit 1
fi

printf '%s\n%s\n%s\n' "$VERSION" "$ASSET_URL" "$ASSET_SHA256"
if [[ "$WITH_ASSET_ID" == true ]]; then
  printf '%s\n' "$ASSET_ID"
fi
