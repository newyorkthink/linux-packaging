#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

############# 准备构建目录 #############

# 设置构建路径，并清理、重建当前应用的 source、AppDir 和 dist 目录。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" rvncconnect

############# 准备构建环境 #############

# 安装构建工具和应用所需的依赖包。
"$SCRIPT_DIR/../common/apt/install_packages.sh" dpkg-dev fcitx5-frontend-gtk3 gobject-introspection ibus-gtk3 libgdk-pixbuf2.0-bin libgirepository1.0-dev libgtk-3-bin libgtk-3-dev librsvg2-bin librsvg2-common librsvg2-dev

############# 下载打包工具 #############

# 下载并校验打包工具及所需插件，随后加载构建环境配置。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" gtk "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"

############ 初始化 AppDir #############

# 首次运行 linuxdeploy，创建 AppDir 的基础目录。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

############ 下载并准备应用 #############

# 下载并校验官方安装包，将其安装到构建环境并解包到 AppDir，成功后返回版本号。
VERSION="$("$SCRIPT_DIR/../common/github/install_and_extract_latest_stable_release_deb.sh" --html-checksum "https://help.realvnc.com/hc/en-us/articles/27252822630301-SHA256-checksums-for-RealVNC-Connect-v8" '^RealVNC-Connect-[0-9]+([.][0-9]+)+-Linux-x64[.]deb$' "https://downloads.realvnc.com/download/file/realvnc-connect" "$SOURCE_DIR/rvncconnect.deb" "$APPDIR" realvnc-rvncconnect amd64)"

########## 准备桌面资源和运行库 #########

# 保存原始 Flutter bundle，整理桌面资源并生成宿主机浏览器隔离入口。
"$SCRIPT_DIR/patches/prepare_runtime.sh" "$APPDIR" "$SOURCE_DIR"

############# 准备 AppRun ##############

# 在 AppDir 根目录创建完整的 AppRun 启动脚本。
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
APPDIR="$(cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)"
export APPDIR

# 保存宿主机环境，供浏览器隔离入口恢复。
export RVNC_HOST_PATH="${PATH:-/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}"
export RVNC_HOST_XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export RVNC_HOST_LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"

# i3wm 等桌面通常没有统一的深色外观门户，默认固定为 GTK 深色主题。
export APPIMAGE_GTK_THEME="${APPIMAGE_GTK_THEME:-Adwaita:dark}"
export GTK_THEME="$APPIMAGE_GTK_THEME"

# 让 Flutter/GTK3 文本框使用宿主机正在运行的 Fcitx5。
export GTK_IM_MODULE="${GTK_IM_MODULE:-fcitx}"
export XMODIFIERS="${XMODIFIERS:-@im=fcitx}"

# 设置程序、运行库和共享数据的搜索路径。
export LD_LIBRARY_PATH="$APPDIR/usr/lib/rvncconnect/lib:$APPDIR/usr/lib/rvncconnect:$APPDIR/usr/lib:$APPDIR/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PATH="$APPDIR/usr/bin:$RVNC_HOST_PATH"
export XDG_DATA_DIRS="$APPDIR/usr/share:$RVNC_HOST_XDG_DATA_DIRS"

# 启动包内程序，并保留传入的命令行参数。
exec "$APPDIR/usr/lib/rvncconnect/rvncconnect" "$@"
APPRUN

# 为启动脚本添加执行权限。
chmod +x "$APPDIR/AppRun"

############### 核心打包 ###############

# 指定 GTK 主版本。
export DEPLOY_GTK_VERSION=3

# 保留 Flutter AOT 和私有运行库的符号。
export NO_STRIP=1

# 使用原始 Flutter bundle 的私有库目录解析依赖。
export LD_LIBRARY_PATH="$SOURCE_DIR/rvncconnect/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# 再次运行 linuxdeploy，部署运行资源并生成中间 AppImage。
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin gtk --output appimage

############### 整理产物 ###############

# 恢复原始 Flutter bundle，并清理不随包发布的 GPU 和 glibc 运行库。
"$SCRIPT_DIR/patches/restore_runtime.sh" "$APPDIR" "$SOURCE_DIR"

# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
