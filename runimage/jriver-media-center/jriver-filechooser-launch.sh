#!/bin/bash
set -e

# 保存原有预加载配置，兼容库加载后立即恢复，供后续子进程继承。
export JRIVER_FILECHOOSER_SAVED_PRELOAD="${LD_PRELOAD-}"

# 只在即将启动的 JRiver 主进程中加入空目录兼容库。
export LD_PRELOAD="/usr/local/lib/jriver/filechooser-empty-path.so${LD_PRELOAD:+:$LD_PRELOAD}"

# 启动未修改的上游 JRiver，完整传递文件名和其他参数。
exec /usr/bin/mediacenter36 "$@"
