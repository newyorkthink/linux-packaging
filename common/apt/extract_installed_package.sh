#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 接收主软件包名称、AppDir 路径和可选的附加软件包。
PACKAGE="${1:-}"
APPDIR="${2:-}"

# 检查调用参数。
[[ $# -ge 2 && -n "$PACKAGE" && -n "$APPDIR" ]] || {
  echo "用法：$0 <主软件包名> <AppDir> [附加软件包名 ...]" >&2
  exit 2
}

# 读取本次实际安装的软件包完整版本。
PACKAGE_VERSION="$(dpkg-query -W -f='${Version}\n' "$PACKAGE")"

# 读取附加软件包的已安装版本，在下载前确定全部软件包的精确版本。
PACKAGE_SPECS=("$PACKAGE=$PACKAGE_VERSION")
for EXTRA_PACKAGE in "${@:3}"; do
  [[ -n "$EXTRA_PACKAGE" ]] || {
    echo "错误：附加软件包名称不能为空。" >&2
    exit 2
  }
  EXTRA_VERSION="$(dpkg-query -W -f='${Version}\n' "$EXTRA_PACKAGE")"
  [[ -n "$EXTRA_VERSION" && "$EXTRA_VERSION" != *[[:space:]]* ]] || {
    echo "错误：无法读取附加软件包的已安装版本：$EXTRA_PACKAGE" >&2
    exit 1
  }
  PACKAGE_SPECS+=("$EXTRA_PACKAGE=$EXTRA_VERSION")
done

# 下载实际安装版本的软件包，并按原始布局解包到 AppDir。
"$SCRIPT_DIR/download_and_extract_packages.sh" "$APPDIR" "${PACKAGE_SPECS[@]}" >&2

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
