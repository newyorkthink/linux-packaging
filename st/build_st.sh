#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装源码编译及运行依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" libx11 libxft libxext freetype2 harfbuzz gd ncurses

# 清掉上次的打包目录。
"$SCRIPT_DIR/../common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir work dist

# 下载上游默认分支的当前源码。
COMMIT="$("$SCRIPT_DIR/../common/github/download_default_branch_source.sh" siduck/st "$SCRIPT_DIR/work/st.tar.gz")"
"$SCRIPT_DIR/../common/archive/extract_archive.sh" "$SCRIPT_DIR/work/st.tar.gz" "$SCRIPT_DIR/work"
SOURCE_DIR="$SCRIPT_DIR/work/st-$COMMIT"

# 本程序专属处理：读取字体配置并生成本次构建的 config.h，不修改上游 config.def.h。
source "$SCRIPT_DIR/font-config.sh"
export ST_FONT_PRIMARY ST_FONT_FALLBACKS ST_FONT_PIXELS SOURCE_DIR
python "$SCRIPT_DIR/patches/apply_font_config.py"

# 本程序专属处理：应用源码默认赛博朋克主题，不修改原有字体配置。
source "$SCRIPT_DIR/patches/theme-config.sh"
export ST_THEME_COLORS ST_THEME_BACKGROUND ST_THEME_FOREGROUND ST_THEME_CURSOR ST_THEME_REVERSE_CURSOR ST_THEME_ALPHA
python "$SCRIPT_DIR/patches/apply_theme_config.py"

# 本程序专属处理：编译上游源码并安装程序及桌面资源。
make -C "$SOURCE_DIR" PREFIX=/usr install

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 使用系统里装好的图标。
export ICON=/usr/share/pixmaps/st.png
# 使用系统里装好的桌面入口文件。
export DESKTOP=/usr/share/applications/st.desktop
# 本程序专属处理：指定终端主程序。
export MAIN_BIN=st
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME=st.AppImage

# 收集程序及其运行依赖。
quick-sharun /usr/bin/st

# 本程序专属处理：封装上游快捷键调用的辅助脚本。
mkdir -p "$SCRIPT_DIR/AppDir/bin"
cp -a /usr/bin/st-copyout /usr/bin/st-urlhandler "$SCRIPT_DIR/AppDir/bin/"

# 本程序专属处理：封装 st-256color 的 terminfo 和许可证。
mkdir -p "$SCRIPT_DIR/AppDir/share/terminfo" "$SCRIPT_DIR/AppDir/share/licenses/st"
tic -sx -o "$SCRIPT_DIR/AppDir/share/terminfo" "$SOURCE_DIR/st.info"
cp "$SOURCE_DIR/LICENSE" "$SCRIPT_DIR/AppDir/share/licenses/st/LICENSE"

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 读取上游版本，并附加当前源码提交的短 SHA。
ST_VERSION="$(awk '$1 == "VERSION" && $2 == "=" && $3 != "" { print $3; found=1; exit } END { if (!found) exit 1 }' "$SOURCE_DIR/config.mk")"

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" dist/st.AppImage "${ST_VERSION}+g${COMMIT:0:12}" dist/version.txt
