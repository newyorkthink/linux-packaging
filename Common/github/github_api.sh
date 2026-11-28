#!/usr/bin/env bash

# 获取 Actions 或当前 checkout 使用的 GitHub 认证请求头。
github_api_auth_header() {
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    printf 'Authorization: Bearer %s\n' "$GITHUB_TOKEN"
  elif [[ -n "${GH_TOKEN:-}" ]]; then
    printf 'Authorization: Bearer %s\n' "$GH_TOKEN"
  elif command -v git >/dev/null 2>&1; then
    git config --get http.https://github.com/.extraheader 2>/dev/null
  else
    return 1
  fi
}

# 使用现有 Actions / Git 认证读取 GitHub API；第二个参数可指定输出文件。
github_api_get() {
  local url="${1:-}"
  local output="${2:-}"
  local auth_header
  local -a headers=(
    -H 'Accept: application/vnd.github+json'
    -H 'X-GitHub-Api-Version: 2022-11-28'
  )

  [[ "$url" == https://api.github.com/* ]] || {
    echo "错误：只允许读取 GitHub API HTTPS 地址：$url" >&2
    return 1
  }

  if auth_header="$(github_api_auth_header)" && [[ -n "$auth_header" ]]; then
    headers+=( -H "$auth_header" )
  fi

  if [[ -n "$output" ]]; then
    curl --fail --silent --show-error --location \
      --proto '=https' \
      --tlsv1.2 \
      --retry 5 \
      --retry-all-errors \
      --retry-delay 2 \
      --connect-timeout 20 \
      --max-time 120 \
      "${headers[@]}" \
      --output "$output" \
      "$url"
  else
    curl --fail --silent --show-error --location \
      --proto '=https' \
      --tlsv1.2 \
      --retry 5 \
      --retry-all-errors \
      --retry-delay 2 \
      --connect-timeout 20 \
      --max-time 120 \
      "${headers[@]}" \
      "$url"
  fi
}

# 先校验官方直链；失败后凭同一个资产 ID 认证下载，再校验同一 SHA-256。
github_download_release_asset() (
  local repo="$1" asset_id="$2" url="$3" digest="${4#sha256:}" output="$5"
  local api_dir auth_header output_dir temp_file actual_sha256

  if [[ ! "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ||
        "/$repo/" == */../* || "/$repo/" == */./* ||
        ! "$asset_id" =~ ^[1-9][0-9]*$ ||
        "${url,,}" != "https://github.com/${repo,,}/releases/download/"* ||
        ! "$digest" =~ ^[[:xdigit:]]{64}$ || -z "$output" ]]; then
    echo "错误：GitHub Release 资产地址、ID、SHA-256 或输出路径无效。" >&2
    return 1
  fi

  api_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || return 1
  if "$api_dir/../download/download_file.sh" "$url" "$output" "$digest" >&2; then
    return 0
  fi

  if ! auth_header="$(github_api_auth_header)" ||
     [[ "${auth_header,,}" != authorization:\ ?* || "$auth_header" == *$'\n'* || "$auth_header" == *$'\r'* ]]; then
    echo "错误：Release 直链失败，且缺少有效的 GitHub 认证凭据：$repo / $asset_id" >&2
    return 1
  fi

  output_dir="$(dirname -- "$output")" || return 1
  mkdir -p -- "$output_dir" || return 1
  temp_file="$(mktemp -- "${output}.part.XXXXXXXX")" || return 1
  trap 'rm -f -- "$temp_file"' EXIT

  # 只向 GitHub API 发送认证头，curl 不把它转发给跨主机的签名下载地址。
  curl --disable --fail --silent --show-error --location --proto '=https' --proto-redir '=https' --tlsv1.2 \
    --retry 3 --retry-delay 2 --connect-timeout 20 --max-time 900 \
    -H 'Accept: application/octet-stream' \
    -H "$auth_header" \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    --output "$temp_file" "https://api.github.com/repos/$repo/releases/assets/$asset_id" || return 1

  actual_sha256="$(sha256sum < "$temp_file")" || return 1
  if [[ "${actual_sha256%% *}" != "${digest,,}" ]]; then
    echo "错误：认证下载的 GitHub Release 资产 SHA-256 不匹配：$repo / $asset_id" >&2
    return 1
  fi

  mv -fT -- "$temp_file" "$output" || return 1
  printf '%s  %s\n' "${digest,,}" "$output" >&2
)
