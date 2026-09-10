#!/bin/bash
set -e

# 丢弃外层启动器继承进来的 LD_PRELOAD，避免 Rofi、AppImage 或 RunImage 的预加载库污染 JRiver。
export JRIVER_FILECHOOSER_SAVED_PRELOAD=""

# 只在即将启动的 JRiver 主进程中加载空目录兼容库，不拼接外层 LD_PRELOAD。
export LD_PRELOAD="/usr/local/lib/jriver/filechooser-empty-path.so"

# 启动未修改的上游 JRiver，完整传递文件名和其他参数。
exec /usr/bin/mediacenter36 "$@"
