#!/usr/bin/env bash
set -Eeuo pipefail

###### 定位源码与补丁 ######
# 定位本脚本附带的补丁目录。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 仅接收本次构建解压出的上游源码目录。
if [[ $# -ne 1 || ! -f "$1/src/icon.c" ]]; then
  echo "错误：请传入包含 src/icon.c 的 alttab 源码目录。" >&2
  exit 1
fi

# 将源码目录转为绝对路径，避免 patch 切换目录后产生路径歧义。
SOURCE_DIR="$(cd -- "$1" && pwd)"

###### 应用补丁 ######
# 保留原有补丁参数；重复应用或上下文不匹配时直接失败。
patch --batch --forward --fuzz=0 -d "$SOURCE_DIR" -p1 < "$SCRIPT_DIR/patches/desktop-icons.patch"

# 泛化回退：宿主图标查找失败时，从目标窗口所属 AppImage 的运行时 APPDIR 读取内嵌图标，不匹配具体应用名称。
patch --batch --forward --fuzz=0 -d "$SOURCE_DIR" -p1 < "$SCRIPT_DIR/patches/appimage-icons.patch"

# 字体回退：主字体缺少中文字形时使用 WenQuanYi Zen Hei Mono，不改动已有图标补丁及其应用顺序。
patch --batch --forward --fuzz=0 -d "$SOURCE_DIR" -p1 < "$SCRIPT_DIR/patches/font-fallback.patch"
