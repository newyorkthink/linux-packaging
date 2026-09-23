#!/usr/bin/env bash
# 基于 RustDesk 官方最新版 AppImage 修复 X11 会话被误报为 tty 的启动环境。
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
[[ "$(uname -m)" == x86_64 ]] || { echo '仅支持 x86_64。' >&2; exit 1; }

SOURCE="$SCRIPT_DIR/source"
APPDIR="$SCRIPT_DIR/AppDir"
DIST="$SCRIPT_DIR/dist"
TOOLS="$SCRIPT_DIR/tools"
IMAGE="$SOURCE/rustdesk-official.AppImage"

###### 准备构建环境 ######
# 安装下载元数据和 AppImage 封装工具需要的基础依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base

# 清理本应用旧工作目录，避免旧版官方文件残留。
rm -rf -- "$SOURCE" "$APPDIR" "$DIST" "$TOOLS"
mkdir -p "$SOURCE" "$DIST"

###### 下载官方资产 ######
# 从 RustDesk 正式 Release 动态选择 x86_64 资产，并核对 GitHub 发布摘要。
VERSION="$("$SCRIPT_DIR/../common/github/download_latest_stable_release_asset.sh" rustdesk/rustdesk 'rustdesk-{version}-x86_64.AppImage' "$IMAGE")"

# 使用公共入口取得官方 appimagetool 和 Type 2 runtime。
"$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS"

###### 保留官方内容并修复入口 ######
# 原样解包官方 AppImage；不替换 RustDesk 程序和其私有运行库。
"$SCRIPT_DIR/../common/archive/extract_appimage.sh" "$IMAGE" "$SOURCE/unpacked"
mv -- "$SOURCE/unpacked/squashfs-root" "$APPDIR"

# 将官方 ELF 启动器保留在原目录，再由脚本只处理实际 X11 却报告 tty 的会话。
mv -- "$APPDIR/AppRun" "$APPDIR/AppRun.official"
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/bin/sh
set -e
HERE="$(dirname "$(readlink -f "$0")")"

# X11 显示可用而桌面类型误报 tty 时，使用 RustDesk 官方支持的覆盖变量。
if [ -n "${DISPLAY:-}" ] && [ "${XDG_SESSION_TYPE:-}" = tty ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
  export RUSTDESK_FORCED_DISPLAY_SERVER=x11
fi

exec "$HERE/AppRun.official" "$@"
APPRUN
chmod 0755 "$APPDIR/AppRun"

###### 封装正式资产 ######
# 重新封装完整官方目录，并在成功生成后写入动态软件版本。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" "$TOOLS/appimagetool-x86_64.AppImage" "$APPDIR" "$DIST/rustdesk.AppImage" "$TOOLS/runtime-x86_64" "$VERSION"
