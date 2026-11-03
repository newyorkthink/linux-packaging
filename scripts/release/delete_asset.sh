#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
  cat <<'USAGE'
用法：
  bash scripts/release/delete_asset.sh --repo "<所有者>/<仓库>" --tag "<Release 标签>" --asset "<完整附件名>" --yes

参数：
  --repo    GitHub.com 仓库，格式为 OWNER/REPO。
  --tag     已核实的 Release 标签，必须明确填写。
  --asset   已核实的完整附件名，按字面精确匹配。
  --yes     确认执行删除；缺少时不查询、不删除。
  --help    显示说明。

依赖：Bash、gh、jq；使用本机 gh 已有认证及目标仓库的发布写权限。
目标已不存在且完整查询成功时返回 0；参数错误返回 2；其他失败返回非零。
USAGE
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

usage_error() {
  printf '参数错误：%s；使用 --help 查看用法。\n' "$*" >&2
  exit 2
}

# 解析并检查全部参数，确认前不访问 GitHub。
repository=
release_tag=
asset_name=
confirmed=false
while (( $# > 0 )); do
  case "$1" in
    --repo|--tag|--asset)
      (( $# >= 2 )) || usage_error "$1 缺少值"
      [[ -n "$2" && "$2" != -* && ! "$2" =~ [[:cntrl:]] ]] || usage_error "$1 的值为空、以短横线开头或含控制字符"
      case "$1" in
        --repo)
          [[ -z "$repository" ]] || usage_error "--repo 重复"
          repository=$2
          ;;
        --tag)
          [[ -z "$release_tag" ]] || usage_error "--tag 重复"
          release_tag=$2
          ;;
        --asset)
          [[ -z "$asset_name" ]] || usage_error "--asset 重复"
          asset_name=$2
          ;;
      esac
      shift 2
      ;;
    --yes)
      [[ "$confirmed" == false ]] || usage_error "--yes 重复"
      confirmed=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage_error "未知参数：$1"
      ;;
  esac
done

[[ -n "$repository" && -n "$release_tag" && -n "$asset_name" ]] || usage_error "--repo、--tag、--asset 必须全部填写"
[[ "$repository" =~ ^[A-Za-z0-9-]+/[A-Za-z0-9_.-]+$ && "$repository" != */. && "$repository" != */.. ]] || usage_error "--repo 必须为 OWNER/REPO"
[[ "$confirmed" == true ]] || usage_error "执行删除必须提供 --yes"

# 只检查已有依赖和认证，不安装软件，也不输出账户或凭据。
command -v gh >/dev/null 2>&1 || die "缺少 gh，请先安装 GitHub CLI"
command -v jq >/dev/null 2>&1 || die "缺少 jq，请先安装 jq"
if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  die "gh 认证不可用，请先在本机检查 github.com 的登录状态"
fi

# 对标签进行 URL 编码，避免特殊字符改变查询路径。
encoded_tag="$(jq -rn --arg tag "$release_tag" '$tag | @uri')"

# 从指定标签读取唯一、有效的 Release 编号。
read_release_id() {
  gh api --hostname github.com "repos/$repository/releases/tags/$encoded_tag" |
    jq -ers --arg tag "$release_tag" '
      if length == 1 then .[0] else error("Release 响应数量无效") end |
      if type == "object" and .tag_name == $tag
        and (.id | type) == "number" and .id > 0 and .id == (.id | floor)
      then .id
      else error("Release 响应无效或标签不匹配")
      end'
}

# 完整读取附件分页并校验每页，任何一页失败都保留为失败。
read_assets() {
  gh api --hostname github.com --paginate "repos/$repository/releases/$1/assets?per_page=100" |
    jq -se '
      if length > 0 and all(.[]; type == "array")
      then add
      else error("附件分页响应无效")
      end |
      if all(.[];
        type == "object" and (.name | type) == "string"
        and (.id | type) == "number" and .id > 0 and .id == (.id | floor))
      then .
      else error("附件元数据无效")
      end'
}

# 按完整文件名精确定位附件，不使用通配符或历史 asset ID。
release_id="$(read_release_id)"
assets_json="$(read_assets "$release_id")"
match_count="$(jq -r --arg name "$asset_name" '[.[] | select(.name == $name)] | length' <<< "$assets_json")"

# 附件查询完成后再次核对标签，防止 Release 被并发替换。
current_release_id="$(read_release_id)"
[[ "$current_release_id" == "$release_id" ]] || die "查询期间 Release 已变化，停止操作"
case "$match_count" in
  0)
    printf '无需删除：完整查询确认 %s 的 Release %s 中没有附件 %s。\n' "$repository" "$release_tag" "$asset_name"
    exit 0
    ;;
  1)
    asset_id="$(jq -r --arg name "$asset_name" '.[] | select(.name == $name) | .id' <<< "$assets_json")"
    ;;
  *)
    die "存在多个同名附件，停止删除"
    ;;
esac

# 只删除本次完整查询中唯一匹配的附件编号。
gh api --hostname github.com --method DELETE "repos/$repository/releases/assets/$asset_id"

# 删除后重新查询全部分页，并确认仍是同一个 Release。
assets_json="$(read_assets "$release_id")"
current_release_id="$(read_release_id)"
[[ "$current_release_id" == "$release_id" ]] || die "删除后 Release 已变化，无法确认结果"
jq -e --arg name "$asset_name" '[.[] | select(.name == $name)] | length == 0' <<< "$assets_json" >/dev/null ||
  die "重新查询仍有同名附件，未确认删除完成"

# 只有删除和完整复查均成功，才报告完成。
printf '已删除并重新查询确认：%s / %s / %s。\n' "$repository" "$release_tag" "$asset_name"
