#!/usr/bin/env bash
# 从 siduck/st 默认分支的当前提交构建独立的 st AppImage。
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

# 安装统一的 Arch AppImage 基础包
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
ROOT="$(dirname -- "$SCRIPT_DIR")"
cd "$SCRIPT_DIR"
source "$SCRIPT_DIR/font-config.sh"

rm -rf "$SCRIPT_DIR/AppDir" "$SCRIPT_DIR/dist" "$SCRIPT_DIR/.build"
mkdir -p "$SCRIPT_DIR/.build" "$SCRIPT_DIR/dist"

export ARCH="$(uname -m)"
export ICON=/usr/share/pixmaps/st.png
export DESKTOP=/usr/share/applications/st.desktop
export MAIN_BIN=st
export OUTPATH="$SCRIPT_DIR/dist"
export OUTNAME=st.AppImage

yay -S --noconfirm base-devel curl jq tar gzip python fontconfig \
  libx11 libxft libxext freetype2 harfbuzz glib2 gd ncurses \
  wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux zsync

COMMIT="$("$ROOT/common/github/download_default_branch_source.sh" \
  siduck/st "$SCRIPT_DIR/.build/st.tar.gz")"
"$ROOT/common/archive/extract_archive.sh" "$SCRIPT_DIR/.build/st.tar.gz" "$SCRIPT_DIR/.build"
SOURCE_DIR="$SCRIPT_DIR/.build/st-$COMMIT"
test -s "$SOURCE_DIR/config.def.h"
test -s "$SOURCE_DIR/st.info"

# 只生成本次构建的 config.h，不修改上游 config.def.h。
export ST_FONT_PRIMARY ST_FONT_FALLBACKS ST_FONT_PIXELS SOURCE_DIR
python - <<'PY'
import json
import os
import pathlib
import re

source = pathlib.Path(os.environ["SOURCE_DIR"])
content = (source / "config.def.h").read_text()
primary = os.environ["ST_FONT_PRIMARY"].strip()
fallbacks = [name.strip() for name in os.environ["ST_FONT_FALLBACKS"].split(",") if name.strip()]
pixels = int(os.environ["ST_FONT_PIXELS"])
if not primary or not fallbacks or pixels <= 0:
    raise SystemExit("错误：font-config.sh 中的字体配置无效")
def pattern(name):
    return json.dumps(f"{name}:pixelsize={pixels}:antialias=true:autohint=true")
content, n = re.subn(r'^static char \*font = .*;$',
                     lambda _: f"static char *font = {pattern(primary)};",
                     content, flags=re.MULTILINE)
if n != 1:
    raise SystemExit("错误：上游 font 字段已变更")
content, n = re.subn(r'^static char \*font2\[\] = .*;$',
                     lambda _: "static char *font2[] = { " +
                     ", ".join(map(pattern, fallbacks)) + " };",
                     content, flags=re.MULTILINE)
if n != 1:
    raise SystemExit("错误：上游 font2 字段已变更")
(source / "config.h").write_text(content)
PY

make -C "$SOURCE_DIR" PREFIX=/usr install
test -s "$ICON"
test -s "$DESKTOP"
quick-sharun /usr/bin/st
# 上游的快捷键会调用两个 shell 脚本，放在随包 PATH 中。
mkdir -p "$SCRIPT_DIR/AppDir/bin"
cp -a /usr/bin/st-copyout /usr/bin/st-urlhandler "$SCRIPT_DIR/AppDir/bin/"

# st 的 TERM 为 st-256color，随程序封装自己的 terminfo。
mkdir -p "$SCRIPT_DIR/AppDir/share/terminfo" "$SCRIPT_DIR/AppDir/share/licenses/st"
tic -sx -o "$SCRIPT_DIR/AppDir/share/terminfo" "$SOURCE_DIR/st.info"
cp "$SOURCE_DIR/LICENSE" "$SCRIPT_DIR/AppDir/share/licenses/st/LICENSE"

quick-sharun --make-appimage
test -s "$SCRIPT_DIR/dist/st.AppImage"
ST_VERSION="$(awk '$1 == "VERSION" && $2 == "=" {print $3; exit}' "$SOURCE_DIR/config.mk")"
test -n "$ST_VERSION"
printf '%s+g%.12s\n' "$ST_VERSION" "$COMMIT" > "$SCRIPT_DIR/dist/version.txt"
