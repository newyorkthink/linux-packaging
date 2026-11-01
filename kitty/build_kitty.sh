#!/usr/bin/env bash
set -Eeuo pipefail

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
yay -S --needed --noconfirm \
  ca-certificates \
  curl \
  file \
  kitty-terminfo \
  libxcb \
  ncurses \
  squashfs-tools \
  tar \
  xz \
  zsync

# 使用 kitty 官方预编译包，并保持 bin、lib、share 的相对目录不变。
curl -fL --retry 3 \
  https://sw.kovidgoyal.net/kitty/installer.sh \
  -o /tmp/kitty-installer.sh

sh /tmp/kitty-installer.sh \
  dest="$APPDIR/usr/lib" \
  launch=n

# kitten 是独立的软链接入口，保留这项检查，避免生成缺少该入口的产物。
test -x "$KITTY_DIR/bin/kitten"

# 从本次官方程序读取版本，并保留版本格式校验。
KITTY_VERSION_OUTPUT="$("$KITTY_DIR/bin/kitty" --version)"
KITTY_VERSION="$(awk '{print $2; exit}' <<< "$KITTY_VERSION_OUTPUT")"
if [[ ! "$KITTY_VERSION" =~ ^[0-9]+([.][0-9]+)+([.+-][0-9A-Za-z.-]+)?$ ]]; then
  echo "错误：无法从 kitty --version 解析版本：$KITTY_VERSION_OUTPUT" >&2
  exit 1
fi

# 准备程序专属的运行库、terminfo、桌面入口和图标。
"$SCRIPT_DIR/patches/prepare_appdir.sh" "$APPDIR"

# 安装独立保存的启动脚本，保持原有运行逻辑。
cp "$SCRIPT_DIR/AppRun" "$APPDIR/AppRun"
chmod +x "$APPDIR/AppRun"

# 下载当前官方 appimagetool，保留原有 continuous 来源。
curl -fL --retry 3 \
  https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage \
  -o /tmp/appimagetool

# 下载当前官方 Type 2 runtime，保留原有 continuous 来源。
curl -fL --retry 3 \
  https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-x86_64 \
  -o /tmp/runtime-x86_64

# 为实际执行的打包工具添加执行权限。
chmod +x /tmp/appimagetool /tmp/runtime-x86_64

# 沿用原封装命令，使用官方 appimagetool 和 Type 2 runtime 生成 AppImage。
APPIMAGE_EXTRACT_AND_RUN=1 \
  /tmp/appimagetool -n \
  --runtime-file /tmp/runtime-x86_64 \
  "$APPDIR" \
  "$OUTFILE"

# 最终 AppImage 非空时才保存本次实际打包的版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" "$OUTFILE" "$KITTY_VERSION" "$OUTDIR/version.txt"

echo "已生成：$OUTFILE"
