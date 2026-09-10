#!/bin/bash
set -e

# 测试版：丢弃外层启动器继承进来的 LD_PRELOAD，只加载 JRiver 自己的文件选择器兼容库。
export JRIVER_FILECHOOSER_SAVED_PRELOAD=""

# 只在即将启动的 JRiver 主进程中加载测试版空目录兼容库。
export LD_PRELOAD="/usr/local/lib/jriver/filechooser-empty-path_test.so"

# 启动未修改的上游 JRiver，完整传递文件名和其他参数。
exec /usr/bin/mediacenter36 "$@"
