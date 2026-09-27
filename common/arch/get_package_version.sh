#!/usr/bin/env bash
set -Eeuo pipefail

# 从已安装的 Arch 软件包读取上游版本，去掉 epoch 和发行版 pkgrel。
if (( $# != 1 )) || [[ -z "$1" ]]; then
  echo "用法：$0 <Arch 软件包名>" >&2
  exit 2
fi

package="$1"
installed="$(pacman -Q -- "$package")"
[[ "$installed" == "$package "* ]] || {
  echo "无法解析已安装的软件包版本：$package" >&2
  exit 1
}

version="${installed#* }"
version="${version#*:}"
version="${version%-*}"
[[ -n "$version" && "$version" != *[[:space:]]* ]] || {
  echo "Arch 软件包版本为空或格式无效：$package" >&2
  exit 1
}
printf '%s\n' "$version"
