#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" --base
# 安装官方软件包及运行依赖。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" "mission-center" fcitx5-gtk

# 清掉上次的打包目录。
"$SCRIPT_DIR/../Common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir dist


# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 使用系统里装好的图标。
export ICON="/usr/share/icons/hicolor/scalable/apps/io.missioncenter.MissionCenter.svg"
# 使用系统里装好的桌面入口文件。
export DESKTOP="/usr/share/applications/io.missioncenter.MissionCenter.desktop"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME="mission-center.AppImage"
# 本程序专属处理：显式启用 GTK4 部署。
export DEPLOY_GTK=1
# 本程序专属处理：指定 GTK4 模块目录名。
export GTK_DIR=gtk-4.0
# 本程序专属处理：显式保留应用及 GTK4 / Libadwaita 翻译资源。
export DEPLOY_LOCALE=1

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../Common/build/read_app_version.sh" pacman "mission-center")"

# 收集程序及其运行依赖。
quick-sharun /usr/bin/missioncenter /usr/bin/missioncenter-magpie

# 本仓库兼容处理：为 GTK 4 输入模块目录写入 Fcitx5 的 GIO 模块注册缓存。
im_mod="$(find AppDir -type f -name 'libim-fcitx5.so' -print -quit)"
[[ -n "$im_mod" ]] || { echo "错误：AppDir 中缺少 GTK4 Fcitx5 输入模块。" >&2; exit 1; }
printf '%s\n' 'libim-fcitx5.so: gtk-im-module' > "$(dirname "$im_mod")/giomodule.cache"

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
ENV

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../Common/build/save_appimage_version.sh" "dist/mission-center.AppImage" "$VERSION" dist/version.txt
