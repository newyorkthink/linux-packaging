#!/usr/bin/env bash

############# 初始化脚本 #############

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

############# 准备构建目录 #############

# 设置构建路径，并清理、重建当前应用的 source、AppDir 和 dist 目录。
source "$SCRIPT_DIR/../Common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" "wemeet"

############# 准备构建环境 #############

# 安装构建工具和应用所需的依赖包。
"$SCRIPT_DIR/../Common/apt/install_packages.sh" dpkg qtchooser qt5-qmake qt5-qmake-bin qtbase5-dev qtbase5-dev-tools qttools5-dev-tools libqt5svg5 qttranslations5-l10n qt5-gtk-platformtheme qtwayland5 fcitx5-frontend-qt5 libfcitx5-qt1 libnss3 libx11-6 libpulse0 libgcrypt20 libdbus-1-3 libsystemd0 libudev1 libxtst6 locales libxkbcommon-x11-0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-render-util0 libxcb-xinerama0 libxcb-xkb1

############# 下载打包工具 #############

# 下载并校验打包工具及所需插件，随后加载构建环境配置。
source "$SCRIPT_DIR/../Common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" qt "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"

############ 初始化 AppDir #############

# 首次运行 linuxdeploy，创建 AppDir 的基础目录。
"$SCRIPT_DIR/../Common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

############ 下载并准备应用 #############

# 本程序专属处理：设置官网下载接口和本次使用的 DEB 路径。
OFFICIAL='https://meeting.tencent.com/web-service/query-download-info?q=%5B%7B%22package-type%22%3A%22app%22%2C%22channel%22%3A%220300000000%22%2C%22platform%22%3A%22linux%22%2C%22arch%22%3A%22x86_64%22%2C%22decorators%22%3A%5B%22deb%22%5D%7D%5D&nonce=123456789abcdefg'
DEB_FILE="$SOURCE_DIR/wemeet.deb"

# 本程序专属处理：按官网 JSON 选择并核对当前 x86_64 DEB，返回实际版本。
VERSION="$("$SCRIPT_DIR/../Common/download/download_json_deb_asset.sh" "$OFFICIAL" '."info-list"[0].version' '."info-list"[0].url' '^https://updatecdn[.]meeting[.]qq[.]com/cos/[0-9a-f]+/TencentMeeting_0300000000_.*[.]deb$' 'TencentMeeting_0300000000_{version}_x86_64_default.publish.officialwebsite.deb' wemeet amd64 "$DEB_FILE")"

# 本程序专属处理：把同一份官方 DEB 安装到构建环境供依赖扫描。
"$SCRIPT_DIR/../Common/apt/install_packages.sh" --no-update "$DEB_FILE"

# 本程序专属处理：按上游原始布局解包同一份 DEB。
"$SCRIPT_DIR/../Common/archive/extract_archive.sh" "$DEB_FILE" "$APPDIR"

########## 准备桌面资源和运行库 #########

# 本程序专属处理：定位官方程序、桌面入口与图标。
APP_ROOT="$APPDIR/opt/wemeet"
DESKTOP_FILE="$APPDIR/usr/share/applications/wemeetapp.desktop"
OFFICIAL_ICON_FILE="$APP_ROOT/icons/hicolor/256x256/mimetypes/wemeetapp.png"
ICON_FILE="$APPDIR/usr/share/icons/hicolor/256x256/apps/wemeet.png"

# 本程序专属处理：确认包内真实主程序可执行。
[[ -x "$APP_ROOT/bin/wemeetapp" ]] || {
  echo '错误：官方包缺少可执行的腾讯会议主程序。' >&2
  exit 1
}

# 本程序专属处理：安装与官方 desktop 匹配的 AppImage 图标。
install -Dm0644 "$OFFICIAL_ICON_FILE" "$ICON_FILE"

# 本程序专属处理：将官方 desktop 的 Exec 和 Icon 对齐包内程序及图标。
sed -i -e 's|^Exec=.*|Exec=wemeetapp %u|' -e 's|^Icon=.*|Icon=wemeet|' "$DESKTOP_FILE"

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
"$SCRIPT_DIR/../Common/linuxdeploy/prepare_locale.sh" zh_CN UTF-8 "$APPDIR/usr/lib/locale/zh_CN.UTF-8"

############# 准备 AppRun ##############

# 在 AppDir 根目录创建完整的 AppRun 启动脚本。
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
HERE="$(dirname "$(readlink -f "${0}")")"

# 本程序专属处理：保留官方 Wayland 会话处理和 XWayland 回退。
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

# 设置简体中文界面环境。
export LOCPATH="$HERE/usr/lib/locale${LOCPATH:+:$LOCPATH}"
if [[ "$(env LC_ALL=zh_CN.UTF-8 locale charmap 2>&1)" == UTF-8 ]]; then
  export LC_ALL=zh_CN.UTF-8
else
  export LC_ALL=C.UTF-8
  export LANGUAGE=zh_CN:zh
fi

# 本程序专属处理：保留官方启动入口的时区设置。
export TZ=Asia/Shanghai

# 设置程序、运行库和共享数据的搜索路径。
export PATH="$HERE/opt/wemeet/bin:$HERE/usr/bin:$HERE/opt/wemeet${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$HERE/opt/wemeet/lib:$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$HERE/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

# 本程序专属处理：优先使用官方 Qt 插件，同时保留 linuxdeploy 部署的搜索目录。
export QT_PLUGIN_PATH="$HERE/opt/wemeet/plugins:$HERE/usr/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
export QT_QPA_PLATFORM_PLUGIN_PATH="$HERE/opt/wemeet/plugins/platforms:$HERE/usr/plugins/platforms${QT_QPA_PLATFORM_PLUGIN_PATH:+:$QT_QPA_PLATFORM_PLUGIN_PATH}"

# 启动包内程序，并保留传入的命令行参数。
exec "$HERE/opt/wemeet/bin/wemeetapp" "$@"
APPRUN

# 为启动脚本添加执行权限。
chmod +x "$APPDIR/AppRun"

############### 核心打包 ###############

# 本程序专属处理：定位 Qt5 工具以及本次部署的 Xtst 和 PulseAudio 库。
QT5_BIN_DIR=/usr/lib/qt5/bin
MULTIARCH="$(dpkg-architecture -qDEB_HOST_MULTIARCH)"
XTST_LIB="/usr/lib/$MULTIARCH/libXtst.so.6"
PULSE_LIB="/usr/lib/$MULTIARCH/libpulse.so.0"
PULSE_COMMON_LIB=("/usr/lib/$MULTIARCH/pulseaudio/"libpulsecommon-*.so)

# 本程序专属处理：沿用 Qt5 工具及官方程序的搜索路径。
export PATH="$APP_ROOT/bin:/opt/wemeet/bin:$QT5_BIN_DIR:$PATH"

# 指定 Qt 查询工具。
export QMAKE="$QT5_BIN_DIR/qmake"

# 本程序专属处理：扫描时优先使用官方私有库并保留运行库原始符号。
export LD_LIBRARY_PATH="$APP_ROOT/lib:/opt/wemeet/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export NO_STRIP=1

# 再次运行 linuxdeploy，部署运行资源并生成中间 AppImage。
export ARCH=x86_64; linuxdeploy --appdir AppDir --desktop-file "$DESKTOP_FILE" --icon-file "$ICON_FILE" -l "$XTST_LIB" -l "$PULSE_LIB" -l "${PULSE_COMMON_LIB[0]}" -l "$APP_ROOT/lib/libQt5Gui.so.5" --plugin qt --output appimage

############### 整理产物 ###############

# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../Common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
