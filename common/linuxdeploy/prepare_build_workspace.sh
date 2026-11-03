#!/usr/bin/env bash

BUILD_ROOT="$1"
APPIMAGE_BASENAME="$2"

# 当前 linuxdeploy 公共工具链固定使用 x86_64 资产，架构检查统一在工作区入口完成。
[[ "$(uname -m)" == x86_64 ]] || {
  echo "错误：当前 linuxdeploy 公共流程仅支持 x86_64。" >&2
  return 1
}

cd "$BUILD_ROOT" || return 1
APPDIR="$BUILD_ROOT/AppDir"

# 直接封装使用已准备好的 AppDir，保留现有工作目录。
if (( $# == 4 )) && [[ "$3" == --prepared-appdir ]]; then
  BUILD_ROOT="$(pwd -P)" || return 1
  if [[ -z "$4" || "$4" == /* || "$BUILD_ROOT" == / ]]; then
    echo "错误：已准备的 AppDir 必须是构建根目录内的相对路径。" >&2
    return 1
  fi
  APPDIR="$(cd -- "$BUILD_ROOT/$4" && pwd -P)" || return 1
  if [[ "$APPDIR" != "$BUILD_ROOT/"* ]]; then
    echo "错误：已准备的 AppDir 必须位于构建根目录内。" >&2
    return 1
  fi
  SOURCE_DIR="$BUILD_ROOT/source"
# 临时模式只清理本次创建的源目录，并保留项目原有的 source 目录。
elif (( $# > 2 )); then
  if [[ $# != 3 || "$3" != --temporary-source ]]; then
    echo "用法：source ${BASH_SOURCE[0]} <构建根目录> <产物名> [--temporary-source | --prepared-appdir <相对路径>]" >&2
    return 1
  fi
  if [[ -n "$(trap -p EXIT)" ]]; then
    echo "错误：临时工作目录模式需要调用方保留 EXIT trap。" >&2
    return 1
  fi
  SOURCE_DIR="$(mktemp -d)" || return 1
  printf -v WORKSPACE_CLEANUP 'rm -rf -- %q' "$SOURCE_DIR"
  trap "$WORKSPACE_CLEANUP" EXIT
  unset WORKSPACE_CLEANUP
else
  SOURCE_DIR="$BUILD_ROOT/source"
fi
DIST_DIR="$BUILD_ROOT/dist"
TOOLS_DIR="$SOURCE_DIR/tools"
OUTFILE="$DIST_DIR/$APPIMAGE_BASENAME.AppImage"
APPIMAGETOOL="$TOOLS_DIR/appimagetool-x86_64.AppImage"
RUNTIME_FILE="$TOOLS_DIR/runtime-x86_64"
INTERMEDIATE_APPIMAGE="$SOURCE_DIR/$APPIMAGE_BASENAME-linuxdeploy-intermediate.AppImage"

if (( $# == 2 )); then
  rm -rf "$SOURCE_DIR" "$APPDIR" "$DIST_DIR"
elif (( $# == 3 )); then
  rm -rf "$APPDIR" "$DIST_DIR"
fi
mkdir -p "$TOOLS_DIR" "$DIST_DIR"

unset BUILD_ROOT APPIMAGE_BASENAME
