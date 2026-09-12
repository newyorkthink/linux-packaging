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

# 字体回退：保留 MonoLisa 主字体，主字体缺字时依次尝试中文、通用符号和 Nerd Font 备用字体。
patch --batch --forward --fuzz=0 -d "$SOURCE_DIR" -p1 < "$SCRIPT_DIR/patches/font-fallback.patch"

# 字形与排版补充：固定备用字体仍缺字时交给 Fontconfig 按字符匹配宿主字体，并增大多行标题行距。
patch --batch --forward --fuzz=0 -d "$SOURCE_DIR" -p1 < "$SCRIPT_DIR/patches/glyph-layout.patch"
