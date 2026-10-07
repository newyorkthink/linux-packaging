#!/usr/bin/env bash
# 从 RongleCat/grok-app 官方 Linux amd64 DEB 动态重打包。
# 官方包不带 zh_CN.UTF-8，也不带 GTK 3 的 IBus / Fcitx5 输入模块。
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

###### 准备 Arch 构建环境 ######

# 只清理当前项目的构建目录。AppDir 由 quick-sharun 创建。
"$SCRIPT_DIR/../common/build/prepare_x86_64_workspace.sh" \
  "$SCRIPT_DIR" --skip-create AppDir source dist

# 安装统一的 Arch AppImage 基础包。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base

# WebKitGTK 4.1 是主程序的直接依赖。im-ibus.so 属于 ibus，不随 gtk3 安装。
# 托盘库由程序运行时加载，不在 ELF NEEDED 里。
"$SCRIPT_DIR/../common/arch/install_packages.sh" \
  dpkg gtk3 webkit2gtk-4.1 ibus fcitx5-gtk libayatana-appindicator

readonly SOURCE_DIR="$SCRIPT_DIR/source"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly APPDIR="$SCRIPT_DIR/AppDir"
readonly DEB_FILE="$SOURCE_DIR/grok-app.deb"
readonly PACKAGE_ROOT="$SOURCE_DIR/package"
readonly DESKTOP_FILE="$SOURCE_DIR/grok-app.desktop"
readonly ICON_FILE="$PACKAGE_ROOT/usr/share/icons/hicolor/128x128/apps/grok-app.png"
readonly OUTFILE="$DIST_DIR/grok-app.AppImage"

###### 获取官方正式版 ######

# 公共入口选择最新正式 semver Release，核对唯一 amd64 DEB 与 GitHub SHA-256 后下载。
VERSION="$("$SCRIPT_DIR/../common/github/download_latest_stable_release_asset.sh" \
  RongleCat/grok-app 'Grok_{version}_amd64.deb' "$DEB_FILE" grok amd64)"
readonly VERSION

# 公共归档入口按官方 DEB 原始布局解包。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" "$DEB_FILE" "$PACKAGE_ROOT"

# 沿用官方 desktop。补上协议参数和分类，图标名保持 grok-app。
cp -a -- "$PACKAGE_ROOT/usr/share/applications/Grok.desktop" "$DESKTOP_FILE"
sed -i \
  -e 's|^Exec=.*|Exec=grok-app %U|' \
  -e 's|^Icon=.*|Icon=grok-app|' \
  -e 's|^Categories=.*|Categories=Development;|' \
  "$DESKTOP_FILE"

###### 构建 AppImage ######

export ARCH=x86_64
export VERSION
export APPNAME="Grok"
export MAIN_BIN=grok-app
export STARTUPWMCLASS=grok-app
export ICON="$ICON_FILE"
export DESKTOP="$DESKTOP_FILE"
export OUTPATH="$DIST_DIR"
export OUTNAME=grok-app.AppImage
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_WEBKIT2GTK=1
export WEBKIT2GTK_DIR=/usr/lib/webkit2gtk-4.1

# 收集官方主程序、运行时托盘库，以及 GTK 3 的 IBus 与 Fcitx5 输入模块。
quick-sharun \
  "$PACKAGE_ROOT/usr/bin/grok-app" \
  /usr/lib/libayatana-appindicator3.so.1 \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so

# 包内提供 zh_CN.UTF-8。不设置 LC_ALL，也不指定 GTK_IM_MODULE，由宿主已配置的输入法选择模块。
mkdir -p "$APPDIR/lib/locale"
localedef --no-archive -i zh_CN -f UTF-8 "$APPDIR/lib/locale/zh_CN.utf8"
cat >> "$APPDIR/.env" <<'ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
ENV

# Grok CLI 用 PATH 上的第一个 bwrap。quick-sharun 把包内 bin 放在最前时，
# 打包工具带入的 bwrap 会把 --proc 当成 capability：bwrap: unknown cap: --proc。
# 不覆盖 AppRun。宿主没有 /usr/bin/bwrap 时保持原 PATH。
cat > "$APPDIR/bin/15-grok-host-bwrap.hook" <<'HOOK'
if [ -x /usr/bin/bwrap ]; then
  export PATH="/usr/bin:/bin${HOSTPATH:+:$HOSTPATH}:$APPDIR/bin"
fi
HOOK

# 启动时把 grok:// 和官方皮肤 MIME 指到当前 AppImage。
bash "$SCRIPT_DIR/../common/desktop/write_scheme_hook.sh" \
  --output "$APPDIR/bin/20-grok-app-protocol.hook" \
  --desktop-file grok-app.desktop \
  --name "Grok" \
  --comment "desktop workbench for Grok Build CLI" \
  --icon grok-app \
  --wm-class grok-app \
  --categories "Development;" \
  --scheme grok \
  --mime-extra application/vnd.grok.skin

# 正式生成 AppImage；版本只在产物成功后写入。
quick-sharun --make-appimage
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" \
  "$OUTFILE" "$VERSION" "$DIST_DIR/version.txt"
