#!/usr/bin/env bash

############# 初始化脚本 #############

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

############# 准备构建目录 #############

# 设置构建路径，并清理、重建当前应用的 source、AppDir 和 dist 目录。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" dingtalk

############# 准备构建环境 #############

# 安装构建工具和应用所需的依赖包。
"$SCRIPT_DIR/../common/apt/install_packages.sh" dpkg-dev libgl1 libegl1 libglu1-mesa libgbm1 libxss1 libasound2t64 libpulse0 libpulse-mainloop-glib0 libopus0 libcups2t64 libnss3 libnspr4 libcrypt1 libgtk2.0-0t64 libfcitx5-qt1 libdbus-1-3 libinput10 libmtdev1t64 libxkbcommon0 libxkbcommon-x11-0 libxcb1 libxcb-cursor0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-randr0 libxcb-render-util0 libxcb-shape0 libxcb-shm0 libxcb-sync1 libxcb-xfixes0 libxcb-xinerama0 libxcomposite1 libxdamage1 libxrandr2 libxtst6 librsvg2-bin zenity

############# 下载打包工具 #############

# 下载并校验最终封装工具及运行时，并设置执行权限。
"$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" --appimagetool "$APPIMAGETOOL" "$RUNTIME_FILE"

############ 下载并准备应用 #############

# 下载并校验官方安装包，将其安装到构建环境并解包到 AppDir，成功后返回版本号。
VERSION="$("$SCRIPT_DIR/../common/aur/install_and_extract_deb_source.sh" dingtalk-bin x86_64 "$SOURCE_DIR" "$SOURCE_DIR/dingtalk.deb" "$APPDIR" com.alibabainc.dingtalk amd64)"

########## 准备桌面资源和运行库 #########

# 本程序专属处理：沿用必要的 AUR 布局调整和组件清理，准备官方运行目录、桌面入口和图标。
"$SCRIPT_DIR/patches/prepare_appdir.sh" "$APPDIR" "$SOURCE_DIR/dingtalk-bin"

# 复制构建环境中的 NSS 核心库及其配套动态加载模块。
"$SCRIPT_DIR/../common/linuxdeploy/copy_nss_runtime.sh" "$APPDIR/opt/dingtalk/release" --with-nspr

# 本程序专属处理：保留钉钉的 NSS 符号检查、可执行栈清理、递归依赖收集及缺失依赖检查。
"$SCRIPT_DIR/patches/collect_runtime.sh" "$APPDIR"

############# 准备 AppRun ##############

# 在 AppDir 根目录创建完整的 AppRun 启动脚本。
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
APPDIR="$(cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)"
RELEASE_DIR="$APPDIR/opt/dingtalk/release"
CEF_LIB_DIR="$RELEASE_DIR/plugins/dtwebview"
RUNTIME_LIB="$APPDIR/usr/lib/dingtalk-runtime"

# 本程序专属处理：保留程序和私有运行库的搜索路径。
export PATH="$APPDIR/usr/bin:${PATH:-/usr/bin:/bin}"
export LD_LIBRARY_PATH="$RELEASE_DIR:$CEF_LIB_DIR:$RUNTIME_LIB"

# 本程序专属处理：预加载内置 CEF，保持与钉钉官方 Elevator.sh 的启动方式一致。
export LD_PRELOAD="$CEF_LIB_DIR/libcef.so${LD_PRELOAD:+:$LD_PRELOAD}"
# 本程序专属处理：保留原有显示后端选择顺序。
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland;xcb}"
# 设置界面自动缩放。
export QT_AUTO_SCREEN_SCALE_FACTOR="${QT_AUTO_SCREEN_SCALE_FACTOR:-1}"
# 本程序专属处理：沿用输入法默认值，允许宿主环境覆盖。
export QT_IM_MODULE="${QT_IM_MODULE:-fcitx}"
export GTK_IM_MODULE="${GTK_IM_MODULE:-fcitx}"
export XMODIFIERS="${XMODIFIERS:-@im=fcitx}"

# 本程序专属处理：保留官方 Qt 插件目录及原有搜索顺序。
if [[ -d "$RELEASE_DIR/plugins" ]]; then
    export QT_PLUGIN_PATH="$RELEASE_DIR/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
fi
if [[ -d "$RELEASE_DIR/plugins/platforms" ]]; then
    export QT_QPA_PLATFORM_PLUGIN_PATH="$RELEASE_DIR/plugins/platforms"
fi

# 本程序专属处理：在官方运行目录中启动程序，保持相邻资源的相对路径。
cd "$RELEASE_DIR"

# 启动包内程序，并保留传入的命令行参数。
exec "$RELEASE_DIR/com.alibabainc.dingtalk" "$@"
APPRUN

# 为启动脚本添加执行权限。
chmod +x "$APPDIR/AppRun"

############### 整理产物 ###############

# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
