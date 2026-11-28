#!/usr/bin/env bash

############# 初始化脚本 #############

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 安装统一的 Arch AppImage 基础包
"$SCRIPT_DIR/../Common/arch/install_packages.sh" --base

############# 准备构建目录 #############

# 设置构建路径，并清理、重建当前应用的 source、AppDir 和 dist 目录。
source "$SCRIPT_DIR/../Common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" "rustdesk"

############ 下载并准备应用 #############

# 本程序专属处理：下载并校验 RustDesk 正式 Release 的官方 x86_64 AppImage，返回实际版本。
VERSION="$("$SCRIPT_DIR/../Common/github/download_latest_stable_release_asset.sh" rustdesk/rustdesk 'rustdesk-{version}-x86_64.AppImage' "$SOURCE_DIR/rustdesk-official.AppImage")"

# 本程序专属处理：解包官方 AppImage，保留 ELF AppRun 和原有运行目录。
"$SCRIPT_DIR/../Common/archive/extract_appimage.sh" "$SOURCE_DIR/rustdesk-official.AppImage" "$SOURCE_DIR/unpacked"
# 本程序专属处理：将完整的官方解包目录移到 AppDir。
mv -- "$SOURCE_DIR/unpacked/squashfs-root" "$APPDIR"

# 本程序专属处理：移除 AppRun.env 中已有的会话类型设置。
sed -i '/^XDG_SESSION_TYPE=/d' "$APPDIR/AppRun.env"
# 本程序专属处理：在 AppRun.env 中写入经实机确认的 X11 设置。
printf '%s\n' 'XDG_SESSION_TYPE=x11' >> "$APPDIR/AppRun.env"

############# 下载打包工具 #############

# 下载并校验最终封装工具及运行时，并设置执行权限。
"$SCRIPT_DIR/../Common/linuxdeploy/prepare_linuxdeploy_tools.sh" --appimagetool "$APPIMAGETOOL" "$RUNTIME_FILE"

############### 整理产物 ###############

# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../Common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
