#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# XnView MP 自带 Qt6 和媒体运行库，因此在仓库规定的 Ubuntu 24.04 Qt6 环境中完成实际打包。
if [[ "${GITHUB_ACTIONS:-}" == "true" && "${XNVIEWMP_NOBLE_INNER:-0}" != "1" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  exec docker run --rm \
    -e XNVIEWMP_NOBLE_INNER=1 \
    -e CI=1 \
    -e GH_TOKEN="${GH_TOKEN:-}" \
    -v "$REPO_ROOT:/workspace" \
    -w /workspace/xnviewmp \
    ubuntu:24.04 \
    bash ./build_xnviewmp.sh
fi

# 使用公共工作区入口统一设置路径，并清理、重建标准构建目录。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" xnviewmp

DEB="$SOURCE_DIR/XnView_MP.deb"
DESKTOP_FILE="$APPDIR/usr/share/applications/XnView.desktop"
ICON_FILE="$APPDIR/opt/XnView/xnview.png"

## 输出明确错误并立即终止构建。
die() {
  echo "错误：$*" >&2
  exit 1
}

###### 准备构建环境 ######

# 通过公共 APT 入口安装 Qt6 插件部署、QML 扫描和媒体运行库收集所需依赖。
"$SCRIPT_DIR/../common/apt/install_packages.sh" \
  dpkg qmake6 qt6-base-dev qt6-base-dev-tools \
  qt6-declarative-dev qt6-declarative-dev-tools \
  qt6-qpa-plugins qt6-gtk-platformtheme qt6-translations-l10n qt6-wayland \
  fcitx5-frontend-qt6 \
  libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 libgstreamer-gl1.0-0 \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
  libpulse0 libpulse-mainloop-glib0 \
  libva2 libva-drm2 libva-x11-2 \
  libwayland-client0 libwayland-cursor0 libwayland-egl1 libwayland-server0 libudev1 \
  libxkbcommon-x11-0 libxcb-cursor0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
  libxcb-render-util0 libxcb-xinerama0 libxcb-xkb1

# 从 Qt6 qmake 读取当前构建环境的翻译目录，避免写死发行版内部路径。
QT6_TRANSLATIONS_DIR="$(qmake6 -query QT_INSTALL_TRANSLATIONS)"

###### 下载打包工具 ######

# 使用公共脚本动态下载并校验 linuxdeploy、Qt 插件、appimagetool 和 Type 2 runtime。
"$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" qt

###### 初始化 AppDir ######

# 通过公共入口运行第一次普通 linuxdeploy，只创建空 AppDir 基础目录。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

###### 下载并准备 XnView MP ######

# 公共入口从官方校验清单选择最新版并核对 SHA-256，同时返回本次实际版本。
VERSION="$("$SCRIPT_DIR/../common/download/download_latest_checksum_asset.sh" \
  "https://download.xnview.com/versions/XnView_MP/XnView_MP-CHECKSUMS.txt" \
  '^XnView_MP-[0-9]+(\.[0-9]+)+-linux-x64\.deb$' "$DEB")"

# 把同一官方 DEB 安装到隔离构建环境供依赖扫描，并由公共入口按上游布局解包到 AppDir。
"$SCRIPT_DIR/../common/apt/install_packages.sh" --no-update "$DEB"
"$SCRIPT_DIR/../common/archive/extract_archive.sh" "$DEB" "$APPDIR"

# 规范官方 desktop 图标；Exec 继续使用 DEB 原始提供的 usr/bin/xnview 入口。
sed -i \
  -e 's|^Icon=.*|Icon=xnview|' \
  -e '/^Value=/d' \
  -e '/^Encoding=/d' \
  -e 's/^Terminal=0$/Terminal=false/' \
  "$DESKTOP_FILE"

###### 准备兼容运行库 ######

# 复制 Qt6 翻译和 XCB 平台库，继续优先使用 XnView 自带 Qt6。
mkdir -p "$APPDIR/usr/lib" "$APPDIR/usr/translations"
cp -a "$QT6_TRANSLATIONS_DIR/." "$APPDIR/usr/translations/"
cp -a "$APPDIR/opt/XnView/lib"/libQt6XcbQpa.so* "$APPDIR/usr/lib/"

# 按明确的库名模式复制当前应用需要的 Ubuntu 24.04 运行库。
copy_runtime_glob() {
  local pattern="$1"
  local files=()
  mapfile -t files < <(compgen -G "$pattern" || true)
  ((${#files[@]} > 0)) || die "找不到必需的运行库：$pattern"
  cp -a "${files[@]}" "$APPDIR/usr/lib/"
}

# 补入 Ubuntu 24.04 中当前应用所需的 GStreamer、PulseAudio、VA-API、Wayland 和 udev 库。
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

# 公共入口配置 linuxdeploy 通用环境；Qt6 只在当前 Qt 项目中追加。
source "$SCRIPT_DIR/../common/linuxdeploy/configure_environment.sh" \
  "$TOOLS_DIR" "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"

# 为 Qt 插件提供隔离的 qmake6 入口，避免 XnView 自带 Qt 库污染系统 qmake。
cat > "$TOOLS_DIR/qmake6" <<'EOF_QMAKE'
#!/usr/bin/env bash
unset LD_LIBRARY_PATH
exec /usr/bin/qmake6 "$@"
EOF_QMAKE
chmod +x "$TOOLS_DIR/qmake6"

export QT_SELECT=qt6
export QMAKE=qmake6
export NO_STRIP=1

# 第二次 linuxdeploy 扫描上游 /opt 布局时，优先使用 XnView 自带运行库并保留 AppDir/usr/lib。
export LD_LIBRARY_PATH="$APPDIR/opt/XnView:$APPDIR/opt/XnView/lib:$APPDIR/opt/XnView/Plugins:$APPDIR/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# 应用文件进入 AppDir 后，在第二次 linuxdeploy 前写入完整根 AppRun。
# Qt6 插件是否生成 hook 以当前官方工具实际产物为准，不人工补 AppRun.wrapped。
cat > "$APPDIR/AppRun" <<'EOF_APPRUN'
#!/usr/bin/env bash
set -Eeuo pipefail

HERE="$(dirname "$(readlink -f "${0}")")"

# 保留中文界面环境；Qt 输入法模块在下方明确选择 Fcitx5。
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
# XnView 在 X11 下继续使用 XCB，并明确加载 Fcitx5 的 Qt 输入上下文。
export QT_QPA_PLATFORM=xcb
export QT_IM_MODULE=fcitx
# 禁用 Qt Multimedia 的 GPU 纹理转换，避免 EGL 集成失败时部分视频只显示黑屏。
export QT_DISABLE_HW_TEXTURES_CONVERSION=1
export QT_FONT_DPI=96

exec "$HERE/opt/XnView/XnView" "$@"
EOF_APPRUN
chmod +x "$APPDIR/AppRun"

# XnView MP 使用 Qt6；第二次 linuxdeploy 部署 Qt6 资源并生成中间 AppImage。
export ARCH=x86_64; linuxdeploy \
  --appdir AppDir --desktop-file "$DESKTOP_FILE" --icon-file "$ICON_FILE" \
  --plugin qt --output appimage

# Qt 主版本变化后最终目录尚未确认，按实际 AppDir 整理现有 AppRun 中的路径型变量。
"$SCRIPT_DIR/../common/linuxdeploy/normalize_apprun_paths.sh" "$APPDIR"

###### 整理产物 ######

# 忽略 linuxdeploy 中间产物，由公共入口使用官方工具和 Type 2 runtime 正式封装。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" \
  "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
