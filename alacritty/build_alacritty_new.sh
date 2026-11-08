#!/usr/bin/env bash

############# 初始化脚本 #############

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

############# 准备构建目录 #############

# 设置构建路径，并清理、重建当前应用的 source、AppDir 和 dist 目录。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" "alacritty"

############# 准备构建环境 #############

# 安装构建工具和应用所需的依赖包。
"$SCRIPT_DIR/../common/apt/install_packages.sh" build-essential ca-certificates cmake curl git jq libfontconfig1-dev libx11-data libxcb-xfixes0-dev libxkbcommon-dev libxkbcommon-x11-0 pkg-config python3 xkb-data librsvg2-bin

############# 下载打包工具 #############

# 下载并校验打包工具及所需插件，随后加载构建环境配置。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" "" "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"

############ 初始化 AppDir #############

# 首次运行 linuxdeploy，创建 AppDir 的基础目录。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

############ 下载并准备应用 #############

# 本程序专属处理：通过公共认证入口获取官方最新正式版源码和标签。
TAG="$("$SCRIPT_DIR/../common/github/download_latest_stable_release_source.sh" alacritty/alacritty "$SOURCE_DIR/alacritty-src")"
VERSION="${TAG#v}"
if [[ -z "$VERSION" ]]; then
  echo "错误：无法读取 Alacritty 正式版版本号。" >&2
  exit 1
fi

# 本程序专属处理：先检查再应用现有 X11 IME 补丁，防止工作区切换后无法输入。
git -C "$SOURCE_DIR/alacritty-src" apply --check "$SCRIPT_DIR/patches/0001-x11-keep-ime-enabled.patch"
git -C "$SOURCE_DIR/alacritty-src" apply "$SCRIPT_DIR/patches/0001-x11-keep-ime-enabled.patch"

# 本程序专属处理：在源码目录中编译 Release 版本，不改变主脚本的工作目录。
(
  cd "$SOURCE_DIR/alacritty-src"
  cargo build --release
)

########## 准备桌面资源和运行库 #########

# 本程序专属处理：为编译后的主程序、官方桌面资源和 XKB 数据准备包内目录。
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/scalable/apps" "$APPDIR/usr/share/X11"

# 本程序专属处理：安装刚编译完成的主程序，避免使用 Ubuntu 仓库的旧版本。
cp "$SOURCE_DIR/alacritty-src/target/release/alacritty" "$APPDIR/usr/bin/alacritty"

# 本程序专属处理：移除 Release 二进制中不需要的符号，控制 AppImage 体积。
strip --strip-unneeded "$APPDIR/usr/bin/alacritty"

# 本程序专属处理：使用同一正式版源码中的桌面入口和 SVG 图标。
cp "$SOURCE_DIR/alacritty-src/extra/linux/Alacritty.desktop" "$APPDIR/usr/share/applications/Alacritty.desktop"
cp "$SOURCE_DIR/alacritty-src/extra/logo/alacritty-term.svg" "$APPDIR/usr/share/icons/hicolor/scalable/apps/Alacritty.svg"

# 本程序专属处理：保留原构建中的 XKB 键盘布局及 Compose 数据。
cp -a /usr/share/X11/xkb "$APPDIR/usr/share/X11/"
cp -a /usr/share/X11/locale "$APPDIR/usr/share/X11/"

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

# 本程序专属处理：仅使用包内运行库，避免继承外层 AppImage 的动态库路径。
export LD_LIBRARY_PATH="$HERE/usr/lib"

# 本程序专属处理：只使用包内及宿主系统的共享数据目录。
export XDG_DATA_DIRS="$HERE/usr/share:/usr/local/share:/usr/share"

# 本程序专属处理：使用与包内运行库配套的 XKB 键盘布局和 Compose 数据。
export XKB_CONFIG_ROOT="$HERE/usr/share/X11/xkb"
export XLOCALEDIR="$HERE/usr/share/X11/locale"

# 本程序专属处理：沿用宿主系统的 terminfo 数据库。
export TERMINFO="/usr/share/terminfo"

# 启动包内程序，并保留传入的命令行参数。
exec "$HERE/usr/bin/alacritty" "$@"
APPRUN

# 为启动脚本添加执行权限。
chmod +x "$APPDIR/AppRun"

############### 核心打包 ###############

# 再次运行 linuxdeploy，部署运行资源并生成中间 AppImage。
export ARCH=x86_64; linuxdeploy --appdir AppDir --output appimage \
  --library /usr/lib/x86_64-linux-gnu/libxkbcommon-x11.so.0 \
  --desktop-file "$APPDIR/usr/share/applications/Alacritty.desktop" \
  --icon-file "$APPDIR/usr/share/icons/hicolor/scalable/apps/Alacritty.svg"

############### 整理产物 ###############

# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
