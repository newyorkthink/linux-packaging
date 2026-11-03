#!/usr/bin/env bash
set -Eeuo pipefail

if (( $# != 4 )) || [[ -z "$1" || -z "$2" || "$3" != *.tar.gz || -z "$4" ]]; then
  echo "用法：$0 <AUR 包名> <架构> <输出.tar.gz> <元数据输出文件>" >&2
  exit 2
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="$3"
METADATA_FILE="$4"
[[ "$(readlink -m -- "$OUTPUT")" != "$(readlink -m -- "$METADATA_FILE")" && ! -d "$OUTPUT" && ! -d "$METADATA_FILE" ]] || {
  echo "错误：归档与元数据必须使用不同的文件路径。" >&2
  exit 2
}

# 元数据和归档使用同次 AUR 快照，校验成功后才发布元数据。
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/aur-tar-download.XXXXXXXX")"
METADATA_TEMP=""
cleanup() {
  rm -rf -- "$WORK_DIR"
  [[ -z "$METADATA_TEMP" ]] || rm -f -- "$METADATA_TEMP"
}
trap cleanup EXIT

"$SCRIPT_DIR/resolve_deb_source.sh" "$1" "$2" "$WORK_DIR" "$WORK_DIR/source.env" "$WORK_DIR/dependencies.txt" --tar-gz
source "$WORK_DIR/source.env"

mkdir -p -- "$(dirname -- "$METADATA_FILE")"
METADATA_TEMP="$(mktemp "${METADATA_FILE}.part.XXXXXX")"
cp -- "$WORK_DIR/source.env" "$METADATA_TEMP"
"$SCRIPT_DIR/../download/download_file.sh" "$SOURCE_URL" "$OUTPUT" "$SOURCE_CHECKSUM"
mv -fT -- "$METADATA_TEMP" "$METADATA_FILE"
METADATA_TEMP=""
