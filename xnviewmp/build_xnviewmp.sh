#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# XnView MP 自带较旧的 Qt 和媒体运行库，因此在 Ubuntu 22.04 中完成实际打包，
# 避免 linuxdeploy 混入 Ubuntu 24.04 的媒体库。
if [[ "${GITHUB_ACTIONS:-}" == "true" && "${XNVIEWMP_JAMMY_INNER:-0}" != "1" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  exec docker run --rm \
    -e XNVIEWMP_JAMMY_INNER=1 \
    -e CI=1 \
    -e GH_TOKEN="${GH_TOKEN:-}" \
    -v "$REPO_ROOT:/workspace" \
    -w /workspace/xnviewmp \
    ubuntu:22.04 \
    bash ./build_xnviewmp.sh
fi

# 使用公共工作区入口统一设置路径，并清理、重建标准构建目录。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" xnviewmp

EXTRACT_DIR="$SOURCE_DIR/extracted"
TGZ="$SOURCE_DIR/XnView_MP.tgz"
mkdir -p "$EXTRACT_DIR"

## 输出明确错误并立即终止构建。
die() {
  echo "错误：$*" >&2
  exit 1
}

###### 准备构建环境 ######

# 通过公共 APT 入口安装 Qt5 插件部署和媒体运行库收集所需依赖。
"$SCRIPT_DIR/../common/apt/install_packages.sh" \
  tar qtchooser qt5-qmake qt5-qmake-bin qtbase5-dev qtbase5-dev-tools qttools5-dev-tools \
  qtdeclarative5-dev qtdeclarative5-dev-tools \
  qml-module-qtqml qml-module-qtqml-models2 \
  qml-module-qtquick2 qml-module-qtquick-window2 qml-module-qtquick-layouts \
  qml-module-qtquick-controls qml-module-qtquick-controls2 qml-module-qtquick-templates2 \
  qml-module-qtgraphicaleffects qml-module-qt-labs-platform qml-module-qt-labs-settings \
  libqt5svg5 qttranslations5-l10n qt5-gtk-platformtheme qtwayland5 \
  fcitx5-frontend-qt5 libfcitx5-qt1 \
  libqt5multimedia5 libqt5multimedia5-plugins libqt5multimediagsttools5 \
  libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
  libpulse0 libpulse-mainloop-glib0 \
  libva2 libva-drm2 libva-x11-2 \
  libwayland-client0 libwayland-cursor0 libwayland-egl1 libwayland-server0 libudev1 \
  libxkbcommon-x11-0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
  libxcb-render-util0 libxcb-xinerama0 libxcb-xkb1

# Qt 插件必须直接使用 Qt5 的真实工具，不能落到没有选中版本的 qtchooser wrapper。
QT5_BIN_DIR=/usr/lib/qt5/bin

###### 下载打包工具 ######

# 使用公共脚本动态下载并校验 linuxdeploy、Qt 插件、appimagetool 和 Type 2 runtime。
"$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" qt

###### 初始化 AppDir ######

# 通过公共入口运行第一次普通 linuxdeploy，只创建空 AppDir 基础目录。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

###### 下载并准备 XnView MP ######

# 公共入口从官方校验清单选择最新版、核对 SHA-256，并写入版本文件。
"$SCRIPT_DIR/../common/download/download_latest_checksum_asset.sh" \
  "https://download.xnview.com/versions/XnView_MP/XnView_MP-CHECKSUMS.txt" \
  '^XnView_MP-[0-9]+(\.[0-9]+)+-linux-x64\.tgz$' "$TGZ" "$DIST_DIR/version.txt"

# 解包官方归档并定位唯一的 XnView 主程序目录。
tar -xzf "$TGZ" -C "$EXTRACT_DIR"
mapfile -d '' xnview_bins < <(find "$EXTRACT_DIR" -type f -name XnView -perm -u+x -print0)
[[ ${#xnview_bins[@]} -eq 1 ]] || die "预期找到一个 XnView 可执行文件，实际找到 ${#xnview_bins[@]} 个"
SOURCE_APP_DIR="$(dirname "${xnview_bins[0]}")"

# 保持上游 /opt/XnView 布局；不预建或填充 AppDir/usr/bin。
mkdir -p "$APPDIR/opt/XnView" "$APPDIR/usr/share/applications"
cp -a "$SOURCE_APP_DIR/." "$APPDIR/opt/XnView/"
DESKTOP_FILE="$APPDIR/usr/share/applications/XnView.desktop"
ICON_FILE="$APPDIR/opt/XnView/xnview.png"
cp -a "$APPDIR/opt/XnView/XnView.desktop" "$DESKTOP_FILE"

# 规范官方 desktop 条目，并让 Exec 名称对应 /opt 中的真实主程序。
sed -i \
  -e 's|^Icon=.*|Icon=xnview|' \
  -e 's|^Exec=.*|Exec=XnView|' \
  -e '/^Value=/d' \
  -e '/^Encoding=/d' \
  -e 's/^Terminal=0$/Terminal=false/' \
  "$DESKTOP_FILE"

###### 准备兼容运行库 ######

# 复制 Qt5 翻译和 XCB 平台库，继续优先使用 XnView 自带 Qt。
mkdir -p "$APPDIR/usr/lib" "$APPDIR/usr/translations"
cp -a /usr/share/qt5/translations/. "$APPDIR/usr/translations/"
cp -a "$APPDIR/opt/XnView/lib"/libQt5XcbQpa.so* "$APPDIR/usr/lib/"

# 按明确的库名模式复制当前应用需要的 Jammy 运行库。
copy_runtime_glob() {
  local pattern="$1"
  local files=()
  mapfile -t files < <(compgen -G "$pattern" || true)
  ((${#files[@]} > 0)) || die "找不到必需的运行库：$pattern"
  cp -a "${files[@]}" "$APPDIR/usr/lib/"
}

# 补入已有兼容基线所需的 GStreamer、PulseAudio、VA-API、Wayland 和 udev 库。
for runtime_lib in \
  libgstreamer-1.0.so.0 libgstapp-1.0.so.0 libgstbase-1.0.so.0 libgstaudio-1.0.so.0 \
  libgstvideo-1.0.so.0 libgstpbutils-1.0.so.0 libgsttag-1.0.so.0 libgstallocators-1.0.so.0 \
  libgstfft-1.0.so.0 libgstgl-1.0.so.0 libpulse.so.0 libpulse-mainloop-glib.so.0 \
  libva.so.2 libva-drm.so.2 libva-x11.so.2 libwayland-client.so.0 libwayland-cursor.so.0 \
  libwayland-egl.so.1 libwayland-server.so.0 \
  libudev.so.1; do
  copy_runtime_glob "/usr/lib/x86_64-linux-gnu/${runtime_lib}*"
done
copy_runtime_glob "/usr/lib/x86_64-linux-gnu/pulseaudio/libpulsecommon-*.so"

###### 核心打包 ######

# 公共入口配置 linuxdeploy 通用环境；Qt5 只在当前 Qt 项目中追加。
source "$SCRIPT_DIR/../common/linuxdeploy/configure_environment.sh" \
  "$TOOLS_DIR" "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"
export QT_SELECT=qt5
export PATH="$QT5_BIN_DIR:$PATH"
export QMAKE="$QT5_BIN_DIR/qmake"
export NO_STRIP=1

# 第二次 linuxdeploy 扫描上游 /opt 布局时，优先使用 XnView 自带运行库并保留 AppDir/usr/lib。
export LD_LIBRARY_PATH="$APPDIR/opt/XnView:$APPDIR/opt/XnView/lib:$APPDIR/opt/XnView/Plugins:$APPDIR/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

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
# XnView 的真实程序位于 /opt，因此在对应变量前继续加入上游 /opt 路径。
export PATH="$HERE/opt/XnView:$HERE/usr/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$HERE/opt/XnView/lib:$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$HERE/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

# Qt 专用目录只加入最终 AppDir 中已经确认用途正确的真实路径。
# opt/XnView/Plugins 是 XnView 自身格式解码库，不是 Qt plugin 根目录。
export QT_PLUGIN_PATH="$HERE/opt/XnView/lib:$HERE/usr/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
export QML_IMPORT_PATH="$HERE/opt/XnView/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
export QML2_IMPORT_PATH="$HERE/opt/XnView/qml${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
# XnView 会读取自身 language 目录；linuxdeploy 同时把对应翻译链接到 usr/translations。
export QT_TRANSLATIONS_PATH="$HERE/usr/translations${QT_TRANSLATIONS_PATH:+:$QT_TRANSLATIONS_PATH}"

export QT_AUTO_SCREEN_SCALE_FACTOR=1
# XnView 官方针对视频播放时的 XCB OpenGL 上下文问题建议使用 EGL 集成。
export QT_QPA_PLATFORM=xcb
export QT_XCB_GL_INTEGRATION=xcb_egl
export QT_FONT_DPI=96

exec "$HERE/opt/XnView/XnView" "$@"
EOF_APPRUN
chmod +x "$APPDIR/AppRun"

# XnView MP 使用 Qt5；第二次 linuxdeploy 部署 Qt 资源并完成 AppRun 包装。
export ARCH=x86_64; linuxdeploy \
  --appdir AppDir --desktop-file "$DESKTOP_FILE" --icon-file "$ICON_FILE" \
  --plugin qt --output appimage

###### 整理产物 ######

# 忽略 linuxdeploy 中间产物，由公共入口使用官方工具和 Type 2 runtime 正式封装。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" \
  "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE"
