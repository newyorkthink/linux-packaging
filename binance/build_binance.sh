#!/usr/bin/env bash

############# 初始化脚本 #############

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

############# 准备构建目录 #############

# 设置构建路径，并清理、重建当前应用的 source、AppDir 和 dist 目录。
source "$SCRIPT_DIR/../Common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" "binance"

############# 准备构建环境 #############

# 安装构建工具和应用所需的依赖包。
"$SCRIPT_DIR/../Common/apt/install_packages.sh" dpkg-dev pkgconf libglib2.0-bin libglib2.0-dev libgirepository1.0-dev libgtk-3-bin libgtk-3-dev libgdk-pixbuf2.0-bin libgdk-pixbuf-2.0-dev librsvg2-dev librsvg2-common libpango1.0-dev ibus-gtk3 libibus-1.0-5 libasound2 libatk1.0-0 libatk-bridge2.0-0 libatspi2.0-0 libcairo2 libcups2 libdbus-1-3 libdrm2 libexpat1 libgbm1 libgdk-pixbuf-2.0-0 libglib2.0-0 libgtk-3-0 libnotify4 libnotify-dev libnspr4 libnss3 libpango-1.0-0 libsecret-1-0 libuuid1 libxss1 libxtst6 libx11-6 libxcb1 libxcomposite1 libxdamage1 libxext6 libxfixes3 libxkbcommon0 libxrandr2 xdg-utils shared-mime-info hicolor-icon-theme

############# 下载打包工具 #############

# 下载并校验打包工具及所需插件，随后加载构建环境配置。
source "$SCRIPT_DIR/../Common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" gtk "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"

############ 初始化 AppDir #############

# 首次运行 linuxdeploy，创建 AppDir 的基础目录。
"$SCRIPT_DIR/../Common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

############ 下载并准备应用 #############

# 下载并校验官方安装包，将其安装到构建环境并解包到 AppDir，成功后返回版本号。
VERSION="$("$SCRIPT_DIR/../Common/github/install_and_extract_latest_stable_release_deb.sh" "binance/desktop" 'binance-{version}-amd64-linux.deb' "$SOURCE_DIR/binance.deb" "$APPDIR")"

# 本程序专属处理：规范包内主桌面入口，避免 Exec 指向宿主机绝对路径。
sed -i -e 's|^Exec=.*$|Exec=binance %U|' -e 's|^Icon=.*$|Icon=binance|' "$APPDIR/usr/share/applications/binance.desktop"

# 本程序专属处理：复用公共入口部署同一构建环境的 NSS 核心库及动态加载模块。
"$SCRIPT_DIR/../Common/linuxdeploy/copy_nss_runtime.sh" "$APPDIR/usr/lib"

############# 准备 AppRun ##############

# 在 AppDir 根目录创建完整的 AppRun 启动脚本。
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
HERE="$(dirname "$(readlink -f "${0}")")"

# 设置程序、运行库和共享数据的搜索路径。
export PATH="$HERE/opt/Binance:$HERE/usr/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$HERE/opt/Binance:$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$HERE/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

# GTK 运行环境：指定 GSettings schema 和 GIO 动态模块的目录。
export GSETTINGS_SCHEMA_DIR="$HERE/usr/share/glib-2.0/schemas${GSETTINGS_SCHEMA_DIR:+:$GSETTINGS_SCHEMA_DIR}"
export GIO_MODULE_DIR="$HERE/usr/lib/x86_64-linux-gnu/gio/modules"

# 启动包内程序，并保留传入的命令行参数。
exec "$HERE/opt/Binance/binance" "$@"
APPRUN

# 为启动脚本添加执行权限。
chmod +x "$APPDIR/AppRun"

############### 核心打包 ###############

# 指定 GTK 主版本。
export DEPLOY_GTK_VERSION=3

# 再次运行 linuxdeploy，部署运行资源并生成中间 AppImage。
# 本程序专属处理：补充 keytar.node 链接的 libsecret 与主程序 dlopen 的 libnotify。
MULTIARCH="$(dpkg-architecture -qDEB_HOST_MULTIARCH)"
export ARCH=x86_64; linuxdeploy \
  --appdir AppDir \
  -l "/usr/lib/$MULTIARCH/libsecret-1.so.0" \
  -l "/usr/lib/$MULTIARCH/libnotify.so" \
  --plugin gtk \
  --output appimage

############### 整理产物 ###############

# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../Common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
