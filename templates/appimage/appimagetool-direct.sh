#!/usr/bin/env bash

############# 初始化脚本 #############

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

############# 准备构建目录 #############

APPDIR="$SCRIPT_DIR/__PREPARED_APPDIR__"
OUTFILE="$SCRIPT_DIR/dist/__APP_NAME__.AppImage"
APPIMAGETOOL="$SCRIPT_DIR/.appimage-tools/appimagetool"
RUNTIME_FILE="$SCRIPT_DIR/.appimage-tools/runtime-x86_64"

# 创建打包工具和最终产物的输出目录。
mkdir -p "$SCRIPT_DIR/.appimage-tools" "$SCRIPT_DIR/dist"

############ 下载并准备应用 #############

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" command "$APPDIR/__MAIN_EXECUTABLE__" --field __VERSION_FIELD__ -- "__VERSION_OPTION__")"

############# 下载打包工具 #############

# 下载并校验最终封装工具及运行时，并设置执行权限。
"$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" --appimagetool "$APPIMAGETOOL" "$RUNTIME_FILE"

############### 整理产物 ###############

# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
