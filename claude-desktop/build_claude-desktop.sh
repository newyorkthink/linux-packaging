#!/usr/bin/env bash
# 将 AUR claude-desktop 引用的 Anthropic 官方 Linux 包封装为 AppImage。
set -Eeuo pipefail

###### 准备构建环境 ######

# 所有构建路径均基于脚本目录。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
cd "$SCRIPT_DIR"

# 当前正式 Job 使用 x86_64 Arch Linux 容器。
ARCH="$(uname -m)"
export ARCH
if [[ "$ARCH" != x86_64 ]]; then
  printf '错误：当前构建只支持 x86_64。\n' >&2
  exit 1
fi

# 安装仓库规定的最小基础工具。
yay -S --noconfirm base-devel git wget curl jq binutils patchelf file coreutils findutils \
  grep sed gawk tar gzip xz unzip rsync util-linux appstream-glib \
  desktop-file-utils zsync ca-certificates

###### 安装官方应用 ######

# 跟随当前 AUR 包版本，由 makepkg 校验官方 DEB 的 SHA-256 并安装真实依赖。
yay -S --noconfirm claude-desktop

# 从实际安装结果读取版本和官方桌面入口，不写死应用版本。
VERSION="$(pacman -Q claude-desktop | awk '{print $2}')"
export VERSION
mapfile -t desktop_files < <(
  pacman -Qlq claude-desktop | awk '/^\/usr\/share\/applications\/[^/]+\.desktop$/'
)
if [[ -z "$VERSION" || ${#desktop_files[@]} -ne 1 ]]; then
  printf '错误：无法确定 Claude Desktop 版本或唯一桌面入口。\n' >&2
  exit 1
fi

# 保留标准入口与官方资源的实际对应关系。
APP_ROOT="$(dirname -- "$(readlink -f /usr/bin/claude-desktop)")"
readonly APP_ROOT
if [[ "$APP_ROOT" != /usr/lib/claude-desktop || ! -x /usr/bin/claude-desktop \
   || ! -s "$APP_ROOT/resources/app.asar" ]]; then
  printf '错误：Claude Desktop 的上游安装布局已改变。\n' >&2
  exit 1
fi

###### 核心打包 ######

# 仅清理本应用在临时 CI 容器中的构建目录。
rm -rf -- "$SCRIPT_DIR/AppDir" "$SCRIPT_DIR/dist"

# 使用官方 desktop 和图标；入口名称由 desktop 自动解析。
export DESKTOP="${desktop_files[0]}"
export ICON=/usr/share/icons/hicolor/256x256/apps/claude-desktop.png
export OUTPATH="$SCRIPT_DIR/dist"
export OUTNAME=claude-desktop.AppImage

# 官方 Electron 二进制不做 strip；依赖部署不启动应用。
export NO_STRIP=1
export STRACE_MODE=0

# 先从标准 /usr/bin 入口收集依赖并生成 sharun 启动入口。
quick-sharun /usr/bin/claude-desktop

# 标准入口是 ELF 软链接；单独收集 ELF 不会复制其旁边的 Electron 资源。
# 在依赖部署后补齐官方资源，保留生成的主入口，不把 setuid helper 带入便携包。
rsync -a --exclude=/claude-desktop --exclude=/chrome-sandbox \
  "$APP_ROOT/" "$SCRIPT_DIR/AppDir/bin/"

# 同时让真实 ELF 所在目录可按原相对路径找到资源；不覆盖已部署的 ELF。
for app_file in "$SCRIPT_DIR/AppDir/bin/"*; do
  app_name="${app_file##*/}"
  if [[ ! -e "$SCRIPT_DIR/AppDir/shared/bin/$app_name" \
     && ! -L "$SCRIPT_DIR/AppDir/shared/bin/$app_name" ]]; then
    ln -s "../../bin/$app_name" "$SCRIPT_DIR/AppDir/shared/bin/$app_name"
  fi
done

# 保留上游许可证说明。
install -Dm644 /usr/share/doc/claude-desktop/copyright \
  "$SCRIPT_DIR/AppDir/share/doc/claude-desktop/copyright"

###### 整理产物 ######

# 由 quick-sharun 生成唯一正式 AppImage，公共 action 负责上传 latest Release。
quick-sharun --make-appimage
