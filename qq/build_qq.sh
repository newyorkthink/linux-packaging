#!/usr/bin/env bash

############# 初始化脚本 #############

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 安装统一的 Arch AppImage 基础包
"$SCRIPT_DIR/../Common/arch/install_packages.sh" --base

# 加载公共 AUR 下载入口。
source "$SCRIPT_DIR/../Common/aur/download_pkgbuild_asset.sh"

############# 准备构建目录 #############

# 设置构建目录、发布产物和来源版本文件的路径。
SOURCE_DIR="$SCRIPT_DIR/source"
DIST_DIR="$SCRIPT_DIR/dist"
OUTFILE="$DIST_DIR/qq.AppImage"
SOURCE_VERSION_FILE="$SOURCE_DIR/version.txt"

# 清理上次的下载目录和产物目录，并重建下载目录。
"$SCRIPT_DIR/../Common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create dist source

############ 下载并准备应用 #############

# 设置上游配方和下载签名接口的地址。
AUR_PKGBUILD_URL='https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=linuxqq-appimage'
QQ_SIGN_URL='https://im.qq.com/http2rpc/gotrpc/noauth/trpc.qqntv2.urlsign.UrlSign/GetSign'

# 从配方读取当前版本，通过公共入口取得签名地址并下载校验官方 AppImage。
download_pkgbuild_asset \
  "$AUR_PKGBUILD_URL" _image_url_x86_64 _image_sha256sums_x86_64 _version \
  "$OUTFILE" "$SOURCE_VERSION_FILE" \
  --url-regex '^https://qqdl\.gtimg\.cn/qqfile/QQNTV2/.+_x86_64_01\.AppImage$' \
  --version-regex 'QQ_([0-9]+\.[0-9]+\.[0-9]+)_([0-9]{6})_x86_64_01\.AppImage$' \
  --resolve-json-url 'https://im.qq.com' "$QQ_SIGN_URL" url data.url \
  --resolve-header 'x-oidb: {"uint32_command":"0x9b8e","uint32_service_type":1}'

############### 整理产物 ###############

# 读取本次下载记录的来源版本。
VERSION="$("$SCRIPT_DIR/../Common/build/read_app_version.sh" text "$SOURCE_VERSION_FILE")"

# 设置产物执行权限，并写入发布流程读取的版本文件。
"$SCRIPT_DIR/../Common/build/save_appimage_version.sh" "$OUTFILE" "$VERSION" "$DIST_DIR/version.txt"
