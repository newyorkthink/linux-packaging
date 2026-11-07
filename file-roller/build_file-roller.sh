#!/usr/bin/env bash

############# 初始化脚本 #############

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

############# 准备构建目录 #############

# 设置构建路径，并清理、重建当前应用的 source、AppDir 和 dist 目录。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" "file-roller"

############# 准备构建环境 #############

# 安装构建工具和应用所需的依赖包。
"$SCRIPT_DIR/../common/apt/install_packages.sh" bzip2 fcitx5-frontend-gtk4 file-roller language-pack-gnome-zh-hans-base libfcitx5gclient2 libgdk-pixbuf2.0-bin libglib2.0-bin libgtk-4-bin libgtk-4-dev librsvg2-bin unzip zip

############# 下载打包工具 #############

# 下载并校验打包工具及所需插件，随后加载构建环境配置。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" gtk "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"

############ 初始化 AppDir #############

# 首次运行 linuxdeploy，创建 AppDir 的基础目录。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

############ 下载并准备应用 #############

# 下载已安装版本的软件包并解包到 AppDir，成功后返回版本号。
VERSION="$("$SCRIPT_DIR/../common/apt/extract_installed_package.sh" "file-roller" "$APPDIR" bzip2 unzip zip)"

########## 准备桌面资源和运行库 #########

# 下载并解包应用所需的图标与主题资源。
"$SCRIPT_DIR/../common/apt/download_and_extract_packages.sh" "$APPDIR" gnome-themes-extra-data

# 本程序专属处理：将 Ubuntu 简体中文译文放入包内翻译目录。
mkdir -p "$APPDIR/usr/share/locale"
cp -a "/usr/share/locale-langpack/zh_CN" "$APPDIR/usr/share/locale/zh_CN"
test -f "$APPDIR/usr/share/locale/zh_CN/LC_MESSAGES/file-roller.mo"

############# 准备 AppRun ##############

# 在 AppDir 根目录创建完整的 AppRun 启动脚本。
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
HERE="$(dirname "$(readlink -f "${0}")")"

# 设置简体中文界面环境。
# 不设置 LOCPATH。Ubuntu 24.04 生成的 locale 数据在这台机器上无法加载，而且 LOCPATH 会挡住系统自己的 zh_CN.UTF-8。
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh

# 设置程序、运行库和共享数据的搜索路径。
export PATH="$HERE/usr/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$HERE/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

# GTK 运行环境：指定 GSettings schema 和 GIO 动态模块的目录。
export GSETTINGS_SCHEMA_DIR="$HERE/usr/share/glib-2.0/schemas${GSETTINGS_SCHEMA_DIR:+:$GSETTINGS_SCHEMA_DIR}"
export GIO_MODULE_DIR="$HERE/usr/lib/x86_64-linux-gnu/gio/modules"

# 本程序专属处理：固定 Adwaita 深色主题，覆盖 linuxdeploy GTK hook 写入的浅色主题。
export GTK_THEME=Adwaita-dark

# 本程序专属处理：切换到包内根目录，使相对 locale 路径指向包内中文译文。
cd "$HERE"

# 本程序专属处理：仅向应用进程传入 LC_ALL。rofi 会带入宿主的 LC_ALL，只设置 LANG 时界面仍是英文。
# 启动包内程序，并保留传入的命令行参数。
exec env LC_ALL=zh_CN.UTF-8 "$HERE/usr/bin/file-roller" "$@"
APPRUN

# 为启动脚本添加执行权限。
chmod +x "$APPDIR/AppRun"

############### 核心打包 ###############

# 指定 GTK 主版本。
export DEPLOY_GTK_VERSION=4

# 再次运行 linuxdeploy，部署运行资源并生成中间 AppImage。
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin gtk --output appimage

############### 整理产物 ###############

# 本程序专属处理：GTK4 通过 immodules/giomodule.cache 发现 fcitx，模块名是 fcitx。
im_mod="$(find "$APPDIR" -type f -name 'libim-fcitx5.so' -print -quit)"
[[ -n "$im_mod" ]] || { echo "错误：包内没有 libim-fcitx5.so。" >&2; exit 1; }
printf '%s\n' 'libim-fcitx5.so: gtk-im-module' > "$(dirname "$im_mod")/giomodule.cache"
fcitx_client="$(find /usr/lib -type f -name 'libFcitx5GClient.so.*' -print -quit)"
[[ -n "$fcitx_client" ]] || { echo "错误：构建环境中没有 libFcitx5GClient。" >&2; exit 1; }
cp -aL "$fcitx_client" "$APPDIR/usr/lib/"

# 本程序专属处理：将 AppImage 内 ELF 的绝对 locale 路径改成相对路径。
# AppRun 会先 cd 到 AppImage 根目录，因此 usr/share/locale 会稳定解析为 AppImage 内置中文目录。
PATCH_APPDIR="$APPDIR" python3 "$SCRIPT_DIR/patches/relocate_locale_paths.py"

# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
