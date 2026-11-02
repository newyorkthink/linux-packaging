#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 调用统一的钉钉构建入口，依赖、来源和封装均由应用 build 负责。
exec bash "$SCRIPT_DIR/../../dingtalk/build_dingtalk.sh"
