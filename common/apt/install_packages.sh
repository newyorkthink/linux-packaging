#!/usr/bin/env bash
set -Eeuo pipefail

UPDATE_PACKAGE_INDEX=1
if [[ "${1:-}" == --no-update ]]; then
  UPDATE_PACKAGE_INDEX=0
  shift
fi

(( $# > 0 )) || {
  echo "用法：$0 [--no-update] <软件包名或本地 DEB> [...]" >&2
  exit 1
}

# 公共下载、解析和基础文件处理入口统一需要这些命令，应用脚本不重复声明。
BASE_PACKAGES=(ca-certificates coreutils curl file findutils gawk grep jq sed xz-utils)

# 根据当前权限选择 apt-get 调用方式，root 环境不经过 sudo。
if ((EUID == 0)); then
  APT=(apt-get)
elif command -v sudo >/dev/null 2>&1; then
  APT=(sudo apt-get)
else
  echo "错误：安装软件包需要 root 或 sudo。" >&2
  exit 1
fi

# 同一构建后续安装本地 DEB 时可跳过已经完成的软件源索引更新。
if ((UPDATE_PACKAGE_INDEX)); then
  "${APT[@]}" update
fi

DEBIAN_FRONTEND=noninteractive "${APT[@]}" install -y --no-install-recommends "${BASE_PACKAGES[@]}" "$@"
