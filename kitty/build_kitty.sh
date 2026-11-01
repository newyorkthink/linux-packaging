#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 安装统一的 Arch AppImage 基础包
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base

trap 'rc=$?; echo "::error file=build_kitty.sh,line=${LINENO}::命令失败（退出码 ${rc}）：${BASH_COMMAND}" >&2; exit "$rc"' ERR

cd "$(dirname "$0")"

# 保持现有 x86_64 构建架构和无需 FUSE 的工具执行方式。
export ARCH=x86_64
export APPIMAGE_EXTRACT_AND_RUN=1

ROOT="$PWD"
APPDIR="$ROOT/AppDir"
OUTDIR="$ROOT/dist"
OUTFILE="$OUTDIR/kitty.AppImage"
KITTY_DIR="$APPDIR/usr/lib/kitty.app"

# 清理并重建本应用的打包目录，移除上次的同名产物。
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/lib" "$OUTDIR"
rm -f "$OUTFILE" "$OUTFILE.zsync"

# 安装原有构建依赖和 kitty 运行资源。
"$SCRIPT_DIR/../common/arch/install_packages.sh" ca-certificates curl file kitty-terminfo libxcb ncurses squashfs-tools tar xz zsync

# 使用 kitty 官方预编译包，并保持 bin、lib、share 的相对目录不变。
"$SCRIPT_DIR/../common/download/download_file.sh" https://sw.kovidgoyal.net/kitty/installer.sh /tmp/kitty-installer.sh

sh /tmp/kitty-installer.sh \
  dest="$APPDIR/usr/lib" \
  launch=n

# kitten 是独立的软链接入口，保留这项检查，避免生成缺少该入口的产物。
test -x "$KITTY_DIR/bin/kitten"

# 读取本次打包使用的版本。
KITTY_VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" command "$KITTY_DIR/bin/kitty" --field 2 -- --version)"

# 准备程序专属的运行库、terminfo、桌面入口和图标。
"$SCRIPT_DIR/patches/prepare_appdir.sh" "$APPDIR"

# 安装独立保存的启动脚本，保持原有运行逻辑。
cp "$SCRIPT_DIR/AppRun" "$APPDIR/AppRun"
chmod +x "$APPDIR/AppRun"

# 下载并校验最终封装工具及运行时，并设置执行权限。
"$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" --appimagetool /tmp/appimagetool /tmp/runtime-x86_64

# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" /tmp/appimagetool "$APPDIR" "$OUTFILE" /tmp/runtime-x86_64 "$KITTY_VERSION"
