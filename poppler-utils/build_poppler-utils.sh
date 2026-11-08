#!/usr/bin/env bash

############# 初始化脚本 #############

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

############# 准备构建目录 #############

# 设置构建路径，并清理、重建当前应用的 source、AppDir 和 dist 目录。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" "poppler-utils"

############# 准备构建环境 #############

# 安装构建工具和应用所需的依赖包。
"$SCRIPT_DIR/../common/apt/install_packages.sh" poppler-utils poppler-data

############# 下载打包工具 #############

# 下载并校验打包工具及所需插件，随后加载构建环境配置。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" "" "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"

############ 初始化 AppDir #############

# 首次运行 linuxdeploy，创建 AppDir 的基础目录。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

############ 下载并准备应用 #############

# 下载已安装版本的软件包并解包到 AppDir，成功后返回版本号。
VERSION="$("$SCRIPT_DIR/../common/apt/extract_installed_package.sh" "poppler-utils" "$APPDIR" poppler-data)"

########## 准备桌面资源和运行库 #########

# 本程序专属处理：准备 Poppler 桌面入口和官方 PNG 图标的包内目录。
mkdir -p "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/256x256/apps"

# 本程序专属处理：通过公共下载入口获取 Poppler 官方 PNG 图标。
"$SCRIPT_DIR/../common/download/download_file.sh" "https://poppler.freedesktop.org/logo.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/poppler-utils.png"

# 本程序专属处理：为包含 13 个命令的 CLI 套件创建终端桌面入口。
cat > "$APPDIR/usr/share/applications/poppler-utils.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Poppler Utilities
Exec=pdftotext %F
Icon=poppler-utils
Terminal=true
Categories=Office;Utility;
EOF

############# 准备 AppRun ##############

# 在 AppDir 根目录创建完整的 AppRun 启动脚本。
# 本程序专属处理：沿用已验证的 13 个 Poppler 命令及 ARGV0 软链接分派入口。
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/bin/sh
set -eu

APPDIR="${APPDIR:-$(CDPATH= cd -P -- "$(dirname -- "$0")" && pwd)}"
export PATH="$APPDIR/usr/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$APPDIR/usr/lib:$APPDIR/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$APPDIR/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

tool="$(basename -- "${ARGV0:-${APPIMAGE:-$0}}")"
case "$tool" in
  pdfattach|pdfdetach|pdffonts|pdfimages|pdfinfo|pdfseparate|pdfsig|pdftocairo|pdftohtml|pdftoppm|pdftops|pdftotext|pdfunite) ;;
  *)
    case "${1-}" in
      pdfattach|pdfdetach|pdffonts|pdfimages|pdfinfo|pdfseparate|pdfsig|pdftocairo|pdftohtml|pdftoppm|pdftops|pdftotext|pdfunite)
        tool="$1"
        shift
        ;;
      *) tool=pdftotext ;;
    esac
    ;;
esac

exec "$APPDIR/usr/bin/$tool" "$@"
APPRUN

# 为启动脚本添加执行权限。
chmod +x "$APPDIR/AppRun"

############### 核心打包 ###############

# 再次运行 linuxdeploy，部署运行资源并生成中间 AppImage。
export ARCH=x86_64; linuxdeploy --appdir AppDir --output appimage

############### 整理产物 ###############

# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
