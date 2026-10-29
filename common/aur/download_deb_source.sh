#!/usr/bin/env bash
set -Eeuo pipefail

# 定位现有的 AUR 来源解析和公共下载入口。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 接收调用方提供的软件包、架构和 DEB 输出路径。
if (( $# != 3 )) || [[ -z "$1" || -z "$2" || -z "$3" ]]; then
  echo "用法：$0 <AUR 包名> <架构> <DEB 输出文件>" >&2
  exit 2
fi

# 为本次解析创建独立的临时目录，避免把中间元数据留在应用目录。
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/aur-deb-download.XXXXXXXX")"

# 无论成功或失败，都只清理本次创建的临时目录。
cleanup() {
  rm -rf -- "$work_dir"
}
trap cleanup EXIT

# 从当前 .SRCINFO 取得唯一的架构专用 DEB 地址和 SHA-256。
"$SCRIPT_DIR/resolve_deb_source.sh" "$1" "$2" "$work_dir" "$work_dir/source.env" "$work_dir/dependencies.txt"

# 载入已经由公共解析入口转义的元数据，不在调用方重复解析来源。
source "$work_dir/source.env"

# 使用公共下载入口校验 SHA-256，并在成功后原子写入调用方指定的文件。
"$SCRIPT_DIR/../download/download_file.sh" "$SOURCE_URL" "$3" "$EXPECTED_SHA256"
