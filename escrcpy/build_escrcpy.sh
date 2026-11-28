#!/usr/bin/env bash

############# 初始化脚本 #############

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 安装统一的 Arch AppImage 基础包
"$SCRIPT_DIR/../Common/arch/install_packages.sh" --base

############# 准备构建目录 #############

# 设置构建目录、发布产物和来源版本文件的路径。
SOURCE_DIR="$SCRIPT_DIR/source"
DIST_DIR="$SCRIPT_DIR/dist"
OUTFILE="$DIST_DIR/escrcpy.AppImage"
SOURCE_VERSION_FILE="$SOURCE_DIR/version.txt"

# 清理上次的下载目录和产物目录，并重建下载目录。
"$SCRIPT_DIR/../Common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create dist source

############ 下载并准备应用 #############

# 本程序专属处理：通过公共 GitHub 入口解析最新稳定 Release，下载并校验官方 x86_64 AppImage 后原样保存。
"$SCRIPT_DIR/../Common/github/download_latest_stable_release_asset.sh" --tag-prefix "v" "viarotel-org/escrcpy" 'regex:Escrcpy-{version}-linux-x86_64[.]AppImage' "$OUTFILE" > "$SOURCE_VERSION_FILE"

############### 整理产物 ###############

# 读取本次下载记录的来源版本。
VERSION="$("$SCRIPT_DIR/../Common/build/read_app_version.sh" text "$SOURCE_VERSION_FILE")"

# 设置产物执行权限，并写入发布流程读取的版本文件。
"$SCRIPT_DIR/../Common/build/save_appimage_version.sh" "$OUTFILE" "$VERSION" "$DIST_DIR/version.txt"
