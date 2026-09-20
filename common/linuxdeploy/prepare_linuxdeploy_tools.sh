#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOWNLOAD_FILE="$SCRIPT_DIR/../download/download_file.sh"
TOOLS_DIR="${1:-}"
PLUGIN="${2:-}"

[[ -n "$TOOLS_DIR" ]] || {
  echo "用法：$0 <工具目录> [gtk|qt]" >&2
  exit 1
}
[[ -x "$DOWNLOAD_FILE" ]] || {
  echo "错误：公共下载脚本不存在或不可执行：$DOWNLOAD_FILE" >&2
  exit 1
}
[[ "$(uname -m)" == x86_64 ]] || {
  echo "错误：当前公共 linuxdeploy 工具准备脚本只支持 x86_64。" >&2
  exit 1
}
command -v curl >/dev/null 2>&1 || {
  echo "错误：缺少 curl。" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || {
  echo "错误：缺少 jq。" >&2
  exit 1
}

mkdir -p "$TOOLS_DIR"
TOOLS_DIR="$(cd -- "$TOOLS_DIR" && pwd)"

# 准备 GitHub API 请求头；Actions 令牌只用于提高官方 API 访问额度。
API_HEADERS=(
  -H 'Accept: application/vnd.github+json'
  -H 'X-GitHub-Api-Version: 2022-11-28'
)
if [[ -n "${GH_TOKEN:-}" ]]; then
  API_HEADERS+=( -H "Authorization: Bearer $GH_TOKEN" )
fi

# 从官方 continuous Release 解析指定资产及摘要，再交给公共下载脚本取得文件。
download_release_asset() {
  local repo="$1" asset="$2" output="$3" metadata url digest

  metadata="$(curl --fail --silent --show-error --location \
    --retry 5 --retry-all-errors --retry-delay 2 \
    --connect-timeout 20 --max-time 120 \
    "${API_HEADERS[@]}" \
    "https://api.github.com/repos/$repo/releases/tags/continuous")"
  url="$(jq -er --arg name "$asset" '.assets[] | select(.name == $name) | .browser_download_url' <<< "$metadata")"
  digest="$(jq -er --arg name "$asset" '.assets[] | select(.name == $name) | .digest' <<< "$metadata")"
  [[ "$digest" =~ ^sha256:[[:xdigit:]]{64}$ ]] || {
    echo "错误：官方资产没有有效的 SHA-256：$repo/$asset" >&2
    exit 1
  }

  "$DOWNLOAD_FILE" "$url" "$output" "$digest"
}

# 动态取得 linuxdeploy、最终封装工具和官方 Type 2 runtime。
download_release_asset linuxdeploy/linuxdeploy linuxdeploy-x86_64.AppImage \
  "$TOOLS_DIR/linuxdeploy-x86_64.AppImage"
download_release_asset AppImage/appimagetool appimagetool-x86_64.AppImage \
  "$TOOLS_DIR/appimagetool-x86_64.AppImage"
download_release_asset AppImage/type2-runtime runtime-x86_64 \
  "$TOOLS_DIR/runtime-x86_64"

# GTK / Qt 项目按需取得对应的官方 linuxdeploy 输入插件。
case "$PLUGIN" in
  '')
    ;;
  gtk)
    # GTK 插件没有 Release 资产；从官方仓库默认分支动态解析当前文件并核对 Git blob SHA。
    command -v sha1sum >/dev/null 2>&1 || {
      echo "错误：缺少 sha1sum。" >&2
      exit 1
    }
    gtk_metadata="$(curl --fail --silent --show-error --location \
      --retry 5 --retry-all-errors --retry-delay 2 \
      --connect-timeout 20 --max-time 120 \
      "${API_HEADERS[@]}" \
      "https://api.github.com/repos/linuxdeploy/linuxdeploy-plugin-gtk/contents/linuxdeploy-plugin-gtk.sh")"
    gtk_url="$(jq -er '.download_url' <<< "$gtk_metadata")"
    gtk_blob_sha="$(jq -er '.sha' <<< "$gtk_metadata")"
    [[ "$gtk_blob_sha" =~ ^[[:xdigit:]]{40}$ ]] || {
      echo "错误：官方 GTK 插件没有有效的 Git blob SHA。" >&2
      exit 1
    }
    "$DOWNLOAD_FILE" "$gtk_url" "$TOOLS_DIR/linuxdeploy-plugin-gtk"
    gtk_actual_blob_sha="$({
      printf 'blob %s\0' "$(stat -c '%s' "$TOOLS_DIR/linuxdeploy-plugin-gtk")"
      cat "$TOOLS_DIR/linuxdeploy-plugin-gtk"
    } | sha1sum | awk '{print $1}')"
    [[ "$gtk_actual_blob_sha" == "$gtk_blob_sha" ]] || {
      echo "错误：GTK 插件 Git blob SHA 校验失败。" >&2
      exit 1
    }
    chmod +x "$TOOLS_DIR/linuxdeploy-plugin-gtk"
    sha256sum "$TOOLS_DIR/linuxdeploy-plugin-gtk"
    ;;
  qt)
    download_release_asset linuxdeploy/linuxdeploy-plugin-qt linuxdeploy-plugin-qt-x86_64.AppImage \
      "$TOOLS_DIR/linuxdeploy-plugin-qt-x86_64.AppImage"
    chmod +x "$TOOLS_DIR/linuxdeploy-plugin-qt-x86_64.AppImage"
    ;;
  *)
    echo "错误：当前不支持的 linuxdeploy 输入插件：$PLUGIN" >&2
    exit 1
    ;;
esac

# 只给需要直接执行的 AppImage 工具增加执行权限，并提供标准 linuxdeploy 命令名。
chmod +x \
  "$TOOLS_DIR/linuxdeploy-x86_64.AppImage" \
  "$TOOLS_DIR/appimagetool-x86_64.AppImage"
ln -sfn linuxdeploy-x86_64.AppImage "$TOOLS_DIR/linuxdeploy"
