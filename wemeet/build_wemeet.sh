#!/usr/bin/env bash
# 下载腾讯会议官网当前 Linux DEB，保留官方 Qt 目录并使用 linuxdeploy 制作 AppImage。
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 使用公共工作区入口统一设置路径、检查架构，并清理、重建标准构建目录。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" wemeet

DEB_FILE="$SOURCE_DIR/wemeet.deb"
APP_ROOT="$APPDIR/opt/wemeet"
DESKTOP_FILE="$APPDIR/usr/share/applications/wemeetapp.desktop"
OFFICIAL_ICON_FILE="$APP_ROOT/icons/hicolor/256x256/mimetypes/wemeetapp.png"
ICON_FILE="$APPDIR/usr/share/icons/hicolor/256x256/apps/wemeet.png"
OFFICIAL='https://meeting.tencent.com/web-service/query-download-info?q=%5B%7B%22package-type%22%3A%22app%22%2C%22channel%22%3A%220300000000%22%2C%22platform%22%3A%22linux%22%2C%22arch%22%3A%22x86_64%22%2C%22decorators%22%3A%5B%22deb%22%5D%7D%5D&nonce=123456789abcdefg'

###### 准备构建环境 ######

# 安装 Qt5 插件部署工具，以及腾讯会议明确需要的 XCB、音频和系统运行库。
"$SCRIPT_DIR/../common/apt/install_packages.sh" \
  dpkg qtchooser qt5-qmake qt5-qmake-bin qtbase5-dev qtbase5-dev-tools qttools5-dev-tools \
  libqt5svg5 qttranslations5-l10n qt5-gtk-platformtheme qtwayland5 \
  fcitx5-frontend-qt5 libfcitx5-qt1 \
  libnss3 libx11-6 libpulse0 libgcrypt20 libdbus-1-3 libsystemd0 libudev1 \
  libxtst6 \
  libxkbcommon-x11-0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
  libxcb-render-util0 libxcb-xinerama0 libxcb-xkb1

# 腾讯会议使用 Qt5；Qt 插件必须调用同一主版本的真实 qmake。
QT5_BIN_DIR=/usr/lib/qt5/bin

###### 下载打包工具 ######

# 动态取得 linuxdeploy、Qt 插件、appimagetool 和官方 Type 2 runtime。
"$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" qt

###### 初始化 AppDir ######

# 第一次只运行普通 linuxdeploy，创建空 AppDir 的 usr/bin、usr/lib 和 usr/share 基础目录。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

###### 下载并准备腾讯会议 ######

# 官方接口返回当前版本和 CDN 地址；公共入口核对域名、文件名、版本、包名和架构。
VERSION="$("$SCRIPT_DIR/../common/download/download_json_deb_asset.sh" \
  "$OFFICIAL" \
  '."info-list"[0].version' \
  '."info-list"[0].url' \
  '^https://updatecdn[.]meeting[.]qq[.]com/cos/[0-9a-f]+/TencentMeeting_0300000000_.*[.]deb$' \
  'TencentMeeting_0300000000_{version}_x86_64_default.publish.officialwebsite.deb' \
  wemeet amd64 "$DEB_FILE")"

# 把同一官方 DEB 安装到隔离构建环境供依赖扫描，并按上游原始布局解包到 AppDir。
"$SCRIPT_DIR/../common/apt/install_packages.sh" --no-update "$DEB_FILE"
"$SCRIPT_DIR/../common/archive/extract_archive.sh" "$DEB_FILE" "$APPDIR"

[[ -x "$APP_ROOT/bin/wemeetapp" ]] || {
  echo '错误：官方包缺少腾讯会议主程序。' >&2
  exit 1
}
[[ -f "$DESKTOP_FILE" ]] || {
  echo '错误：官方包缺少腾讯会议 desktop 文件。' >&2
  exit 1
}
[[ -f "$OFFICIAL_ICON_FILE" ]] || {
  echo '错误：官方包缺少腾讯会议图标。' >&2
  exit 1
}

# desktop 使用可由 linuxdeploy 从已安装官方 DEB 解析的真实程序名；官方图标复制为匹配的 AppImage 图标名。
install -Dm0644 "$OFFICIAL_ICON_FILE" "$ICON_FILE"
sed -i \
  -e 's|^Exec=.*|Exec=wemeetapp %u|' \
  -e 's|^Icon=.*|Icon=wemeet|' \
  "$DESKTOP_FILE"

###### 核心打包 ######

# 公共入口配置 linuxdeploy 通用环境；Qt5 工具和腾讯会议私有库仅在当前项目追加。
source "$SCRIPT_DIR/../common/linuxdeploy/configure_environment.sh" \
  "$TOOLS_DIR" "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"
export QT_SELECT=qt5
export PATH="$APP_ROOT/bin:/opt/wemeet/bin:$QT5_BIN_DIR:$PATH"
export QMAKE="$QT5_BIN_DIR/qmake"
export LD_LIBRARY_PATH="$APP_ROOT/lib:/opt/wemeet/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# 应用文件进入 AppDir 后，在第二次 linuxdeploy 前写入完整根 AppRun。
# Qt 插件若生成 hook，会自动把本入口保存为 AppRun.wrapped。
cat > "$APPDIR/AppRun" <<'EOF_APPRUN'
#!/usr/bin/env bash
set -Eeuo pipefail

HERE="$(dirname "$(readlink -f "${0}")")"

# 保留官方启动脚本对 Wayland 会话的 XWayland 回退逻辑。
if [[ "${XDG_SESSION_TYPE:-}" == wayland ]]; then
  if [[ -f /opt/x11-wayland/x11-ext.sh ]]; then
    source /opt/x11-wayland/x11-ext.sh
  else
    export QT_QPA_PLATFORM=xcb
    export XDG_SESSION_TYPE=x11
    unset WAYLAND_DISPLAY
    export WEMEET_XWAYLAND=1
  fi
fi

# 保留官方语言、时区、私有库和 Qt 插件环境，并加入 linuxdeploy 三个基础目录。
export LC_ALL=zh_CN.UTF-8
export TZ=Asia/Shanghai
export PATH="$HERE/opt/wemeet/bin:$HERE/usr/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$HERE/opt/wemeet/lib:$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$HERE/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
export QT_PLUGIN_PATH="$HERE/opt/wemeet/plugins:$HERE/usr/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
export QT_QPA_PLATFORM_PLUGIN_PATH="$HERE/opt/wemeet/plugins/platforms:$HERE/usr/plugins/platforms${QT_QPA_PLATFORM_PLUGIN_PATH:+:$QT_QPA_PLATFORM_PLUGIN_PATH}"

exec "$HERE/opt/wemeet/bin/wemeetapp" "$@"
EOF_APPRUN
chmod +x "$APPDIR/AppRun"

# 第二次 linuxdeploy 使用 Qt5 插件扫描官方程序与资源，并保留中间 AppImage 供流程内部使用。
export ARCH=x86_64; linuxdeploy \
  --appdir AppDir \
  --desktop-file "$DESKTOP_FILE" \
  --icon-file "$ICON_FILE" \
  --plugin qt \
  --output appimage

###### 整理产物 ######

# 首次 linuxdeploy 成品尚未实机确认，按最终 AppDir 整理入口中已经声明的路径型变量。
"$SCRIPT_DIR/../common/linuxdeploy/normalize_apprun_paths.sh" "$APPDIR"

# 忽略 linuxdeploy 中间产物，由 appimagetool 和官方 Type 2 runtime 封装唯一正式资产。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" \
  "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
