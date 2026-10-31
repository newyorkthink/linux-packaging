#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

###### 准备构建目录 ######

# 设置构建路径，并清理、重建当前应用的 source、AppDir 和 dist 目录。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" xnviewmp

###### 准备构建环境 ######

# 安装构建工具和应用所需的依赖包。
"$SCRIPT_DIR/../common/apt/install_packages.sh" dpkg qmake6 qt6-base-dev qt6-base-dev-tools qt6-declarative-dev qt6-declarative-dev-tools qt6-qpa-plugins qt6-gtk-platformtheme qt6-translations-l10n qt6-wayland fcitx5-frontend-qt6 libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 libgstreamer-gl1.0-0 gstreamer1.0-plugins-base gstreamer1.0-plugins-good libpipewire-0.3-0t64 libpulse0 libpulse-mainloop-glib0 libva2 libva-drm2 libva-x11-2 libwayland-client0 libwayland-cursor0 libwayland-egl1 libwayland-server0 libudev1 libxkbcommon-x11-0 libxcb-cursor0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-render-util0 libxcb-xinerama0 libxcb-xkb1

###### 下载打包工具 ######

# 下载并校验打包工具及所需插件，随后加载构建环境配置。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" qt "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"

###### 初始化 AppDir ######

# 首次运行 linuxdeploy，创建 AppDir 的基础目录。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

###### 下载并准备应用 ######

# 下载并校验官方安装包，将其安装到构建环境并解包到 AppDir，成功后返回版本号。
VERSION="$("$SCRIPT_DIR/../common/github/install_and_extract_latest_stable_release_deb.sh" --checksum "https://download.xnview.com/versions/XnView_MP/XnView_MP-CHECKSUMS.txt" '^XnView_MP-[0-9]+(\.[0-9]+)+-linux-x64\.deb$' "$SOURCE_DIR/XnView_MP.deb" "$APPDIR")"

###### 准备桌面资源和运行库 ######

# 指定 XnView MP 官方安装包中的桌面入口和图标路径，供图标修正及 linuxdeploy 图标部署使用。
DESKTOP_FILE="$APPDIR/usr/share/applications/XnView.desktop"
ICON_FILE="$APPDIR/opt/XnView/xnview.png"

# XnView MP 官方桌面入口使用绝对图标路径，需改为图标名称才能通过公共封装检查。
sed -i 's|^Icon=.*|Icon=xnview|' "$DESKTOP_FILE"

# 复制应用自带的 Qt XCB 平台库，供 Qt 插件识别模块。
cp -a "$APPDIR/opt/XnView/lib"/libQt6XcbQpa.so* "$APPDIR/usr/lib/"

# XnView MP 的包内组件依赖 PulseAudio、Wayland，Qt 多媒体还会动态加载 PipeWire 和 VA-API，因此一并补入对应运行库。
for runtime_lib in libpulse.so.0 libwayland-client.so.0 libwayland-cursor.so.0 libwayland-egl.so.1 libpipewire-0.3.so.0 libva.so.2 libva-drm.so.2 libva-x11.so.2; do
  # 复制当前运行库及其版本文件。
  cp -a "/usr/lib/x86_64-linux-gnu/${runtime_lib}"* "$APPDIR/usr/lib/"
done

# 为 XnView MP 补入的 PulseAudio 库还依赖 libpulsecommon，因此同时复制该配套库。
cp -a /usr/lib/x86_64-linux-gnu/pulseaudio/libpulsecommon-*.so "$APPDIR/usr/lib/"

###### 准备 AppRun ######

# 在 AppDir 根目录创建完整的 AppRun 启动脚本。
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
HERE="$(dirname "$(readlink -f "${0}")")"

# 设置简体中文界面环境。
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh

# 设置程序、运行库和共享数据的搜索路径。
export PATH="$HERE/opt/XnView:$HERE/usr/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$HERE/opt/XnView/lib:$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$HERE/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

# Qt 运行环境：指定插件、QML 模块和翻译资源的搜索目录。
export QT_PLUGIN_PATH="$HERE/opt/XnView/lib:$HERE/usr/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
export QML_IMPORT_PATH="$HERE/opt/XnView/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
export QML2_IMPORT_PATH="$HERE/opt/XnView/qml${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
export QT_TRANSLATIONS_PATH="$HERE/usr/translations${QT_TRANSLATIONS_PATH:+:$QT_TRANSLATIONS_PATH}"

# 设置界面自动缩放。
export QT_AUTO_SCREEN_SCALE_FACTOR=1

# 使用 XCB 后端，并通过包内 IBus 插件和 IBus Portal 接入 Fcitx5。
export QT_QPA_PLATFORM=xcb
export QT_IM_MODULE=ibus
export QT_IM_MODULES=ibus
export IBUS_USE_PORTAL=1

# 禁用多媒体硬件纹理转换。
export QT_DISABLE_HW_TEXTURES_CONVERSION=1

# 设置界面字体 DPI。
export QT_FONT_DPI=96

# 启动包内程序，并保留传入的命令行参数。
exec "$HERE/opt/XnView/XnView" "$@"
APPRUN

# 为启动脚本添加执行权限。
chmod +x "$APPDIR/AppRun"

###### 核心打包 ######

# 创建独立的 Qt 查询工具入口，避免应用自带运行库影响系统工具。
cat > "$TOOLS_DIR/qmake6" <<'EOF_QMAKE'
#!/usr/bin/env bash

# 清除运行库搜索路径。
unset LD_LIBRARY_PATH

# 启动系统工具，并保留传入的命令行参数。
exec /usr/bin/qmake6 "$@"
EOF_QMAKE

# 为工具入口添加执行权限。
chmod +x "$TOOLS_DIR/qmake6"

# 指定 Qt 查询工具。
export QMAKE=qmake6

# 再次运行 linuxdeploy，部署运行资源并生成中间 AppImage。
export ARCH=x86_64; linuxdeploy --appdir AppDir --icon-file "$ICON_FILE" --plugin qt --output appimage

###### 整理产物 ######

# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
