#!/usr/bin/env bash
set -Eeuo pipefail

# 下载 GitHub 最新正式 Release 标签的源码。
# 只向 stdout 输出标签名。仓库和目标目录由调用方传入。

if [[ $# -ne 2 ]]; then
  echo "用法：$0 <owner/repo> <目标目录>" >&2
  exit 2
fi

REPOSITORY="$1"
DEST="$2"

case "$REPOSITORY" in
  *[!a-zA-Z0-9_./-]*|.*|*..*|/*|*/|*/*/*)
    echo "错误：无效仓库：$REPOSITORY" >&2
    exit 1
    ;;
esac
[[ "$REPOSITORY" == */* ]] || {
  echo "错误：无效仓库：$REPOSITORY" >&2
  exit 1
}
[[ -n "$DEST" && "$DEST" != -* ]] || {
  echo "错误：无效目标目录。" >&2
  exit 1
}
[[ ! -e "$DEST" ]] || {
  echo "错误：目标目录已存在：$DEST" >&2
  exit 1
}

for command_name in jq git; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "错误：缺少必需命令：$command_name" >&2
    exit 1
  }
done

ROOT="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
# shellcheck source=common/github/github_api.sh
source "$ROOT/common/github/github_api.sh"

RELEASE_JSON="$(github_api_get "https://api.github.com/repos/$REPOSITORY/releases/latest")"
TAG="$(printf '%s\n' "$RELEASE_JSON" | jq -er '
  select(type == "object" and .draft == false and .prerelease == false)
  | .tag_name
  | select(type == "string" and test("^[vV]?[0-9]+([.][0-9]+){2}([._+-][0-9A-Za-z]+)*$"))
')" || {
  echo "错误：无法解析最新正式版本：$REPOSITORY" >&2
  exit 1
}

git clone --depth 1 --branch "$TAG" "https://github.com/$REPOSITORY.git" "$DEST" >&2
printf '%s\n' "$TAG"
