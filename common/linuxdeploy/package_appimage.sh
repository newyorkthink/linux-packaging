#!/usr/bin/env bash
set -Eeuo pipefail

APPIMAGETOOL="$1"
APPDIR="$2"
OUTFILE="$3"
RUNTIME_FILE="$4"
VERSION="${5:-}"
VERSION_FILE="${6:-$(dirname -- "$OUTFILE")/version.txt}"

# 使用官方 appimagetool 和 Type 2 runtime 正式封装，并统一确认最终资产非空。
export ARCH=x86_64
export APPIMAGE_EXTRACT_AND_RUN=1
"$APPIMAGETOOL" -n "$APPDIR" "$OUTFILE" --runtime-file "$RUNTIME_FILE"
[[ -s "$OUTFILE" ]] || {
  echo "错误：最终 AppImage 未生成或为空：$OUTFILE" >&2
  exit 1
}
chmod +x "$OUTFILE"
sha256sum "$OUTFILE"

# 调用方传入软件版本时，只在最终 AppImage 成功生成后原子写入标准版本元数据。
if (( $# >= 5 )); then
  [[ -n "$VERSION" ]] || {
    echo "错误：软件版本不能为空。" >&2
    exit 1
  }

  mkdir -p "$(dirname -- "$VERSION_FILE")"
  VERSION_TEMP="$(mktemp "${VERSION_FILE}.part.XXXXXX")"
  trap 'rm -f -- "$VERSION_TEMP"' EXIT
  printf '%s\n' "$VERSION" > "$VERSION_TEMP"
  chmod 0644 "$VERSION_TEMP"
  mv -f -- "$VERSION_TEMP" "$VERSION_FILE"
  trap - EXIT
fi
