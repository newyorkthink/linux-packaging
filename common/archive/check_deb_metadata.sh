#!/usr/bin/env bash

# 命令失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 四个位置参数固定；空的预期值表示不核对该字段，至少指定一项。
if (( $# != 4 )) || [[ -z "${2:-}${3:-}${4:-}" ]]; then
  echo "用法：$0 <DEB 文件> <预期版本或空字符串> <预期包名或空字符串> <预期架构或空字符串>" >&2
  exit 2
fi
DEB_FILE="$1"
EXPECTED_VERSION="$2"
EXPECTED_PACKAGE="$3"
EXPECTED_ARCHITECTURE="$4"

# 转为绝对路径，使带空格或以连字符开头的相对文件名也能正确读取。
[[ "$DEB_FILE" == /* ]] || DEB_FILE="$PWD/$DEB_FILE"
[[ -n "$1" && -f "$DEB_FILE" ]] || {
  echo "错误：DEB 文件不存在或不是普通文件：$1" >&2
  exit 1
}

# 校验工具由构建环境提前提供，本入口不安装依赖。
command -v dpkg-deb >/dev/null 2>&1 || {
  echo "错误：校验 DEB 元数据需要 dpkg-deb。" >&2
  exit 1
}

# 只读取调用方指定的字段，按完整原值比较，不裁剪 epoch 或 Debian 修订号。
check_field() {
  local field="$1" expected="$2" actual
  [[ -n "$expected" ]] || return 0
  actual="$(dpkg-deb -f "$DEB_FILE" "$field")"
  if [[ "$actual" != "$expected" ]]; then
    echo "错误：DEB 的 $field 不符合预期：$actual / $expected（$DEB_FILE）" >&2
    exit 1
  fi
}

# 成功时不输出内容，不下载、安装、解包或修改 DEB。
check_field Version "$EXPECTED_VERSION"
check_field Package "$EXPECTED_PACKAGE"
check_field Architecture "$EXPECTED_ARCHITECTURE"
