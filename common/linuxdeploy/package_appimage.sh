#!/usr/bin/env bash
set -Eeuo pipefail

APPIMAGETOOL="$1"
APPDIR="$2"
OUTFILE="$3"
RUNTIME_FILE="$4"
VERSION="${5:-}"
VERSION_FILE="${6:-$(dirname -- "$OUTFILE")/version.txt}"

VERIFY_SCRIPT=
# runtime-first 模式保留原封装命令，并在发布元数据前验证产物。
if (( $# > 6 )) && [[ "$6" == --runtime-first ]]; then
  if [[ $# != 8 || "$7" != --verify || ! -f "$8" || ! -x "$8" || -z "$VERSION" ]]; then
    echo "用法：$0 <appimagetool> <AppDir> <输出文件> <runtime> <版本> --runtime-first --verify <验证脚本>" >&2
    exit 1
  fi
  VERIFY_SCRIPT="$8"
  VERSION_FILE="$(dirname -- "$OUTFILE")/version.txt"
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# 补齐封装所需权限和 PNG 图标。
"$SCRIPT_DIR/../appimage/prepare_appdir_for_appimagetool.sh" "$APPDIR"

# 使用官方 appimagetool 和 Type 2 runtime 正式封装，并统一确认最终资产非空。
export ARCH=x86_64
export APPIMAGE_EXTRACT_AND_RUN=1
if [[ -n "$VERIFY_SCRIPT" ]]; then
  ARCH=x86_64 \
  VERSION="$VERSION" \
  APPIMAGE_EXTRACT_AND_RUN=1 \
    "$APPIMAGETOOL" \
      --runtime-file "$RUNTIME_FILE" \
      "$APPDIR" \
      "$OUTFILE"
else
  "$APPIMAGETOOL" -n "$APPDIR" "$OUTFILE" --runtime-file "$RUNTIME_FILE"
fi
[[ -s "$OUTFILE" ]] || {
  echo "错误：最终 AppImage 未生成或为空：$OUTFILE" >&2
  exit 1
}
chmod +x "$OUTFILE"
if [[ -n "$VERIFY_SCRIPT" ]]; then
  "$VERIFY_SCRIPT" "$OUTFILE" "$APPDIR" "$VERSION"
fi
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
