#!/usr/bin/env bash

BUILD_ROOT="$1"
APPIMAGE_BASENAME="$2"

# 当前 linuxdeploy 公共工具链固定使用 x86_64 资产，架构检查统一在工作区入口完成。
[[ "$(uname -m)" == x86_64 ]] || {
  echo "错误：当前 linuxdeploy 公共流程仅支持 x86_64。" >&2
  return 1
}

cd "$BUILD_ROOT"

SOURCE_DIR="$BUILD_ROOT/source"
APPDIR="$BUILD_ROOT/AppDir"
DIST_DIR="$BUILD_ROOT/dist"
TOOLS_DIR="$SOURCE_DIR/tools"
OUTFILE="$DIST_DIR/$APPIMAGE_BASENAME.AppImage"
APPIMAGETOOL="$TOOLS_DIR/appimagetool-x86_64.AppImage"
RUNTIME_FILE="$TOOLS_DIR/runtime-x86_64"
INTERMEDIATE_APPIMAGE="$SOURCE_DIR/$APPIMAGE_BASENAME-linuxdeploy-intermediate.AppImage"

rm -rf "$SOURCE_DIR" "$APPDIR" "$DIST_DIR"
mkdir -p "$TOOLS_DIR" "$DIST_DIR"

unset BUILD_ROOT APPIMAGE_BASENAME
