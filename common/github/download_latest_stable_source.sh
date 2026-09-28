#!/usr/bin/env bash
set -Eeuo pipefail

REPOSITORY="${1:-}"
ARCHIVE="${2:-}"
MODE="${3:-release}"

# 仅接受明确的 GitHub 仓库和 tar.gz 输出，禁止把预发布标签当作正式版。
[[ $# -ge 2 && $# -le 3 && "$REPOSITORY" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+$ && "$ARCHIVE" == *.tar.gz && "$MODE" =~ ^(release|tags)$ ]] || {
  echo "用法：$0 <owner/repo> <输出.tar.gz> [release|tags]" >&2
  exit 1
}

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
# 复用现有认证、重试和超时逻辑读取官方 Release。
source "$ROOT/common/github/github_api.sh"
if [[ "$MODE" == release ]]; then
  METADATA="$(github_api_get "https://api.github.com/repos/$REPOSITORY/releases/latest")"
  TAG="$(jq -er 'select(.draft == false and .prerelease == false) | .tag_name | select(test("^v?[0-9]+(\\.[0-9]+){1,3}$"))' <<< "$METADATA")"
else
  # 没有 Release、仅发布正式数字标签的上游由调用方显式选择 tags；不自动降级。
  TAGS=()
  PAGE=1
  while :; do
    METADATA="$(github_api_get "https://api.github.com/repos/$REPOSITORY/tags?per_page=100&page=$PAGE")"
    COUNT="$(jq -er 'if type == "array" then length else error("标签响应不是数组") end' <<< "$METADATA")"
    mapfile -t CURRENT_TAGS < <(jq -r '.[].name | select(test("^v?[0-9]+(\\.[0-9]+){1,3}$"))' <<< "$METADATA")
    TAGS+=("${CURRENT_TAGS[@]}")
    (( COUNT == 100 )) || break
    PAGE=$((PAGE + 1))
  done
  (( ${#TAGS[@]} > 0 )) || { echo "错误：上游没有正式数字版本标签。" >&2; exit 1; }
  TAG="$(printf '%s\n' "${TAGS[@]}" | sed -E 's/^(v?)(.*)$/\2 \1\2/' | sort -k1,1V | tail -n 1 | cut -d ' ' -f 2)"
fi
VERSION="${TAG#v}"

# 把本次正式标签解析为提交，避免下载期间标签移动导致来源不一致。
COMMIT="$(github_api_get "https://api.github.com/repos/$REPOSITORY/commits/$TAG" | jq -er '.sha | select(test("^[0-9a-f]{40}$"))')"
# GitHub 自动生成的源码归档没有 Release asset digest；按提交下载并记录本地 SHA-256。
"$ROOT/common/download/download_file.sh" "https://codeload.github.com/$REPOSITORY/tar.gz/$COMMIT" "$ARCHIVE" >&2
printf '正式源码：%s，标签：%s，提交：%s\n' "$REPOSITORY" "$TAG" "$COMMIT" >&2
sha256sum "$ARCHIVE" >&2
# stdout 只输出实际版本，供调用方在最终打包成功后记录。
printf '%s\n' "$VERSION"
