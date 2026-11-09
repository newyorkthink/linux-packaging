#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base

# 本程序专属处理：清理旧产物，保留仓库已有的图标与 PATH hook。
rm -rf -- dist platform-tools bin.zip AppDir/etc
if [[ -d AppDir/bin ]]; then
  find AppDir/bin -mindepth 1 ! -name 'make-symlinks-in-path.hook' -delete
fi
mkdir -p AppDir/bin dist

# 本程序专属处理：使用 GitHub Actions 的 pkgforge Arch Linux 构建容器内置工具，
# 精简构建环境中的软件包，排除 Mesa 和 Vulkan。
get-debloated-pkgs --add-common --prefer-nano ! mesa ! vulkan

# 本程序专属处理：精简后重新安装 quick-sharun 所需的基础包。
# 必须放在 get-debloated-pkgs 之后：该步骤会卸掉 unzip / patchelf，
# Actions 已分别报过 `unzip: command not found` 和 `Missing dependency 'patchelf'`。
yay -S --noconfirm base-devel git wget curl jq binutils patchelf file coreutils findutils \
  grep sed gawk tar gzip xz unzip rsync util-linux appstream-glib \
  desktop-file-utils zsync ca-certificates

# 本程序专属处理：下载 Google 官方最新 Linux Platform Tools。
"$SCRIPT_DIR/../common/download/download_file.sh" "https://dl.google.com/android/repository/platform-tools-latest-linux.zip" bin.zip

# 本程序专属处理：解压官方 ZIP，保留完整的平台工具。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" bin.zip "$SCRIPT_DIR"
rm -f -- bin.zip
mv -v ./platform-tools/* ./AppDir/bin/
rmdir ./platform-tools

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 保留原有的应用名称。
export APPNAME=android-tools
# 保留原有的主程序入口。
export MAIN_BIN=adb
# 保留原有的桌面入口设置。
export DESKTOP=DUMMY
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME=android-tools.AppImage
# 本程序专属处理：保留原有的 AppImage 更新信息。
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|android-tools.AppImage.zsync"

# 本程序专属处理：从官方 source.properties 读取平台工具版本。
VERSION="$(awk -F'=' '/Revision/ {gsub(/\r/, "", $2); gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit}' ./AppDir/bin/source.properties)"
[[ -n "$VERSION" ]] || {
  echo "错误：无法从 source.properties 解析 platform-tools 版本。" >&2
  exit 1
}

# 收集程序及其运行依赖。
quick-sharun ./AppDir/bin/*

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" dist/android-tools.AppImage "$VERSION" dist/version.txt
