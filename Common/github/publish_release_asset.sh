#!/usr/bin/env bash
set -Eeuo pipefail

# 使用调用方的 GitHub 凭据发布已命名的构建产物。
if (( $# != 2 )) || [[ ! "$1" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ || ! -f "$2" || ! -s "$2" ]]; then
  echo "用法：$0 <owner/repo> <非空资产文件>" >&2
  exit 2
fi

REPOSITORY="$1"
RELEASE_FILE="$2"
RELEASE_NAME="${RELEASE_FILE##*/}"

# Release 资产超过单页时，按完整分页列表精确删除本应用旧资产。
# gh release upload --clobber 曾未识别已有同名资产，连续返回 422。
for attempt in 1 2 3 4 5 6 7 8; do
  # 查询失败后进入本轮退避，不使用分页未完成时的部分结果。
  if release_id="$(gh api "repos/$REPOSITORY/releases/tags/latest" --jq .id)" &&
     asset_ids="$(gh api --paginate \
       "repos/$REPOSITORY/releases/$release_id/assets?per_page=100" \
       | jq -r --arg name "$RELEASE_NAME" '.[] | select(.name == $name) | .id')"; then
    assets_deleted=true
    for asset_id in $asset_ids; do
      if ! gh api --method DELETE \
        "repos/$REPOSITORY/releases/assets/$asset_id"; then
        assets_deleted=false
        break
      fi
    done
    # 删除失败后重新列举附件；仅在全部删除成功时进入上传。
    if [[ "$assets_deleted" == true ]] &&
       timeout 180 gh release upload latest "$RELEASE_FILE" \
         --repo "$REPOSITORY"; then
      break
    fi
  fi
  if [[ "$attempt" -eq 8 ]]; then
    echo '发布 Release 资产失败，已尝试 8 次。' >&2
    exit 1
  fi
  echo "发布 Release 资产失败，$((attempt * 5)) 秒后重试（$attempt/8）。" >&2
  sleep $((attempt * 5))
done
