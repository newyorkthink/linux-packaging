#!/usr/bin/env bash
# 将 AUR 当前稳定 Stacer（官方源码、Qt6）打包为 AnyLinux AppImage。
# 不使用官方 jammy AppImage：其 go-appimage deploy 会打入构建环境的旧 glibc。
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 安装统一的 Arch AppImage 基础包
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
readonly SCRIPT_DIR
cd "$SCRIPT_DIR"

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

###### 准备构建环境 ######

APPDIR="$SCRIPT_DIR/AppDir"
DIST_DIR="$SCRIPT_DIR/dist"
OUTFILE="$DIST_DIR/stacer.AppImage"

# 只清理本目录构建产物，避免影响仓库其他应用。
rm -rf "$APPDIR" "$DIST_DIR"
mkdir -p "$DIST_DIR"

ARCH="$(uname -m)"
export ARCH
[[ "$ARCH" == x86_64 ]] || die "当前仅支持 x86_64，检测到：$ARCH"

export STARTUPWMCLASS=stacer
export ICON=/usr/share/icons/hicolor/scalable/apps/stacer.svg
export DESKTOP=/usr/share/applications/stacer.desktop
export OUTPATH="$DIST_DIR"
export OUTNAME="$(basename "$OUTFILE")"

# 安装 quick-sharun / AppImage 打包所需的最小基础工具。
yay -S --noconfirm base-devel git wget curl jq binutils patchelf file coreutils findutils \
  grep sed gawk tar gzip xz unzip rsync util-linux appstream-glib \
  desktop-file-utils zsync ca-certificates

###### 安装 Stacer 与同主版本 Qt6 输入上下文 ######

# AUR stacer 从 QuentiumYT/Stacer 官方源码编译，并按包依赖拉入 qt6-base / qt6-charts / qt6-svg。
yay -S --noconfirm stacer

# Stacer 是 Qt6 GUI。按仓库 Qt 主版本一致规则，补入同一主版本的 Fcitx5 输入上下文插件。
yay -S --noconfirm fcitx5-qt

command -v stacer >/dev/null 2>&1 || die "AUR stacer 安装后找不到 /usr/bin/stacer。"
[[ -s "$ICON" ]] || die "缺少 Stacer 图标：$ICON"
[[ -s "$DESKTOP" ]] || die "缺少 Stacer desktop 文件：$DESKTOP"
[[ -d /usr/share/stacer/translations ]] || die "缺少 Stacer 翻译目录：/usr/share/stacer/translations"

STACER_PACKAGE_VERSION="$(pacman -Q stacer | awk '{print $2}')"
STACER_VERSION="${STACER_PACKAGE_VERSION#*:}"
STACER_VERSION="${STACER_VERSION%-*}"
[[ -n "$STACER_VERSION" ]] || die "无法解析 Stacer 版本。"

###### 核心打包 ######

# 同时收集 /usr/share/stacer，避免只封装 ELF 后丢失翻译。
quick-sharun /usr/bin/stacer /usr/share/stacer

# 上游按以下顺序查找翻译：
# 1. 宿主 /usr/share/stacer/translations
# 2. Flatpak /app/share/stacer/translations
# 3. applicationDirPath()/translations
# AppImage 内 1/2 通常不存在，因此把随包翻译链接到主程序同级目录。
if [[ -d "$APPDIR/share/stacer/translations" ]]; then
  mkdir -p "$APPDIR/bin"
  ln -sfn ../share/stacer/translations "$APPDIR/bin/translations"
  if [[ -d "$APPDIR/shared/bin" ]]; then
    ln -sfn ../../share/stacer/translations "$APPDIR/shared/bin/translations"
  fi
else
  die "quick-sharun 未把 Stacer 翻译目录收集进 AppDir。"
fi

quick-sharun --make-appimage

###### 整理产物 ######

[[ -s "$OUTFILE" ]] || die "未生成 $OUTFILE"
printf '%s\n' "$STACER_VERSION" > "$DIST_DIR/version.txt"
printf '已生成：%s（版本 %s）\n' "$OUTFILE" "$STACER_VERSION"
