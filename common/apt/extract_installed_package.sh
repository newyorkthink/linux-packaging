#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 接收已安装的软件包名称和 AppDir 路径。
PACKAGE="${1:-}"
APPDIR="${2:-}"

# 检查调用参数。
[[ $# -eq 2 && -n "$PACKAGE" && -n "$APPDIR" ]] || {
  echo "用法：$0 <已安装的软件包名> <AppDir>" >&2
  exit 2
}

# 读取本次实际安装的软件包完整版本。
PACKAGE_VERSION="$(dpkg-query -W -f='${Version}\n' "$PACKAGE")"

# 下载实际安装版本的软件包，并按原始布局解包到 AppDir。
"$SCRIPT_DIR/download_and_extract_packages.sh" "$APPDIR" "$PACKAGE=$PACKAGE_VERSION" >&2

# 去掉 Debian epoch 和 revision，取得上游版本号。
VERSION="${PACKAGE_VERSION#*:}"
VERSION="${VERSION%-*}"

# 检查上游版本号。
[[ -n "$VERSION" && "$VERSION" != *[[:space:]]* ]] || {
  echo "错误：无法读取软件包的上游版本：$PACKAGE" >&2
  exit 1
}

# 全部步骤成功后，仅向标准输出返回版本号。
printf '%s\n' "$VERSION"
