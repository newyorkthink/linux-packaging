#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

###### 准备构建环境 ######

# 只清理上次构建残留的平台工具和产物，保留仓库内的图标与 hook。
rm -rf dist platform-tools bin.zip AppDir/etc
if [[ -d AppDir/bin ]]; then
  find AppDir/bin -mindepth 1 ! -name 'make-symlinks-in-path.hook' -delete
fi
mkdir -p AppDir/bin dist

ARCH="$(uname -m)"
export ARCH
export OUTPATH=./dist
export OUTNAME="android-tools.AppImage"
export APPNAME="android-tools"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|android-tools.AppImage.zsync"
export DESKTOP=DUMMY
export MAIN_BIN=adb

# 沿用源仓库已验证的精简包流程，排除无关的 Mesa / Vulkan。
get-debloated-pkgs --add-common --prefer-nano ! mesa ! vulkan

# 安装 AGENTS.md 规定的 quick-sharun 最小基础包。
# 必须放在 get-debloated-pkgs 之后：该步骤会卸掉 unzip / patchelf，
# Actions 已分别报过 `unzip: command not found` 和 `Missing dependency 'patchelf'`。
yay -S --noconfirm base-devel git wget curl jq binutils patchelf file coreutils findutils \
  grep sed gawk tar gzip xz unzip rsync util-linux appstream-glib \
  desktop-file-utils zsync ca-certificates

###### 下载上游文件 ######

# 始终获取 Google 官方当前 latest Linux platform-tools，不锁定版本号。
BINARY_SOURCE="https://dl.google.com/android/repository/platform-tools-latest-linux.zip"
wget --retry-connrefused --tries=30 "$BINARY_SOURCE" -O ./bin.zip
unzip -q ./bin.zip
rm -f ./bin.zip
mv -v ./platform-tools/* ./AppDir/bin
rmdir ./platform-tools

VERSION="$(awk -F'=' '/Revision/ {gsub(/\r/, "", $2); gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit}' ./AppDir/bin/source.properties)"
[[ -n "$VERSION" ]] || {
  echo "错误：无法从 source.properties 解析 platform-tools 版本。" >&2
  exit 1
}

###### 核心打包 ######

# 按源仓库方式收集 AppDir/bin 中的全部平台工具与 hook。
quick-sharun ./AppDir/bin/*

quick-sharun --make-appimage

###### 整理产物 ######

test -s ./dist/android-tools.AppImage
printf '%s\n' "$VERSION" > ./dist/version.txt
