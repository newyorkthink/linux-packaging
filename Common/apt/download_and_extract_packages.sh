#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
EXTRACT_ARCHIVE="$SCRIPT_DIR/../archive/extract_archive.sh"
OUTPUT_DIR="${1:-}"
shift || true

[[ -n "$OUTPUT_DIR" && $# -gt 0 ]] || {
  echo "用法：$0 <解包目标目录> <软件包名> [...]" >&2
  exit 1
}
[[ -x "$EXTRACT_ARCHIVE" ]] || {
  echo "错误：公共归档解包入口不存在或不可执行：$EXTRACT_ARCHIVE" >&2
  exit 1
}
command -v apt-get >/dev/null 2>&1 || {
  echo "错误：缺少 apt-get。" >&2
  exit 1
}

TEMP_DIR="$(mktemp -d)"

# 退出时删除只用于承载下载 DEB 的临时目录。
cleanup() {
  rm -rf -- "$TEMP_DIR"
}
trap cleanup EXIT

# 只下载调用方明确指定的软件包，不安装到构建环境。
(
  cd "$TEMP_DIR"
  apt-get download "$@"
)

# 逐个通过公共归档入口解包，保持各 DEB 自身的原始目录布局。
shopt -s nullglob
DEB_FILES=("$TEMP_DIR"/*.deb)
(( ${#DEB_FILES[@]} > 0 )) || {
  echo "错误：APT 未下载任何 DEB。" >&2
  exit 1
}
for deb_file in "${DEB_FILES[@]}"; do
  "$EXTRACT_ARCHIVE" "$deb_file" "$OUTPUT_DIR"
done
