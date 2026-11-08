#!/usr/bin/env bash

############# 初始化脚本 #############

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

############# 准备构建目录 #############

# 设置构建路径，并清理、重建当前应用的 source、AppDir 和 dist 目录。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" "realvnc_vnc_viewer"

############# 准备构建环境 #############

# 安装构建工具和应用所需的依赖包。
"$SCRIPT_DIR/../common/apt/install_packages.sh" libsm6 libx11-6 libxext6

############# 下载打包工具 #############

# 下载并校验打包工具及所需插件，随后加载构建环境配置。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" "" "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"

############ 初始化 AppDir #############

# 首次运行 linuxdeploy，创建 AppDir 的基础目录。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

############ 下载并准备应用 #############

# 下载并校验官方安装包，将其安装到构建环境并解包到 AppDir，成功后返回版本号。
VERSION="$("$SCRIPT_DIR/../common/github/install_and_extract_latest_stable_release_deb.sh" --release-tag "original-package-archive" "newyorkthink/linux-packaging" "VNC-Viewer-7.15.1-Linux-x64.deb" "$SOURCE_DIR/VNC-Viewer-7.15.1-Linux-x64.deb" "$APPDIR")"

########## 准备桌面资源和运行库 #########

# 本程序专属处理：校验官方桌面资源，并在包内副本中设置 AppImage 的启动入口和图标。
DEPLOY_DESKTOP_FILE="$SOURCE_DIR/realvnc-vncviewer.desktop"
cp -a "$APPDIR/usr/share/applications/realvnc-vncviewer.desktop" "$DEPLOY_DESKTOP_FILE"
sed -i -e 's|^Exec=.*$|Exec=vncviewer|' -e 's|^Icon=.*$|Icon=vncviewer48x48|' "$DEPLOY_DESKTOP_FILE"
cp -a "$DEPLOY_DESKTOP_FILE" "$APPDIR/usr/share/applications/"
ICON_FILE="/usr/share/icons/hicolor/48x48/apps/vncviewer48x48.png"
[[ -f "$ICON_FILE" ]] || { echo "错误：找不到官方安装包的图标。" >&2; exit 1; }

############# 准备 AppRun ##############

# 在 AppDir 根目录创建完整的 AppRun 启动脚本。
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
HERE="$(dirname "$(readlink -f "${0}")")"

# 设置程序、运行库和共享数据的搜索路径。
export PATH="$HERE/usr/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$HERE/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

# 启动包内程序，并保留传入的命令行参数。
exec "$HERE/usr/bin/vncviewer" "$@"
APPRUN

# 为启动脚本添加执行权限。
chmod +x "$APPDIR/AppRun"

############### 核心打包 ###############

# 再次运行 linuxdeploy，部署运行资源并生成中间 AppImage。
export ARCH=x86_64; linuxdeploy --appdir AppDir --desktop-file "$DEPLOY_DESKTOP_FILE" --icon-file "$ICON_FILE" --output appimage

############### 整理产物 ###############

# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
