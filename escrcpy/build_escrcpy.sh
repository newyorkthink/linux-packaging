#!/usr/bin/env bash
# 动态获取 Escrcpy 官方最新稳定版 Linux x86_64 AppImage，校验 GitHub Release digest 后按仓库稳定资产名发布。
set -Eeuo pipefail

###### 准备构建环境 ######

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
cd "$SCRIPT_DIR"

ARCH="$(uname -m)"
readonly ARCH
if [[ "$ARCH" != x86_64 ]]; then
  printf '错误：当前仅支持 x86_64。\n' >&2
  exit 1
fi

# 仅安装解析 Release 元数据、下载文件和校验 SHA-256 所需工具。
yay -S --noconfirm --needed curl jq coreutils ca-certificates

readonly SOURCE_DIR="$SCRIPT_DIR/source"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly RELEASE_JSON="$SOURCE_DIR/release.json"
readonly OFFICIAL_APPIMAGE="$SOURCE_DIR/Escrcpy-linux-x86_64.AppImage"
readonly OUTPUT="$DIST_DIR/escrcpy.AppImage"
readonly RELEASE_API="https://api.github.com/repos/viarotel-org/escrcpy/releases/latest"

# 只清理本应用自己的临时下载目录和产物目录。
rm -rf -- "$SOURCE_DIR" "$DIST_DIR"
mkdir -p "$SOURCE_DIR" "$DIST_DIR"

###### 下载上游文件 ######

curl_args=(
  --fail --location
  --retry 5 --retry-all-errors --retry-delay 2
  --connect-timeout 20 --max-time 1800
  -H 'Accept: application/vnd.github+json'
  -H 'X-GitHub-Api-Version: 2022-11-28'
)
if [[ -n "${GH_TOKEN:-}" ]]; then
  curl_args+=(-H "Authorization: Bearer $GH_TOKEN")
fi

# GitHub latest Release 作为唯一版本入口，不在仓库中写死应用版本。
curl "${curl_args[@]}" "$RELEASE_API" -o "$RELEASE_JSON"

jq -e '.draft == false and .prerelease == false' "$RELEASE_JSON" >/dev/null || {
  printf '错误：GitHub latest 返回的不是稳定 Release。\n' >&2
  exit 1
}

TAG_NAME="$(jq -r '.tag_name // empty' "$RELEASE_JSON")"
if [[ ! "$TAG_NAME" =~ ^v?([0-9]+\.[0-9]+\.[0-9]+([.+-][0-9A-Za-z.-]+)?)$ ]]; then
  printf '错误：无法识别 Escrcpy 稳定版本标签：%s\n' "$TAG_NAME" >&2
  exit 1
fi
VERSION="${BASH_REMATCH[1]}"
readonly VERSION
readonly EXPECTED_ASSET="Escrcpy-${VERSION}-linux-x86_64.AppImage"

mapfile -t asset_rows < <(
  jq -r --arg name "$EXPECTED_ASSET" \
    '.assets[] | select(.name == $name) | [.browser_download_url, (.digest // "")] | @tsv' \
    "$RELEASE_JSON"
)
if [[ ${#asset_rows[@]} -ne 1 ]]; then
  printf '错误：Release 中预期存在且仅存在一个资产：%s\n' "$EXPECTED_ASSET" >&2
  exit 1
fi

IFS=$'\t' read -r DOWNLOAD_URL RELEASE_DIGEST <<< "${asset_rows[0]}"
if [[ "$DOWNLOAD_URL" != https://github.com/viarotel-org/escrcpy/releases/download/*/"$EXPECTED_ASSET" ]]; then
  printf '错误：Release 资产下载地址不符合预期：%s\n' "$DOWNLOAD_URL" >&2
  exit 1
fi
if [[ ! "$RELEASE_DIGEST" =~ ^sha256:([0-9a-fA-F]{64})$ ]]; then
  printf '错误：Release 资产缺少可用的 SHA-256 digest。\n' >&2
  exit 1
fi
EXPECTED_SHA256="${BASH_REMATCH[1],,}"
readonly EXPECTED_SHA256

curl "${curl_args[@]}" "$DOWNLOAD_URL" -o "$OFFICIAL_APPIMAGE"
if [[ ! -s "$OFFICIAL_APPIMAGE" ]]; then
  printf '错误：下载到的官方 AppImage 为空。\n' >&2
  exit 1
fi

ACTUAL_SHA256="$(sha256sum "$OFFICIAL_APPIMAGE" | awk '{print tolower($1)}')"
readonly ACTUAL_SHA256
if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
  printf '错误：官方 AppImage SHA-256 校验失败。\n预期：%s\n实际：%s\n' \
    "$EXPECTED_SHA256" "$ACTUAL_SHA256" >&2
  exit 1
fi

###### 整理产物 ######

# 不改写官方 AppImage 内容，只统一本仓库 latest Release 中的稳定资产名。
install -Dm0755 "$OFFICIAL_APPIMAGE" "$OUTPUT"
printf '%s\n' "$VERSION" > "$HOME/version"

printf 'Escrcpy version: %s\n' "$VERSION"
printf 'Source asset: %s\n' "$EXPECTED_ASSET"
printf 'SHA-256: %s\n' "$ACTUAL_SHA256"
printf 'Output: %s\n' "$OUTPUT"
