#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

###### 准备构建目录 ######

# 设置构建路径，并清理、重建当前应用的 source、AppDir 和 dist 目录。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" joplin

###### 准备构建环境 ######

# 安装构建工具和应用所需的依赖包。
"$SCRIPT_DIR/../common/apt/install_packages.sh" dpkg-dev pkgconf libglib2.0-bin libglib2.0-dev libgirepository1.0-dev libgtk-3-bin libgtk-3-dev libgdk-pixbuf2.0-bin libgdk-pixbuf-2.0-dev librsvg2-dev librsvg2-common libpango1.0-dev ibus-gtk3 libibus-1.0-5 libasound2 libatk1.0-0 libatk-bridge2.0-0 libatspi2.0-0 libcairo2 libcups2 libdbus-1-3 libdrm2 libgbm1 libgdk-pixbuf-2.0-0 libglib2.0-0 libgtk-3-0 libnotify4 libnspr4 libnss3 libpango-1.0-0 libsecret-1-0 libuuid1 libappindicator3-1 libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 libxi6 libxinerama1 libxkbcommon0 libxrandr2 libxrender1 libxshmfence1 libxss1 libxtst6 xdg-utils shared-mime-info hicolor-icon-theme

###### 下载打包工具 ######

# 下载并校验打包工具及所需插件，随后加载构建环境配置。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" gtk "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"

###### 初始化 AppDir ######

# 首次运行 linuxdeploy，创建 AppDir 的基础目录。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

###### 下载并准备应用 ######

# 下载并校验官方安装包，将其安装到构建环境并解包到 AppDir，成功后返回版本号。
VERSION="$("$SCRIPT_DIR/../common/github/install_and_extract_latest_stable_release_deb.sh" "laurent22/joplin" 'Joplin-{version}.deb' "$SOURCE_DIR/joplin.deb" "$APPDIR")"

###### 准备桌面资源和运行库 ######

# 下载并解包应用所需的图标与主题资源。
"$SCRIPT_DIR/../common/apt/download_and_extract_packages.sh" "$APPDIR" adwaita-icon-theme adwaita-icon-theme-full gnome-themes-extra-data

# 复制构建环境中的 NSS 核心库及其配套动态加载模块。
"$SCRIPT_DIR/../common/linuxdeploy/copy_nss_runtime.sh" "$APPDIR/usr/lib"

###### 准备 AppRun ######

# 在 AppDir 根目录创建完整的 AppRun 启动脚本。
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
HERE="$(dirname "$(readlink -f "${0}")")"

# 设置程序、运行库和共享数据的搜索路径。
export PATH="$HERE/opt/Joplin:$HERE/usr/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$HERE/opt/Joplin:$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$HERE/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

# GTK 运行环境：指定 GSettings schema 和 GIO 动态模块的目录。
export GSETTINGS_SCHEMA_DIR="$HERE/usr/share/glib-2.0/schemas${GSETTINGS_SCHEMA_DIR:+:$GSETTINGS_SCHEMA_DIR}"
export GIO_MODULE_DIR="$HERE/usr/lib/x86_64-linux-gnu/gio/modules"

# 设置深色主题和辅助功能兼容选项。
export GTK_THEME=Adwaita-dark
export NO_AT_BRIDGE=1

# 启动包内程序，并保留传入的命令行参数。
exec "$HERE/opt/Joplin/joplin" "$@"
APPRUN

# 为启动脚本添加执行权限。
chmod +x "$APPDIR/AppRun"

###### 核心打包 ######

# 指定 GTK 主版本。
export DEPLOY_GTK_VERSION=3

# 再次运行 linuxdeploy，部署运行资源并生成中间 AppImage。
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin gtk --output appimage

###### 整理产物 ######

# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
