#!/usr/bin/env bash
set -Eeuo pipefail

SNAP_NAME="${1:-}"
PUBLISHER="${2:-}"
ARCHITECTURE="${3:-}"
OUTPUT="${4:-}"

[[ "$SNAP_NAME" =~ ^[a-z][a-z0-9-]*$ && -n "$PUBLISHER" &&
  "$ARCHITECTURE" =~ ^(amd64|arm64)$ && -n "$OUTPUT" ]] || {
  echo "用法：$0 <Snap 名称> <发布者帐号> <amd64|arm64> <输出文件>" >&2
  exit 1
}

INFO_FILE="$(mktemp)"
TEMP_SNAP=""
cleanup() {
  rm -f -- "$INFO_FILE"
  [[ -z "$TEMP_SNAP" ]] || rm -f -- "$TEMP_SNAP"
}
trap cleanup EXIT

# 从 Snap Store 官方接口读取当前 latest/stable 通道元数据。
curl --fail --silent --show-error --location \
  --proto '=https' --tlsv1.2 \
  --retry 5 --retry-all-errors --retry-delay 2 \
  --connect-timeout 20 --max-time 120 \
  --header 'Snap-Device-Series: 16' \
  --output "$INFO_FILE" \
  "https://api.snapcraft.io/v2/snaps/info/$SNAP_NAME"

mapfile -t FIELDS < <(
  jq -er --arg name "$SNAP_NAME" --arg publisher "$PUBLISHER" \
    --arg architecture "$ARCHITECTURE" '
      select(.name == $name and .snap.name == $name and
             .snap.publisher.username == $publisher) |
      [."channel-map"[] |
       select(.channel.track == "latest" and .channel.risk == "stable" and
              .channel.architecture == $architecture)] |
      if length == 1 then
        first | .version, .download.url, .download."sha3-384"
      else empty end
    ' "$INFO_FILE"
)

(( ${#FIELDS[@]} == 3 )) || {
  echo "错误：无法唯一确定 $SNAP_NAME 的 $ARCHITECTURE latest/stable 版本。" >&2
  exit 1
}
VERSION="${FIELDS[0]}"
URL="${FIELDS[1]}"
EXPECTED_SHA3="${FIELDS[2]}"
[[ "$VERSION" =~ ^[0-9]+([.][0-9]+)+([+._-][a-zA-Z0-9]+)*$ &&
  "$URL" =~ ^https://api[.]snapcraft[.]io/api/v1/snaps/download/[a-zA-Z0-9]+_[0-9]+[.]snap$ &&
  "$EXPECTED_SHA3" =~ ^[[:xdigit:]]{96}$ ]] || {
  echo "错误：Snap Store 版本、下载地址或 SHA3-384 无效。" >&2
  exit 1
}

mkdir -p -- "$(dirname -- "$OUTPUT")"
TEMP_SNAP="$(mktemp "${OUTPUT}.part.XXXXXX")"

# 下载完整 Snap，再以官方 SHA3-384 校验；成功后才替换目标文件。
"$(dirname -- "${BASH_SOURCE[0]}")/../download/download_file.sh" "$URL" "$TEMP_SNAP"
ACTUAL_SHA3="$(openssl dgst -sha3-384 -r "$TEMP_SNAP" | awk '{print $1}')"
[[ "${ACTUAL_SHA3,,}" == "${EXPECTED_SHA3,,}" ]] || {
  echo "错误：$SNAP_NAME Snap 的 SHA3-384 校验失败。" >&2
  exit 1
}
mv -f -- "$TEMP_SNAP" "$OUTPUT"
TEMP_SNAP=""
printf '%s\n' "$VERSION"
