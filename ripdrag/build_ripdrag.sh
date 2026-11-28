#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" --base
# 安装官方软件包及运行依赖。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" glycin gtk4 librsvg rust xorg-server xorg-server-common xorg-server-xvfb

# 清掉上次的打包目录。
"$SCRIPT_DIR/../Common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir dist source


# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 本程序专属处理：使用仓库中已有的图标。
export ICON="$SCRIPT_DIR/resources/ripdrag.svg"
# 本程序专属处理：使用并校验仓库中已有的桌面入口。
export DESKTOP="$SCRIPT_DIR/resources/ripdrag.desktop"
desktop-file-validate "$DESKTOP"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME="ripdrag.AppImage"
# 包里的真实程序名。
export MAIN_BIN=ripdrag
# 本程序专属处理：打包时部署 GTK4 运行组件。
export DEPLOY_GTK=1
# 本程序专属处理：打包时部署 GdkPixbuf 图像加载组件。
export DEPLOY_GDK=1
# 本程序专属处理：打包时部署 Glycin 图片加载器。
export DEPLOY_GLYCIN=1

# 本程序专属处理：从 crates.io 安装当前版本到本次构建目录。
"$SCRIPT_DIR/../Common/build/install_cargo_crate.sh" ripdrag "$SCRIPT_DIR/source"
RIPDRAG_BIN="$SCRIPT_DIR/source/bin/ripdrag"

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../Common/build/read_app_version.sh" command "$RIPDRAG_BIN" --field 2 -- --version)"

# 收集程序及其运行依赖。
quick-sharun "$RIPDRAG_BIN"

# 本程序专属处理：将现有深色主题 Hook 放入 AppDir。
install -m 0755 -- "$SCRIPT_DIR/00-ripdrag-dark-theme.hook" AppDir/bin/00-ripdrag-dark-theme.hook

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../Common/build/save_appimage_version.sh" "dist/ripdrag.AppImage" "$VERSION" dist/version.txt
