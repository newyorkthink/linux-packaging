#!/usr/bin/env bash
set -Eeuo pipefail

# 下载 GitHub 仓库默认分支当前提交的源码；只向 stdout 输出提交 SHA。
REPOSITORY="$1"
ARCHIVE="$2"
case "$REPOSITORY" in
  *[!a-zA-Z0-9_./-]*|.*|*..*|/*|*/) echo "错误：无效仓库：$REPOSITORY" >&2; exit 1 ;;
esac

ROOT="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
source "$ROOT/common/github/github_api.sh"
COMMIT="$(github_api_get "https://api.github.com/repos/$REPOSITORY/commits?per_page=1" |
  jq -er '.[0].sha | select(test("^[0-9a-f]{40}$"))')"
"$ROOT/common/download/download_file.sh" \
  "https://codeload.github.com/$REPOSITORY/tar.gz/$COMMIT" "$ARCHIVE"
printf '%s\n' "$COMMIT"
