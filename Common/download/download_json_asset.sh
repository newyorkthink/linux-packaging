#!/usr/bin/env bash

# 命令失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 读取来源选择、发布校验及输出参数。
if (( $# < 9 )); then
  printf '%s\n' \
    '用法：download_json_asset.sh <JSON URL> <资产 jq> <地址正则> <版本正则> <仓库> <软件键> <发布资产> <输出文件> <版本文件>' \
    '      [--metadata-alternate <JSON URL>] [--pkgbuild <URL> <地址字段> <SHA-256 字段> <版本字段>]' \
    '      [--resolve-json-url <Cookie URL> <POST URL> <请求字段> <返回字段路径>] [--resolve-header <请求头>]...' >&2
  exit 2
fi

metadata_url="$1"
asset_filter="$2"
url_regex="$3"
version_regex="$4"
repository="$5"
software_key="$6"
release_asset="$7"
output="$8"
version_file="$9"
shift 9

# 输出明确的错误并终止。
fail() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

alternate_url=''
if [[ "${1:-}" == --metadata-alternate ]]; then
  (( $# >= 2 )) && [[ -n "$2" ]] || fail '--metadata-alternate 需要一个 HTTPS 地址。'
  alternate_url="$2"
  shift 2
fi

pkgbuild_args=()
if [[ "${1:-}" == --pkgbuild ]]; then
  (( $# >= 5 )) || fail '--pkgbuild 需要配方地址及三个字段名。'
  pkgbuild_args=("$2" "$3" "$4" "$5")
  shift 5
fi

resolve_args=()
if (( $# )); then
  [[ "$1" == --resolve-json-url ]] && (( $# >= 5 )) || fail '链接解析参数必须以 --resolve-json-url 开头。'
  resolve_args=("$@")
fi

[[ "$repository" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ && -n "$software_key" &&
   -n "$release_asset" && "$release_asset" != */* && -n "$asset_filter" &&
   -n "$url_regex" && -n "$version_regex" && -n "$output" && -n "$version_file" &&
   "$output" != */ && "$version_file" != */ && ! -d "$output" && ! -d "$version_file" ]] ||
  fail '参数缺失或格式无效。'

# 输出与版本记录必须使用不同的文件。
output_path="$(readlink -m -- "$output")"
version_path="$(readlink -m -- "$version_file")"
[[ "$output_path" != "$version_path" ]] || fail '输出文件和版本文件必须使用不同路径。'

# 定位仓库内的公共下载入口。
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
download_file="$script_dir/download_file.sh"

# 已配置且有效的配方继续走现有下载与校验流程。
if (( ${#pkgbuild_args[@]} )); then
  source "$script_dir/../aur/download_pkgbuild_asset.sh"
  if download_pkgbuild_asset "${pkgbuild_args[@]}" "$output" "$version_file" \
    --url-regex "$url_regex" --version-regex "$version_regex" "${resolve_args[@]}"; then
    exit 0
  fi
  printf '配方来源不可用，改从官方 JSON 读取资产地址。\n' >&2
fi

# 本次元数据与版本暂存文件退出时清理。
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/json-asset.XXXXXXXX")"
version_temp=''
trap 'rm -rf -- "$work_dir"; if [[ -n "$version_temp" ]]; then rm -f -- "$version_temp"; fi' EXIT

# 只接受官方 JSON 中唯一匹配地址规则的资产。
resolve_asset() {
  local candidate
  "$download_file" "$1" "$work_dir/metadata.json" >&2 || return 1
  candidate="$(
    jq -ers "[.[] | ($asset_filter)] | select(length == 1) | .[0] | strings" "$work_dir/metadata.json"
  )" || return 1
  [[ "$candidate" == https://* && "$candidate" != *[[:space:]]* && "$candidate" =~ $url_regex ]] || return 1
  printf '%s\n' "$candidate"
}

if ! asset_url="$(resolve_asset "$metadata_url")"; then
  [[ -n "$alternate_url" ]] && asset_url="$(resolve_asset "$alternate_url")" || fail '官方 JSON 未提供符合规则的资产地址。'
fi

# 沿用首个捕获组为版本、可选第二组为构建标识的格式。
[[ "$asset_url" =~ $version_regex ]] || fail '无法从官方资产地址解析版本。'
(( ${#BASH_REMATCH[@]} == 2 || ${#BASH_REMATCH[@]} == 3 )) || fail '版本正则必须提供一个或两个捕获组。'
version="${BASH_REMATCH[1]}"
if [[ -n "${BASH_REMATCH[2]:-}" ]]; then
  version+="-${BASH_REMATCH[2]}"
fi
[[ "$version" =~ ^[0-9][0-9A-Za-z.+:~_-]*$ ]] || fail '官方资产版本格式无效。'

# 通过公共入口下载并校验发布清单，再读取当前 Release 的摘要。
"$script_dir/../github/download_tagged_release_asset.sh" \
  "$repository" latest software_versions.json "$work_dir/versions.json" >&2
source "$script_dir/../github/github_api.sh"
github_api_get "https://api.github.com/repos/$repository/releases/tags/latest" "$work_dir/release.json"

# 只使用同一正式 Release 中唯一已上传资产的 SHA-256。
release_digest() {
  jq -er --arg name "$1" '
    select(.tag_name == "latest" and .draft == false and .prerelease == false)
    | [.assets[] | select(.name == $name and .state == "uploaded")]
    | select(length == 1) | .[0].digest | strings | select(test("^sha256:[0-9a-fA-F]{64}$"))
  ' "$work_dir/release.json"
}

manifest_digest="$(release_digest software_versions.json)" || fail '无法取得已发布版本清单的摘要。'
printf '%s  %s\n' "${manifest_digest#sha256:}" "$work_dir/versions.json" | sha256sum -c --status ||
  fail '发布清单在核对期间发生变化。'

# 仅使用同一版本且清单与 Release 资产摘要一致的校验值。
manifest_sha256="$(jq -er --arg key "$software_key" --arg version "$version" --arg asset "$release_asset" '
  .[$key] | select(.version == $version and .asset == $asset)
  | .sha256 | strings | select(test("^[0-9a-fA-F]{64}$"))
' "$work_dir/versions.json")" || fail "已发布清单没有版本 $version 的匹配资产摘要。"
asset_digest="$(release_digest "$release_asset")" || fail '无法取得已发布资产的摘要。'
[[ "${asset_digest,,}" == "sha256:${manifest_sha256,,}" ]] || fail '版本清单与已发布资产的摘要不一致。'

# 下载校验成功后才替换版本记录。
mkdir -p -- "$(dirname -- "$version_file")"
version_temp="$(mktemp -- "$version_file.part.XXXXXXXX")"
printf '%s\n' "$version" > "$version_temp"
if (( ${#resolve_args[@]} )); then
  "$download_file" "${resolve_args[@]}" -- "$asset_url" "$output" "$manifest_sha256" >&2
else
  "$download_file" "$asset_url" "$output" "$manifest_sha256" >&2
fi
mv -fT -- "$version_temp" "$version_file"
version_temp=''
