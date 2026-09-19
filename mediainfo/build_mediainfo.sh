#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

###### 准备构建环境 ######

rm -rf AppDir dist source
mkdir -p dist source

export ARCH="$(uname -m)"
[[ "$ARCH" == "x86_64" ]] || {
  echo "错误：当前仅支持 x86_64。" >&2
  exit 1
}

export OUTPATH="./dist"
export OUTNAME="mediainfo.AppImage"
export APPNAME="mediainfo"
export DESKTOP=DUMMY
export MAIN_BIN=mediainfo
export STARTUPWMCLASS=mediainfo

# 安装 quick-sharun / AppImage 打包所需的最小基础工具。
yay -S --noconfirm base-devel git wget curl jq binutils patchelf file coreutils findutils \
  grep sed gawk tar gzip xz unzip rsync util-linux appstream-glib \
  desktop-file-utils zsync ca-certificates

# 单独安装 Arch 官方 MediaInfo CLI 软件包，由包管理器拉入实际运行依赖。
yay -S --noconfirm mediainfo

# 从本次实际安装的软件包读取上游版本，去掉 Arch epoch / pkgrel。
MEDIAINFO_PACKAGE_VERSION="$(pacman -Q mediainfo | awk '{print $2}')"
MEDIAINFO_VERSION="${MEDIAINFO_PACKAGE_VERSION#*:}"
MEDIAINFO_VERSION="${MEDIAINFO_VERSION%-*}"
[[ -n "$MEDIAINFO_VERSION" ]] || {
  echo "错误：无法解析 MediaInfo 版本。" >&2
  exit 1
}

###### 下载官方资源 ######

# CLI 包不附带图标；从 MediaInfo 官方源码仓库获取品牌 SVG，供 AppImage 元数据使用。
curl -fL --retry 3 --retry-all-errors --connect-timeout 20 --max-time 120 \
  https://raw.githubusercontent.com/MediaArea/MediaInfo/master/Source/Resource/Image/MediaInfo.svg \
  -o "$SCRIPT_DIR/source/MediaInfo.svg"
[[ -s "$SCRIPT_DIR/source/MediaInfo.svg" ]] || {
  echo "错误：MediaInfo 官方图标下载为空。" >&2
  exit 1
}
grep -q '<svg' "$SCRIPT_DIR/source/MediaInfo.svg" || {
  echo "错误：MediaInfo 官方图标不是预期 SVG。" >&2
  exit 1
}
export ICON="$SCRIPT_DIR/source/MediaInfo.svg"

###### 核心打包 ######

# MediaInfo CLI 有标准 /usr/bin 入口，直接交给 quick-sharun 收集实际运行依赖。
quick-sharun /usr/bin/mediainfo

###### 整理产物 ######

quick-sharun --make-appimage

test -s ./dist/mediainfo.AppImage
printf '%s\n' "$MEDIAINFO_VERSION" > ./dist/version.txt
