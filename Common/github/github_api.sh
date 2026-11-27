#!/usr/bin/env bash

# 使用现有 Actions / Git 认证读取 GitHub API；第二个参数可指定输出文件。
github_api_get() {
  local url="${1:-}"
  local output="${2:-}"
  local checkout_auth_header=""
  local -a headers=(
    -H 'Accept: application/vnd.github+json'
    -H 'X-GitHub-Api-Version: 2022-11-28'
  )

  [[ "$url" == https://api.github.com/* ]] || {
    echo "错误：只允许读取 GitHub API HTTPS 地址：$url" >&2
    return 1
  }

  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    headers+=( -H "Authorization: Bearer $GITHUB_TOKEN" )
  elif [[ -n "${GH_TOKEN:-}" ]]; then
    headers+=( -H "Authorization: Bearer $GH_TOKEN" )
  elif command -v git >/dev/null 2>&1; then
    checkout_auth_header="$(git config --get http.https://github.com/.extraheader 2>/dev/null || true)"
    if [[ -n "$checkout_auth_header" ]]; then
      headers+=( -H "$checkout_auth_header" )
    fi
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
