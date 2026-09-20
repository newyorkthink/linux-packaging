#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOWNLOAD_FILE="$SCRIPT_DIR/download_file.sh"
CHECKSUM_URL="${1:-}"
ASSET_REGEX="${2:-}"
OUTPUT="${3:-}"
VERSION_FILE="${4:-}"

[[ -n "$CHECKSUM_URL" && -n "$ASSET_REGEX" && -n "$OUTPUT" && -n "$VERSION_FILE" ]] || {
  echo "用法：$0 <HTTPS 校验清单 URL> <完整资产名正则> <输出文件> <版本文件>" >&2
  exit 1
}
[[ "$CHECKSUM_URL" == https://* ]] || {
  echo "错误：只允许 HTTPS 校验清单：$CHECKSUM_URL" >&2
  exit 1
}
[[ "$ASSET_REGEX" == ^* && "$ASSET_REGEX" == *'$' ]] || {
  echo "错误：资产名正则必须同时包含 ^ 和 $ 锚点：$ASSET_REGEX" >&2
  exit 1
}
[[ -x "$DOWNLOAD_FILE" ]] || {
  echo "错误：公共下载脚本不存在或不可执行：$DOWNLOAD_FILE" >&2
  exit 1
}

for command_name in grep mktemp sed sort tail; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "错误：缺少必需命令：$command_name" >&2
    exit 1
  }
done

CHECKSUM_FILE="$(mktemp)"
VERSION_TEMP=''

# 退出时只删除本次解析产生的临时校验清单。
cleanup() {
  rm -f -- "$CHECKSUM_FILE"
  if [[ -n "$VERSION_TEMP" ]]; then
    rm -f -- "$VERSION_TEMP"
  fi
}
trap cleanup EXIT

# 下载官方校验清单，并按完整文件名正则选择版本号最高的唯一资产。
"$DOWNLOAD_FILE" "$CHECKSUM_URL" "$CHECKSUM_FILE"
CANDIDATE="$({
  while read -r digest name _; do
    name="${name#\*}"
    name="${name%$'\r'}"
    [[ "$digest" =~ ^[[:xdigit:]]{64}$ ]] || continue
    [[ "$name" =~ $ASSET_REGEX ]] || continue
    printf '%s\t%s\n' "$name" "$digest"
  done < "$CHECKSUM_FILE"
} | sort -t $'\t' -k1,1V | tail -n 1)"

[[ -n "$CANDIDATE" ]] || {
  echo "错误：官方校验清单中没有符合正则的资产：$ASSET_REGEX" >&2
  exit 1
}

IFS=$'\t' read -r ASSET_NAME ASSET_SHA256 <<< "$CANDIDATE"
[[ "$ASSET_NAME" != */* && "$ASSET_NAME" != *..* ]] || {
  echo "错误：官方校验清单包含不安全的资产名：$ASSET_NAME" >&2
  exit 1
}
[[ "$ASSET_SHA256" =~ ^[[:xdigit:]]{64}$ ]] || {
  echo "错误：官方资产没有有效的 SHA-256：$ASSET_NAME" >&2
  exit 1
}

VERSION="$(grep -oE '[0-9]+([.][0-9]+)+' <<< "$ASSET_NAME" | sed -n '1p')"
[[ "$VERSION" =~ ^[0-9]+([.][0-9]+)+$ ]] || {
  echo "错误：无法从资产名解析版本：$ASSET_NAME" >&2
  exit 1
}

ASSET_URL="${CHECKSUM_URL%/*}/$ASSET_NAME"
printf '官方稳定版来源：%s\n' "$ASSET_URL"
"$DOWNLOAD_FILE" "$ASSET_URL" "$OUTPUT" "$ASSET_SHA256"

# 下载和摘要校验成功后，原子写入本次实际取得的软件版本。
mkdir -p "$(dirname -- "$VERSION_FILE")"
VERSION_TEMP="$(mktemp "${VERSION_FILE}.part.XXXXXX")"
printf '%s\n' "$VERSION" > "$VERSION_TEMP"
mv -f -- "$VERSION_TEMP" "$VERSION_FILE"
VERSION_TEMP=''
