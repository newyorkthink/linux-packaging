#!/usr/bin/env bash
# 下载腾讯会议官网当前 Linux DEB，保留官方 Qt 目录并制作便携入口。
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
[[ "$(uname -m)" == x86_64 ]] || { echo '仅支持 x86_64。' >&2; exit 1; }

SOURCE="$SCRIPT_DIR/source"
APPDIR="$SCRIPT_DIR/AppDir"
DIST="$SCRIPT_DIR/dist"
DEB="$SOURCE/wemeet.deb"
PACKAGE="$SOURCE/package"
OFFICIAL='https://meeting.tencent.com/web-service/query-download-info?q=%5B%7B%22package-type%22%3A%22app%22%2C%22channel%22%3A%220300000000%22%2C%22platform%22%3A%22linux%22%2C%22arch%22%3A%22x86_64%22%2C%22decorators%22%3A%5B%22deb%22%5D%7D%5D&nonce=123456789abcdefg'

###### 准备构建环境 ######
# 安装基础工具和会议运行所需的系统图形、音频、Qt XCB 依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
"$SCRIPT_DIR/../common/arch/install_packages.sh" dpkg
"$SCRIPT_DIR/../common/arch/install_packages.sh" nss nspr dbus glib2 libpulse pipewire fontconfig freetype2 libx11 libxext libxrender libxrandr libxfixes libxcomposite libxdamage libxkbcommon libxkbcommon-x11 libxcb xcb-util-image xcb-util-keysyms xcb-util-renderutil xcb-util-wm mesa libglvnd alsa-lib at-spi2-core gtk3 cups ibus hicolor-icon-theme

# 只清理腾讯会议自己的工作目录，预留官方原包与打包目录。
rm -rf -- "$SOURCE" "$APPDIR" "$DIST"
mkdir -p "$SOURCE" "$PACKAGE" "$APPDIR/opt" "$DIST"

###### 下载和解包官方 DEB ######
# 官方下载接口返回当前版本和 CDN 地址；公共入口核对域名、文件名、版本和架构。
VERSION="$("$SCRIPT_DIR/../common/download/download_json_deb_asset.sh" "$OFFICIAL" '."info-list"[0].version' '."info-list"[0].url' '^https://updatecdn[.]meeting[.]qq[.]com/cos/[0-9a-f]+/TencentMeeting_0300000000_.*[.]deb$' 'TencentMeeting_0300000000_{version}_x86_64_default.publish.officialwebsite.deb' wemeet amd64 "$DEB")"

# 保留原 DEB 的 /opt/wemeet 相对结构和桌面资源。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" "$DEB" "$PACKAGE"
[[ -x "$PACKAGE/opt/wemeet/bin/wemeetapp" ]] || { echo '官方包缺少会议主程序。' >&2; exit 1; }
cp -a -- "$PACKAGE/opt/wemeet" "$APPDIR/opt/wemeet"
install -Dm0644 "$PACKAGE/opt/wemeet/icons/hicolor/256x256/mimetypes/wemeetapp.png" "$APPDIR/wemeet.png"
install -Dm0644 "$PACKAGE/usr/share/applications/wemeetapp.desktop" "$APPDIR/wemeet.desktop"

# 桌面入口指向 AppImage 内的主程序，图标使用官方 DEB 自带的 PNG。
sed -i -e 's|^Exec=.*|Exec=wemeet %u|' -e 's|^Icon=.*|Icon=wemeet|' "$APPDIR/wemeet.desktop"

# 官方启动器依赖 /opt 绝对路径；便携入口只设置同等目录和插件环境。
cat > "$APPDIR/AppRun.sh" <<'APPRUN'
#!/bin/sh
set -e
ROOT="$APPDIR/opt/wemeet"
export PATH="$ROOT/bin${PATH:+:$PATH}"
export SHARUN_EXTRA_LIBRARY_PATH="$ROOT/lib${SHARUN_EXTRA_LIBRARY_PATH:+:$SHARUN_EXTRA_LIBRARY_PATH}"
export SHARUN_WORKING_DIR="$ROOT"
export SHARUN_ALLOW_QT_PLUGIN_PATH=1
export QT_PLUGIN_PATH="$ROOT/plugins"
export QT_QPA_PLATFORM_PLUGIN_PATH="$ROOT/plugins/platforms"
if [ "${XDG_SESSION_TYPE:-}" = wayland ] && [ ! -f /opt/x11-wayland/x11-ext.sh ]; then
  export QT_QPA_PLATFORM=xcb
  export WEMEET_XWAYLAND=1
fi
cd "$ROOT"
exec "$ROOT/bin/wemeetapp" "$@"
APPRUN
chmod 0755 "$APPDIR/AppRun.sh"

###### 封装正式资产 ######
# quick-sharun 按主程序 ELF 收集外部运行库，保留腾讯自带的 Qt 库和资源布局。
export ARCH=x86_64 VERSION APPNAME='Tencent Meeting' MAIN_BIN=wemeet
export ICON="$APPDIR/wemeet.png" DESKTOP="$APPDIR/wemeet.desktop"
export OUTPATH="$DIST" OUTNAME=wemeet.AppImage NO_STRIP=1
export DEPLOY_OPENGL=1 DEPLOY_PIPEWIRE=1
LD_LIBRARY_PATH="$APPDIR/opt/wemeet/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" quick-sharun "$APPDIR/opt/wemeet/bin/wemeetapp"
quick-sharun --make-appimage

# 成品存在时记录官网实际版本，供统一 Release 版本清单读取。
[[ -s "$DIST/wemeet.AppImage" ]] || { echo '腾讯会议 AppImage 未生成。' >&2; exit 1; }
printf '%s\n' "$VERSION" > "$DIST/version.txt"
