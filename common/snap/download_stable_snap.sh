#!/usr/bin/env bash
set -Eeuo pipefail

SNAP_NAME="${1:-}"
PUBLISHER="${2:-}"
ARCHITECTURE="${3:-}"
OUTPUT="${4:-}"
METADATA_OUTPUT="${5:-}"
DOWNLOAD_MODE="${6:-curl}"
SNAP_SOURCE_DIRECTORY="${SNAP_SOURCE_DIRECTORY:-}"

# 仅在 DNS 解析失败时使用 Cloudflare 的 HTTPS 备用解析服务。
DOH_FALLBACK_URL="https://cloudflare-dns.com/dns-query"

[[ "$SNAP_NAME" =~ ^[a-z][a-z0-9-]*$ && -n "$PUBLISHER" &&
  "$ARCHITECTURE" =~ ^(amd64|arm64)$ && -n "$OUTPUT" ]] || {
  echo "用法：$0 <Snap 名称> <发布者帐号> <amd64|arm64> <输出文件> [元数据 JSON 输出] [curl|snap]" >&2
  exit 1
}

[[ "$DOWNLOAD_MODE" == curl || "$DOWNLOAD_MODE" == snap ]] || {
  echo "错误：Snap 下载模式只能为 curl 或 snap。" >&2
  exit 2
}

# 可选元数据只用于同次来源衔接，不能覆盖 Snap 自身或写入目录。
if [[ -n "$METADATA_OUTPUT" ]]; then
  [[ "$METADATA_OUTPUT" != / && ! -d "$METADATA_OUTPUT" &&
    "$(realpath -m -- "$METADATA_OUTPUT")" != "$(realpath -m -- "$OUTPUT")" ]] || {
    echo "错误：Snap 元数据输出路径无效，或与 Snap 输出重合。" >&2
    exit 1
  }
fi

# 官方客户端直接下载并验证签名声明；原 curl 调用不依赖这些工具。
if [[ "$DOWNLOAD_MODE" == snap ]]; then
  [[ -z "$SNAP_SOURCE_DIRECTORY" ]] || {
    echo "错误：snap 下载模式不能同时指定已下载的来源目录。" >&2
    exit 2
  }
  for command_name in snap python3 unsquashfs timeout; do
    command -v "$command_name" >/dev/null 2>&1 || {
      echo "错误：snap 下载模式需要 $command_name。" >&2
      exit 1
    }
  done
  SNAP_DOWNLOAD_WORK="$(mktemp -d)"
  trap 'rm -rf -- "$SNAP_DOWNLOAD_WORK"' EXIT

  # 明确请求目标架构的 latest/stable；进度写入 stderr，stdout 仍只返回版本。
  UBUNTU_STORE_ARCH="$ARCHITECTURE" timeout 900 snap download "$SNAP_NAME" \
    --channel=latest/stable --basename=source --target-directory="$SNAP_DOWNLOAD_WORK" >&2

  # 从客户端已验证的声明和同一份 Snap 读取身份与版本，再复核摘要并原子导出。
  python3 - "$SNAP_NAME" "$PUBLISHER" "$ARCHITECTURE" "$SNAP_DOWNLOAD_WORK" \
    "$OUTPUT" "$METADATA_OUTPUT" <<'PY'
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

try:
    import yaml
except ImportError:
    raise SystemExit("错误：snap 下载模式需要 Python 的 PyYAML。") from None


def fail(message):
    raise SystemExit("错误：" + message)


# 声明的签名链由 snap download 校验；此处按原始帧读取头部，不把正文当成元数据。
def assertion_headers(data):
    cursor = 0
    while cursor < len(data):
        while data[cursor:cursor + 1] == b"\n":
            cursor += 1
        if cursor == len(data):
            break
        end = data.find(b"\n\n", cursor)
        if end < 0:
            fail("Snap 签名声明缺少完整头部。")
        headers = yaml.load(data[cursor:end].decode("utf-8"), Loader=yaml.BaseLoader)
        if not isinstance(headers, dict) or not isinstance(headers.get("type"), str):
            fail("Snap 签名声明头部无效。")
        body_length = headers.get("body-length", "0")
        if not isinstance(body_length, str) or not re.fullmatch(r"[0-9]+", body_length):
            fail("Snap 签名声明的正文长度无效。")
        cursor = end + 2
        if int(body_length):
            cursor += int(body_length)
            if data[cursor:cursor + 2] != b"\n\n":
                fail("Snap 签名声明的正文长度不匹配。")
            cursor += 2
        signature_end = data.find(b"\n\n", cursor)
        cursor = len(data) if signature_end < 0 else signature_end + 2
        yield headers


def unique(items, message):
    if len(items) != 1:
        fail(message)
    return items[0]


def main():
    name, publisher, architecture, work, output, metadata_output = sys.argv[1:]
    work = Path(work)
    source = work / "source.snap"
    assertions = work / "source.assert"
    if any(path.is_symlink() or not path.is_file() or path.stat().st_size == 0
           for path in (source, assertions)):
        fail("官方客户端没有生成完整 Snap 和签名声明。")
    headers = list(assertion_headers(assertions.read_bytes()))
    declaration = unique(
        [item for item in headers if item.get("type") == "snap-declaration"
         and item.get("snap-name") == name and item.get("series") == "16"],
        "无法唯一确定本次 Snap 的签名身份。",
    )
    snap_id = declaration.get("snap-id", "")
    if not re.fullmatch(r"[a-zA-Z0-9]{32}", snap_id):
        fail("签名声明中的 Snap ID 无效。")
    unique(
        [item for item in headers if item.get("type") == "account"
         and item.get("account-id") == declaration.get("publisher-id")
         and item.get("username") == publisher],
        "Snap 发布者与预期账号不一致，或声明中缺少发布者账号。",
    )
    revision = unique(
        [item for item in headers if item.get("type") == "snap-revision"
         and item.get("snap-id") == snap_id],
        "无法唯一确定本次 Snap 的签名修订。",
    )
    revision_number = revision.get("snap-revision", "")
    encoded_digest = revision.get("snap-sha3-384", "")
    size = revision.get("snap-size", "")
    if (not re.fullmatch(r"[1-9][0-9]*", revision_number)
            or not re.fullmatch(r"[A-Za-z0-9_-]{64}", encoded_digest)
            or not re.fullmatch(r"[1-9][0-9]*", size)):
        fail("签名声明中的修订、SHA3-384 或大小无效。")
    expected = base64.urlsafe_b64decode(encoded_digest).hex()
    raw_metadata = subprocess.check_output(
        ["unsquashfs", "-cat", str(source), "meta/snap.yaml"],
    )
    metadata = yaml.load(raw_metadata.decode("utf-8"), Loader=yaml.BaseLoader)
    if not isinstance(metadata, dict) or metadata.get("name") != name:
        fail("Snap 包内名称与签名身份不一致。")
    architectures = metadata.get("architectures", ["all"])
    if (not isinstance(architectures, list)
            or not all(isinstance(item, str) for item in architectures)
            or architecture not in architectures and architectures != ["all"]):
        fail("Snap 包内架构与请求的架构不一致。")
    version = metadata.get("version", "")
    if not isinstance(version, str) or not re.fullmatch(
            r"[0-9]+(?:[.][0-9]+)+(?:[+._-][a-zA-Z0-9]+)*", version):
        fail("Snap 包内版本无效。")
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    temporaries = []
    try:
        with tempfile.NamedTemporaryFile(dir=output.parent, prefix=output.name + ".part.",
                                         delete=False) as target:
            staged = Path(target.name)
            temporaries.append(staged)
            digest = hashlib.sha3_384()
            written = 0
            with source.open("rb") as stream:
                while chunk := stream.read(1024 * 1024):
                    target.write(chunk)
                    digest.update(chunk)
                    written += len(chunk)
        if written != int(size) or digest.hexdigest() != expected:
            fail("Snap 文件与官方签名声明的大小或 SHA3-384 不一致。")
        os.replace(staged, output)
        if metadata_output:
            destination = Path(metadata_output)
            destination.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=destination.parent,
                                             prefix=destination.name + ".part.", delete=False) as target:
                temporary_metadata = Path(target.name)
                temporaries.append(temporary_metadata)
                json.dump({
                    "name": name, "publisher": publisher, "architecture": architecture,
                    "channel": "latest/stable", "version": version,
                    "url": "https://api.snapcraft.io/api/v1/snaps/download/"
                           + snap_id + "_" + revision_number + ".snap",
                    "sha3_384": expected,
                }, target)
                target.write("\n")
            os.replace(temporary_metadata, destination)
    finally:
        for temporary in temporaries:
            temporary.unlink(missing_ok=True)
    print(version)


try:
    main()
except (OSError, ValueError, yaml.YAMLError, subprocess.CalledProcessError) as error:
    fail("Snap 来源校验或导出失败：" + str(error))
PY
  exit 0
fi

INFO_FILE="$(mktemp)"
TEMP_SNAP=""
TEMP_METADATA=""
cleanup() {
  rm -f -- "$INFO_FILE"
  [[ -z "$TEMP_SNAP" ]] || rm -f -- "$TEMP_SNAP"
  [[ -z "$TEMP_METADATA" ]] || rm -f -- "$TEMP_METADATA"
}
trap cleanup EXIT

# 从 Snap Store 官方接口读取当前 latest/stable 通道元数据。
# 使用 HTTP/1.1 和指数退避重试，每轮保留原有请求次数和超时。
fetch_snap_metadata() {
  curl --http1.1 --fail --silent --show-error --location \
    --proto '=https' --tlsv1.2 \
    --retry 5 --retry-all-errors --retry-delay 0 \
    --connect-timeout 20 --max-time 120 \
    --header 'Snap-Device-Series: 16' \
    "$@" \
    --output "$INFO_FILE" \
    "https://api.snapcraft.io/v2/snaps/info/$SNAP_NAME"
}

# 已下载来源只由当前 workflow 传入，不重新请求元数据或下载旧版来源。
if [[ -n "$SNAP_SOURCE_DIRECTORY" ]]; then
  [[ "$SNAP_SOURCE_DIRECTORY" == /* && -d "$SNAP_SOURCE_DIRECTORY" &&
    -f "$SNAP_SOURCE_DIRECTORY/source.snap" && ! -L "$SNAP_SOURCE_DIRECTORY/source.snap" &&
    -s "$SNAP_SOURCE_DIRECTORY/source.snap" &&
    -f "$SNAP_SOURCE_DIRECTORY/source.json" && ! -L "$SNAP_SOURCE_DIRECTORY/source.json" &&
    -s "$SNAP_SOURCE_DIRECTORY/source.json" ]] || {
    echo "错误：Snap 来源目录须为绝对路径，并包含普通 Snap 和元数据文件。" >&2
    exit 1
  }
  mapfile -t FIELDS < <(
    jq -er --arg name "$SNAP_NAME" --arg publisher "$PUBLISHER" \
      --arg architecture "$ARCHITECTURE" '
        select(.name == $name and .publisher == $publisher and
               .architecture == $architecture and .channel == "latest/stable") |
        .version, .url, .sha3_384
      ' "$SNAP_SOURCE_DIRECTORY/source.json"
  )
else
  # 原请求仅在域名解析失败时改用 DoH，其他错误保留原退出状态。
  if fetch_snap_metadata; then
    :
  else
    SNAP_INFO_STATUS=$?
    if (( SNAP_INFO_STATUS != 6 )); then
      exit "$SNAP_INFO_STATUS"
    fi
    printf 'Snap Store 域名解析失败，改用 HTTPS 备用解析重试元数据。\n' >&2
    fetch_snap_metadata --doh-url "$DOH_FALLBACK_URL"
  fi

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
fi

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

if [[ -n "$SNAP_SOURCE_DIRECTORY" ]]; then
  # 复用同次官方来源，后续仍按 SHA3-384 重新核对实际文件。
  cp -- "$SNAP_SOURCE_DIRECTORY/source.snap" "$TEMP_SNAP"
else
  # 下载完整 Snap，再以官方 SHA3-384 校验；成功后才替换目标文件。
  # 显式启用 HTTP/1.1、指数退避和 DNS 备用解析，其他公共下载调用沿用默认行为。
  "$(dirname -- "${BASH_SOURCE[0]}")/../download/download_file.sh" \
    "$URL" "$TEMP_SNAP" "" "" curl http1.1 0 "$DOH_FALLBACK_URL"
fi
ACTUAL_SHA3="$(openssl dgst -sha3-384 -r "$TEMP_SNAP" | awk '{print $1}')"
[[ "${ACTUAL_SHA3,,}" == "${EXPECTED_SHA3,,}" ]] || {
  echo "错误：$SNAP_NAME Snap 的 SHA3-384 校验失败。" >&2
  exit 1
}
mv -f -- "$TEMP_SNAP" "$OUTPUT"
TEMP_SNAP=""

# 只有完整 Snap 通过官方摘要后，才按需导出同次版本、地址与身份。
if [[ -n "$METADATA_OUTPUT" ]]; then
  mkdir -p -- "$(dirname -- "$METADATA_OUTPUT")"
  TEMP_METADATA="$(mktemp "${METADATA_OUTPUT}.part.XXXXXX")"
  jq -n --arg name "$SNAP_NAME" --arg publisher "$PUBLISHER" --arg architecture "$ARCHITECTURE" \
    --arg version "$VERSION" --arg url "$URL" --arg sha3_384 "$EXPECTED_SHA3" \
    '{name: $name, publisher: $publisher, architecture: $architecture,
      channel: "latest/stable", version: $version, url: $url, sha3_384: $sha3_384}' > "$TEMP_METADATA"
  mv -f -- "$TEMP_METADATA" "$METADATA_OUTPUT"
  TEMP_METADATA=""
fi
printf '%s\n' "$VERSION"
