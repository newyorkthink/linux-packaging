#!/usr/bin/env bash
set -Eeuo pipefail

# 检查构建类型。
TARGET="${1:-}"
case "$TARGET" in
  appimage|runimage|termux) ;;
  *)
    printf '错误：不支持的构建类型：%s\n' "$TARGET" >&2
    exit 1
    ;;
esac

# 只查找 GitHub Actions 官方机器人创建的专用状态 Issue。
ISSUE_NUMBERS="$(
  gh api --paginate \
    "repos/${GITHUB_REPOSITORY}/issues?state=all&per_page=100" \
    --jq '.[] | select(.title == "[自动化] Daily Build State" and .user.login == "github-actions[bot]" and (has("pull_request") | not)) | .number'
)"

# 防止存在多个合法状态 Issue。
if [[ "$ISSUE_NUMBERS" == *$'\n'* ]]; then
  printf '错误：存在多个 GitHub Actions 创建的每日构建状态 Issue。\n' >&2
  exit 1
fi

# 未建立状态 Issue 时，默认不暂停。
if [[ -z "$ISSUE_NUMBERS" ]]; then
  printf 'false\n'
  exit 0
fi

# 读取状态 Issue 正文。
BODY="$(
  gh api \
    "repos/${GITHUB_REPOSITORY}/issues/${ISSUE_NUMBERS}" \
    --jq '.body'
)"

# 严格验证 JSON 结构和布尔值。
STATE="$(
  jq -ce '
    if (type == "object")
       and (keys == ["appimage", "runimage", "termux"])
       and ((.appimage | type) == "boolean")
       and ((.runimage | type) == "boolean")
       and ((.termux | type) == "boolean")
    then .
    else error("每日构建状态数据无效")
    end
  ' <<< "$BODY"
)"

# 将开启状态转换为暂停状态。
ENABLED="$(jq -r --arg target "$TARGET" '.[$target]' <<< "$STATE")"

if [[ "$ENABLED" == "false" ]]; then
  printf 'true\n'
else
  printf 'false\n'
fi
