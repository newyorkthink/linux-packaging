#!/usr/bin/env bash
set -Eeuo pipefail

# 通过认证 API 将来源引用解析到提交，再获取该提交中的单个文件。
if (( $# != 4 )) || [[ ! "$1" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ||
  "/$1/" == */../* || "/$1/" == */./* || -z "$2" || "$2" == . || "$2" == .. || "$2" == *[[:space:][:cntrl:]]* ||
  -z "$3" || "$3" == *[[:cntrl:]]* || "/$3/" == *//* ||
  "/$3/" == */../* || "/$3/" == */./* || -z "$4" || "$4" == */ || -d "$4" ]]; then
  echo "用法：$0 <owner/repo> <分支、标签或提交 SHA> <仓库内文件路径> <输出文件>" >&2
  exit 2
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Common/github/github_api.sh
source "$SCRIPT_DIR/github_api.sh"
AUTH_HEADER="$(github_api_auth_header)" || AUTH_HEADER=""
if [[ "${AUTH_HEADER,,}" != authorization:\ ?* || "$AUTH_HEADER" == *$'\n'* || "$AUTH_HEADER" == *$'\r'* ]]; then
  echo "错误：读取 GitHub 仓库文件需要有效的认证凭据。" >&2
  exit 1
fi

REPO="$1"
REF="$2"
REPOSITORY_PATH="$3"
OUTPUT="$4"
OUTPUT_DIR="$(dirname -- "$OUTPUT")"
mkdir -p -- "$OUTPUT_DIR"
WORK_DIR="$(mktemp -d "$OUTPUT_DIR/.repository-file.XXXXXXXX")"
trap 'rm -rf -- "$WORK_DIR"' EXIT

# 分支或标签可能含斜杠，文件地址只保留实际目录分隔符。
ENCODED_REF="$(python3 -c 'import sys; from urllib.parse import quote; print(quote(sys.argv[1], safe=""))' "$REF")"
ENCODED_PATH="$(python3 -c 'import sys; from urllib.parse import quote; print(quote(sys.argv[1], safe="/"))' "$REPOSITORY_PATH")"
API="https://api.github.com/repos/$REPO"
github_api_get "$API/commits/$ENCODED_REF" "$WORK_DIR/commit.json"
COMMIT="$(jq -er '.sha | select(type == "string" and test("^[0-9a-f]{40}$"))' "$WORK_DIR/commit.json")"
github_api_get "$API/contents/$ENCODED_PATH?ref=$COMMIT" "$WORK_DIR/file.json"

# 使用 API 返回的大小及 Git blob SHA 校验解码后的字节，再原子替换目标。
python3 - "$WORK_DIR/file.json" "$REPOSITORY_PATH" "$WORK_DIR/verified" <<'PY'
import base64
import binascii
import hashlib
import json
from pathlib import Path
import sys

metadata_path, expected_path, output_path = sys.argv[1:]
metadata = json.loads(Path(metadata_path).read_text(encoding="utf-8"))
if (
    not isinstance(metadata, dict) or metadata.get("type") != "file"
    or metadata.get("path") != expected_path or metadata.get("encoding") != "base64"
    or not isinstance(metadata.get("content"), str)
    or type(metadata.get("size")) is not int
):
    raise SystemExit("错误：GitHub API 未返回指定文件的完整内容及元数据。")

try:
    data = base64.b64decode(metadata["content"].replace("\n", ""), validate=True)
except (ValueError, binascii.Error):
    raise SystemExit("错误：GitHub 文件的 Base64 内容无效。") from None
header = f"blob {len(data)}\0".encode("ascii")
if len(data) != metadata["size"] or hashlib.sha1(header + data).hexdigest() != metadata.get("sha"):
    raise SystemExit("错误：GitHub 文件的大小或 Git blob SHA 不匹配。")
Path(output_path).write_bytes(data)
PY

mv -fT -- "$WORK_DIR/verified" "$OUTPUT"
printf '%s\n' "$COMMIT"
