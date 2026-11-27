#!/usr/bin/env bash

############# 初始化脚本 #############

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

############# 准备构建目录 #############

# 设置构建路径，并清理、重建当前应用的 source、AppDir 和 dist 目录。
source "$SCRIPT_DIR/../Common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" "rainlendar2"

############# 准备构建环境 #############

# 安装构建工具和应用所需的依赖包。
"$SCRIPT_DIR/../Common/apt/install_packages.sh" adwaita-icon-theme dpkg-dev glib-networking gnome-themes-extra ibus-gtk3 libcanberra-gtk3-module libcanberra-pulse libcanberra0 libgdk-pixbuf2.0-bin libgdk-pixbuf-2.0-dev libgirepository1.0-dev libglib2.0-bin libglib2.0-dev libgtk-3-bin libgtk-3-dev libpango1.0-dev librsvg2-dev libsm6 libstdc++6 libwebpdemux2

############# 下载打包工具 #############

# 下载并校验打包工具及所需插件，随后加载构建环境配置。
source "$SCRIPT_DIR/../Common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" gtk "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"

############ 初始化 AppDir #############

# 首次运行 linuxdeploy，创建 AppDir 的基础目录。
"$SCRIPT_DIR/../Common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

############ 下载并准备应用 #############

# 下载并校验官方安装包，将其安装到构建环境并解包到 AppDir，成功后返回版本号。
VERSION="$("$SCRIPT_DIR/../Common/github/install_and_extract_latest_stable_release_deb.sh" "rainlendar/Rainlendar-Resources" 'regex:rainlendar2-pro_{version}\.b[0-9]+-[0-9]+_amd64\.deb' "$SOURCE_DIR/rainlendar2-pro_amd64.deb" "$APPDIR")"

# 本程序专属处理：规范化桌面入口，并准备 IBus 和动态加载的铃声库。
"$SCRIPT_DIR/patches/prepare_appimage.sh" prepare "$APPDIR"

############# 准备 AppRun ##############

# 在 AppDir 根目录创建完整的 AppRun 启动脚本。
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
HERE="$(dirname "$(readlink -f "${0}")")"

# 设置程序、运行库和共享数据的搜索路径。
export PATH="$HERE/usr/bin:${PATH:-/usr/bin:/bin}"
export LD_LIBRARY_PATH="$HERE/usr/lib/rainlendar2:$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$HERE/usr/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

# GTK 运行环境：指定 GSettings schema 和 GIO 动态模块的目录。
export GSETTINGS_SCHEMA_DIR="$HERE/usr/share/glib-2.0/schemas${GSETTINGS_SCHEMA_DIR:+:$GSETTINGS_SCHEMA_DIR}"
export GIO_MODULE_DIR="$HERE/usr/lib/x86_64-linux-gnu/gio/modules"

# 本程序专属处理：使用包内 GTK3 IBus 模块连接宿主 Fcitx5 的 IBus 前端。
IBUS_IMMODULE="$HERE/usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so"
if [[ ! -f "$IBUS_IMMODULE" ]]; then
  echo '错误：Rainlendar2 AppImage 缺少 GTK3 IBus 模块。' >&2
  exit 1
fi

# 在用户可写目录创建临时缓存，并在写入失败时清理。
IM_CACHE_DIR="${XDG_RUNTIME_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}/rainlendar2"
mkdir -p -m 0700 -- "$IM_CACHE_DIR"
IM_CACHE_TEMP="$(mktemp "$IM_CACHE_DIR/immodules.XXXXXXXX")"
trap 'rm -f -- "$IM_CACHE_TEMP"' EXIT

# 生成记录当前 AppImage 挂载路径的 GTK3 输入法模块缓存。
cat > "$IM_CACHE_TEMP" <<EOF
# GTK+ Input Method Modules file
"$IBUS_IMMODULE"
"ibus" "IBus (Intelligent Input Bus)" "ibus" "" "ja:ko:zh:*"
EOF

# 缓存写完后原子替换正式文件，避免 GTK 读到未写完的内容。
GTK_IM_MODULE_FILE="$IM_CACHE_DIR/immodules.cache"
mv -fT -- "$IM_CACHE_TEMP" "$GTK_IM_MODULE_FILE"
trap - EXIT

# 指定 GTK3 使用 IBus，并保留宿主已有的 XMODIFIERS 设置。
export GTK_IM_MODULE_FILE
export GTK_IM_MODULE=ibus
export XMODIFIERS="${XMODIFIERS:-@im=fcitx}"

# 本程序专属处理：沿用旧版的 X11 后端和 GTK3 对话框深色主题。
export GDK_BACKEND=x11
export GTK_THEME=Adwaita:dark

# 本程序专属处理：使用包内 Pulse 驱动，并从程序目录读取默认铃声。
export CANBERRA_DRIVER=pulse
export LTDL_LIBRARY_PATH="$HERE/usr/lib${LTDL_LIBRARY_PATH:+:$LTDL_LIBRARY_PATH}"
cd -- "$HERE/usr/lib/rainlendar2"

# 启动包内程序，并保留传入的命令行参数。
exec "$HERE/usr/lib/rainlendar2/rainlendar2" "$@"
APPRUN

# 为启动脚本添加执行权限。
chmod +x "$APPDIR/AppRun"

############### 核心打包 ###############

# 指定 GTK 主版本。
export DEPLOY_GTK_VERSION=3

# 本程序专属处理：让 GTK 插件找到 Ubuntu 24.04 的输入法模块索引工具。
MULTIARCH="$(dpkg-architecture -qDEB_HOST_MULTIARCH)"
export PATH="/usr/lib/$MULTIARCH/libgtk-3-0t64:$PATH"

# 本程序专属处理：保留 GetPath 并发补丁需要的符号。
export NO_STRIP=1

# 再次运行 linuxdeploy，部署运行资源并生成中间 AppImage。
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin gtk --output appimage

############### 整理产物 ###############

# 本程序专属处理：修复铃声驱动路径和同步线程的共享返回值。
"$SCRIPT_DIR/patches/prepare_appimage.sh" finalize "$APPDIR"

# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../Common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
