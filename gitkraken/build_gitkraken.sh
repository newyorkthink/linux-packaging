#!/usr/bin/env bash

############# 初始化脚本 #############

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

############# 准备构建目录 #############

# 设置构建路径，并清理、重建当前应用的 source、AppDir 和 dist 目录。
source "$SCRIPT_DIR/../Common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" "gitkraken"

############# 准备构建环境 #############

# 安装构建工具和应用所需的依赖包。
"$SCRIPT_DIR/../Common/apt/install_packages.sh" dpkg-dev pkgconf libglib2.0-bin libglib2.0-dev libgirepository1.0-dev libgtk-3-bin libgtk-3-dev libgdk-pixbuf2.0-bin libgdk-pixbuf-2.0-dev librsvg2-dev librsvg2-common libpango1.0-dev libnss3 libnspr4 libssl3t64 ibus-gtk3 fcitx5-frontend-gtk3 locales hicolor-icon-theme adwaita-icon-theme

############# 下载打包工具 #############

# 下载并校验打包工具及所需插件，随后加载构建环境配置。
source "$SCRIPT_DIR/../Common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" gtk "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"

############ 初始化 AppDir #############

# 首次运行 linuxdeploy，创建 AppDir 的基础目录。
"$SCRIPT_DIR/../Common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

############ 下载并准备应用 #############

# 下载并校验官方安装包，将其安装到构建环境并解包到 AppDir，成功后返回版本号。
VERSION="$("$SCRIPT_DIR/../Common/github/install_and_extract_latest_stable_release_deb.sh" --url "https://api.gitkraken.dev/releases/production/linux/x64/active/gitkraken-amd64.deb" "" "$SOURCE_DIR/gitkraken-amd64.deb" "$APPDIR" "gitkraken" "amd64")"

########## 准备桌面资源和运行库 #########

# 本程序专属处理：使用官方主桌面入口，并将包内 CLI 链接改为相对路径。
DESKTOP_FILE="$APPDIR/usr/share/applications/gitkraken.desktop"
sed -i -e 's|^Exec=.*$|Exec=gitkraken %U|' -e 's|^Icon=.*$|Icon=gitkraken|' "$DESKTOP_FILE"
sed -i -e 's|^Exec=/usr/bin/gitkraken |Exec=gitkraken |' -e 's|^Icon=.*$|Icon=gitkraken|' \
  "$APPDIR/usr/share/applications/gitkraken-url-handler.desktop" \
  "$APPDIR/usr/share/applications/gk-cli-url-handler.desktop"
ln -sfn ../share/gitkraken/resources/bin/gitkraken.sh "$APPDIR/usr/bin/gitkraken"

# 下载并解包应用所需的图标与主题资源。
"$SCRIPT_DIR/../Common/apt/download_and_extract_packages.sh" "$APPDIR" hicolor-icon-theme adwaita-icon-theme

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

# 本程序专属处理：宿主选用简体中文 UTF-8 且缺少对应 locale 时，使用包内数据。
if [[ "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" == zh_CN.UTF-8 ]] &&
   [[ "$(locale charmap 2>/dev/null)" != UTF-8 ]]; then
  export LOCPATH="$HERE/usr/lib/locale${LOCPATH:+:$LOCPATH}"
fi

# 设置程序、运行库和共享数据的搜索路径。
export PATH="$HERE/usr/share/gitkraken:$HERE/usr/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$HERE/usr/share/gitkraken:$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$HERE/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

# GTK 运行环境：指定 GSettings schema 和 GIO 动态模块的目录。
export GSETTINGS_SCHEMA_DIR="$HERE/usr/share/glib-2.0/schemas${GSETTINGS_SCHEMA_DIR:+:$GSETTINGS_SCHEMA_DIR}"
export GIO_MODULE_DIR="$HERE/usr/lib/x86_64-linux-gnu/gio/modules"

# 本程序专属处理：GTK 菜单默认使用深色主题，显式指定的主题优先。
export GTK_THEME="${APPIMAGE_GTK_THEME:-Adwaita:dark}"

# 启动包内程序，并保留传入的命令行参数。
exec "$HERE/usr/share/gitkraken/gitkraken" "$@"
APPRUN

# 为启动脚本添加执行权限。
chmod +x "$APPDIR/AppRun"

############### 核心打包 ###############

# 指定 GTK 主版本。
export DEPLOY_GTK_VERSION=3

# 再次运行 linuxdeploy，部署运行资源并生成中间 AppImage。
# 本程序专属处理：选择主桌面入口，部署真实程序和原生模块所需的运行库。
PROGRAM_DIR="$APPDIR/usr/share/gitkraken"
MULTIARCH="$(dpkg-architecture -qDEB_HOST_MULTIARCH)"
PATH="/usr/lib/$MULTIARCH/libgtk-3-0t64:$PATH" \
  linuxdeploy --appdir AppDir --desktop-file "$DESKTOP_FILE" \
    --deploy-deps-only "$PROGRAM_DIR/gitkraken" \
    --deploy-deps-only "$PROGRAM_DIR/chrome_crashpad_handler" \
    --library "/usr/lib/$MULTIARCH/libssl.so.3" \
    --library "/usr/lib/$MULTIARCH/libgssapi_krb5.so.2" \
    --library "/usr/lib/$MULTIARCH/libxkbfile.so.1" \
    --plugin gtk --output appimage

############### 整理产物 ###############

# 复制构建环境中的 NSS 核心库及其配套动态加载模块。
"$SCRIPT_DIR/../Common/linuxdeploy/copy_nss_runtime.sh" "$APPDIR/usr/lib" --with-nspr

# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../Common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
