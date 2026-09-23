#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 当前应用只清理自身构建目录，避免旧版资源混入新产物。
rm -rf -- "$SCRIPT_DIR/AppDir" "$SCRIPT_DIR/source" "$SCRIPT_DIR/dist"
mkdir -p -- "$SCRIPT_DIR/source" "$SCRIPT_DIR/dist" "$SCRIPT_DIR/AppDir/shared/bin"

SOURCE_DIR="$SCRIPT_DIR/source"
APPDIR="$SCRIPT_DIR/AppDir"
APP_ROOT="$APPDIR/shared/bin"
SNAP_FILE="$SOURCE_DIR/bluemail.snap"
OUTFILE="$SCRIPT_DIR/dist/bluemail.AppImage"

###### 准备 Arch 构建环境 ######

# 公共入口安装 quick-sharun 构建所需的最小基础工具。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base

# 依据 AUR 依赖和官方 Snap 格式安装 BlueMail 所需的应用级工具与运行库。
"$SCRIPT_DIR/../common/arch/install_packages.sh" \
  squashfs-tools openssl gtk3 nss libnotify libsecret libappindicator libxtst libxss

###### 获取官方稳定版 ######

# 公共入口动态下载 latest/stable amd64 Snap，并校验官方 SHA3-384。
VERSION="$("$SCRIPT_DIR/../common/snap/download_stable_snap.sh" \
  bluemail blix amd64 "$SNAP_FILE")"

# 公共归档入口把 Snap 解包到真实程序目录，保留 Electron 资源相对布局。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" "$SNAP_FILE" "$APP_ROOT"

###### 整理 BlueMail 目录 ######

# 保存官方 desktop 和图标；把 Snap 专用绝对图标路径换成 AppImage 内名称。
cp -a -- "$APP_ROOT/meta/gui/bluemail.desktop" "$SOURCE_DIR/bluemail.desktop"
cp -a -- "$APP_ROOT/meta/gui/icon.png" "$SOURCE_DIR/bluemail.png"
sed -i 's|^Icon=.*|Icon=bluemail|' "$SOURCE_DIR/bluemail.desktop"

# 去掉 Snap 宿主运行时目录；保留应用自身 Chromium 库和资源。
rm -rf -- "${APP_ROOT:?}/data-dir" "${APP_ROOT:?}/gnome-platform" \
  "${APP_ROOT:?}/lib" "${APP_ROOT:?}/meta" "${APP_ROOT:?}/scripts" "${APP_ROOT:?}/usr"
rm -f -- "$APP_ROOT/command.sh" "$APP_ROOT/desktop-init.sh" \
  "$APP_ROOT/desktop-common.sh" "$APP_ROOT/desktop-gnome-specific.sh"

# 沿用官方 Snap 启动参数，并从 BlueMail 文件目录加载相邻资源和库。
cat > "$APPDIR/AppRun.sh" <<'APPRUN'
#!/bin/sh
set -e

export SHARUN_EXTRA_LIBRARY_PATH="$APPDIR/shared/bin${SHARUN_EXTRA_LIBRARY_PATH:+:$SHARUN_EXTRA_LIBRARY_PATH}"
export SHARUN_WORKING_DIR="$APPDIR/shared/bin"

exec "$APPDIR/bin/bluemail" --ozone-platform=x11 --no-sandbox "$@"
APPRUN
chmod +x "$APPDIR/AppRun.sh"

###### 构建 AppImage ######

export ARCH=x86_64
export VERSION
export APPNAME=BlueMail
export MAIN_BIN=bluemail
export STARTUPWMCLASS=BlueMail
export ICON="$SOURCE_DIR/bluemail.png"
export DESKTOP="$SOURCE_DIR/bluemail.desktop"
export OUTPATH="$SCRIPT_DIR/dist"
export OUTNAME=bluemail.AppImage
export DEPLOY_GTK=1
export NO_STRIP=1
export STRACE_MODE=0

# 收集主程序与上游 Electron 按名称动态加载的通知、密钥和托盘库。
LD_LIBRARY_PATH="$APP_ROOT${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  quick-sharun "$APP_ROOT/bluemail" "$APP_ROOT/chrome_crashpad_handler" \
  /usr/lib/libnotify.so.4 /usr/lib/libsecret-1.so.0 \
  /usr/lib/libappindicator3.so.1

# Electron 从包装器所在目录寻找 ICU、PAK、locales 和 resources；用包内链接保留原文件。
for item in "$APP_ROOT"/*; do
  name="${item##*/}"
  [[ "$name" == bluemail || -e "$APPDIR/bin/$name" || -L "$APPDIR/bin/$name" ]] && continue
  ln -s "../shared/bin/$name" "$APPDIR/bin/$name"
done

# 正式封装并只在产物生成后写入本次实际下载的版本。
quick-sharun --make-appimage
[[ -s "$OUTFILE" ]] || {
  echo "错误：BlueMail AppImage 未生成。" >&2
  exit 1
}
printf '%s\n' "$VERSION" > "$SCRIPT_DIR/dist/version.txt"
