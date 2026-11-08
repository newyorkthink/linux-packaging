#!/usr/bin/env bash

############# 初始化脚本 #############

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 安装统一的 Arch AppImage 基础包
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base

trap 'rc=$?; echo "::error file=build_kitty.sh,line=${LINENO}::命令失败（退出码 ${rc}）：${BASH_COMMAND}" >&2; exit "$rc"' ERR

cd "$(dirname "$0")"

# 本程序专属处理：保持现有 x86_64 构建架构和无需 FUSE 的工具执行方式。
export ARCH=x86_64
export APPIMAGE_EXTRACT_AND_RUN=1

############# 准备构建目录 #############

ROOT="$PWD"
APPDIR="$ROOT/AppDir"
OUTDIR="$ROOT/dist"
OUTFILE="$OUTDIR/kitty.AppImage"
KITTY_DIR="$APPDIR/usr/lib/kitty.app"

# 本程序专属处理：清理并重建本应用的打包目录，移除上次的同名产物。
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/lib" "$OUTDIR"
rm -f "$OUTFILE" "$OUTFILE.zsync"

############# 准备构建环境 #############

# 安装构建工具和应用所需的依赖包。
"$SCRIPT_DIR/../common/arch/install_packages.sh" ca-certificates curl file kitty-terminfo libxcb ncurses squashfs-tools tar xz zsync

############ 下载并准备应用 #############

# 本程序专属处理：通过公共入口获取 Kitty 最新正式版预编译包对应的版本。
KITTY_RELEASE_VERSION="$("$SCRIPT_DIR/../common/github/resolve_latest_stable_release_asset.sh" kovidgoyal/kitty 'kitty-{version}-x86_64.txz' | sed -n '1p')"

# 本程序专属处理：通过公共脚本下载并校验 Kitty 官方预编译包。
"$SCRIPT_DIR/../common/github/download_latest_stable_named_asset.sh" kovidgoyal/kitty "kitty-${KITTY_RELEASE_VERSION}-x86_64.txz" /tmp/kitty.txz

# 本程序专属处理：通过公共归档入口解压预编译包，保留原有目录结构。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" /tmp/kitty.txz "$KITTY_DIR"

# 读取本次打包使用的版本。
KITTY_VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" command "$KITTY_DIR/bin/kitty" --field 2 -- --version)"

########## 准备桌面资源和运行库 #########

# 本程序专属处理：准备程序专属的运行库、terminfo、桌面入口和图标。
"$SCRIPT_DIR/patches/prepare_appdir.sh" "$APPDIR"

############# 准备 AppRun ##############

# 本程序专属处理：安装独立保存的启动脚本，保持原有运行逻辑。
cp "$SCRIPT_DIR/AppRun" "$APPDIR/AppRun"

# 为启动脚本添加执行权限。
chmod +x "$APPDIR/AppRun"

############# 下载打包工具 #############

# 下载并校验最终封装工具及运行时，并设置执行权限。
"$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" --appimagetool /tmp/appimagetool /tmp/runtime-x86_64

############### 整理产物 ###############

# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" /tmp/appimagetool "$APPDIR" "$OUTFILE" /tmp/runtime-x86_64 "$KITTY_VERSION"
