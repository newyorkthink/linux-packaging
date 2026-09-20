#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

###### 准备构建环境 ######

# 公共入口统一设置标准路径，并清理、重建 source、AppDir、dist 和 tools。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" xnconvert

DEB="$SOURCE_DIR/XnConvert.deb"
DESKTOP_FILE="$APPDIR/usr/share/applications/XnConvert.desktop"
ICON_FILE="$APPDIR/opt/XnConvert/xnconvert.png"

# 通过公共入口安装当前应用明确需要的构建与运行依赖。
"$SCRIPT_DIR/../common/apt/install_packages.sh" \
  dpkg qtchooser qt5-qmake qt5-qmake-bin qtbase5-dev qtbase5-dev-tools libqt5svg5 \
  qttranslations5-l10n qt5-gtk-platformtheme qtwayland5 fcitx5-frontend-qt5 libfcitx5-qt1 \
  libxkbcommon-x11-0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-render-util0 \
  libxcb-xinerama0 libxcb-xkb1

# XnConvert 使用 Qt5，Qt 插件必须使用同一主版本的真实 qmake。
QT5_BIN_DIR=/usr/lib/qt5/bin

###### 下载打包工具 ######

# 使用公共脚本动态下载并校验 linuxdeploy、Qt 插件、appimagetool 和 Type 2 runtime。
"$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" qt

###### 初始化 AppDir ######

# 第一次只运行普通 linuxdeploy 创建空 AppDir；此处不配置 Qt 或中间产物。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

###### 下载并准备 XnConvert ######

# 通过公共入口从官方校验清单取得、校验并记录当前最新稳定版 Linux x64 DEB。
"$SCRIPT_DIR/../common/download/download_latest_checksum_asset.sh" \
  "https://download.xnview.com/versions/XnConvert/XnConvert-CHECKSUMS.txt" \
  '^XnConvert-[0-9]+(\.[0-9]+)+-linux-x64\.deb$' "$DEB" "$DIST_DIR/version.txt"

# 把同一官方 DEB 安装到隔离构建环境供依赖扫描，并由公共入口按上游布局解包到 AppDir。
"$SCRIPT_DIR/../common/apt/install_packages.sh" --no-update "$DEB"
"$SCRIPT_DIR/../common/archive/extract_archive.sh" "$DEB" "$APPDIR"

# 官方 desktop 使用绝对图标路径；改成 AppImage 可发现的图标名称。
sed -i 's|^Icon=.*|Icon=xnconvert|' "$DESKTOP_FILE"

###### 准备 Qt5 运行资源 ######

# 保留已经验证的 Qt5 翻译、XCB 平台库和图标部署方式。
mkdir -p \
  "$APPDIR/usr/lib" "$APPDIR/usr/translations" \
  "$APPDIR/usr/share/icons/hicolor/256x256/apps"
cp -a /usr/share/qt5/translations/. "$APPDIR/usr/translations/"
cp -a "$APPDIR/opt/XnConvert/lib"/libQt5XcbQpa.so* "$APPDIR/usr/lib/"
cp -a "$ICON_FILE" "$APPDIR/usr/share/icons/hicolor/256x256/apps/xnconvert.png"

###### 核心打包 ######

# 公共入口设置技术栈无关的 linuxdeploy 环境；Qt5 参数仍由当前项目追加。
source "$SCRIPT_DIR/../common/linuxdeploy/configure_environment.sh" \
  "$TOOLS_DIR" "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"
export QT_SELECT=qt5
export PATH="$QT5_BIN_DIR:$PATH"
export QMAKE="$QT5_BIN_DIR/qmake"

# 应用文件进入 AppDir 后，在第二次 linuxdeploy 前写入完整根 AppRun。
# Qt linuxdeploy 会自动把它保存为 AppRun.wrapped，并生成加载 Qt hook 的顶层 AppRun。
cat > "$APPDIR/AppRun" <<'EOF_APPRUN'
#!/usr/bin/env bash
set -Eeuo pipefail

HERE="$(dirname "$(readlink -f "${0}")")"

# 保留中文界面环境；输入法仍由 Qt 插件和宿主桌面负责。
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh

# 所有 linuxdeploy AppRun 都保留 AppDir/usr 下的 bin、lib、share 三个基础搜索目录。
export PATH="$HERE/opt/XnConvert:$HERE/usr/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$HERE/opt/XnConvert/lib:$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$HERE/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

# XnConvert 自带 Qt plugin 位于 opt/XnConvert/lib，中文输入插件由 linuxdeploy 放入 usr/plugins。
# opt/XnConvert/Plugins 是应用自己的图片格式解码库，不属于 QT_PLUGIN_PATH。
export QT_PLUGIN_PATH="$HERE/opt/XnConvert/lib:$HERE/usr/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
export QT_QPA_PLATFORM_PLUGIN_PATH="$HERE/opt/XnConvert/lib/platforms:$HERE/usr/plugins/platforms${QT_QPA_PLATFORM_PLUGIN_PATH:+:$QT_QPA_PLATFORM_PLUGIN_PATH}"
# XnConvert 会读取自身 language 目录；linuxdeploy 同时把对应翻译链接到 usr/translations。
export QT_TRANSLATIONS_PATH="$HERE/usr/translations${QT_TRANSLATIONS_PATH:+:$QT_TRANSLATIONS_PATH}"
export QT_QPA_PLATFORM=xcb

exec "$HERE/opt/XnConvert/XnConvert" "$@"
EOF_APPRUN
chmod +x "$APPDIR/AppRun"

# 第二次 linuxdeploy 扫描上游 /opt 布局时，优先使用 XnConvert 自带运行库。
export LD_LIBRARY_PATH="$APPDIR/opt/XnConvert/lib:$APPDIR/opt/XnConvert/Plugins:$APPDIR/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# XnConvert 使用 Qt5；第二次 linuxdeploy 部署 Qt 资源并完成 AppRun 包装。
export ARCH=x86_64; linuxdeploy \
  --appdir AppDir --desktop-file "$DESKTOP_FILE" --icon-file "$ICON_FILE" \
  --plugin qt --output appimage

###### 整理产物 ######

# 公共入口使用官方 appimagetool 和 Type 2 runtime 封装，并输出正式资产 SHA-256。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" \
  "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE"
