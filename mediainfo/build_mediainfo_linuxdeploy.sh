#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

###### 准备构建目录 ######

# 设置构建路径，并清理、重建当前应用的 source、AppDir 和 dist 目录。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" mediainfo

###### 准备构建环境 ######

# 安装构建工具和应用所需的依赖包。
"$SCRIPT_DIR/../common/apt/install_packages.sh" aptitude mediainfo librsvg2-bin

###### 下载打包工具 ######

# 下载并校验打包工具及所需插件，随后加载构建环境配置。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" "" "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"

###### 初始化 AppDir ######

# 首次运行 linuxdeploy，创建 AppDir 的基础目录。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

###### 下载并准备应用 ######

# 下载已安装版本的软件包并解包到 AppDir，成功后返回版本号。
VERSION="$("$SCRIPT_DIR/../common/apt/extract_installed_package.sh" mediainfo "$APPDIR")"

###### 准备桌面资源和运行库 ######

# MediaInfo CLI 包没有自带图标，下载官方 SVG 到 AppDir，供桌面入口和最终封装使用。
"$SCRIPT_DIR/../common/download/download_file.sh" "https://raw.githubusercontent.com/MediaArea/MediaInfo/master/Source/Resource/Image/MediaInfo.svg" "$APPDIR/usr/share/icons/hicolor/scalable/apps/mediainfo.svg"

# 检查 MediaInfo CLI 包中的桌面入口，仅在缺失时生成支持终端运行的入口。
mapfile -t MEDIAINFO_DESKTOP_FILES < <(dpkg -L mediainfo | awk '/\/usr\/share\/applications\/.*\.desktop$/ {print}')
if (( ${#MEDIAINFO_DESKTOP_FILES[@]} == 0 )); then
  cat > "$SOURCE_DIR/mediainfo.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=MediaInfo
Exec=mediainfo %f
Icon=mediainfo
Terminal=true
Categories=AudioVideo;
EOF
elif (( ${#MEDIAINFO_DESKTOP_FILES[@]} == 1 )); then
  cp "${MEDIAINFO_DESKTOP_FILES[0]}" "$SOURCE_DIR/mediainfo.desktop"
else
  echo "错误：mediainfo CLI 包包含多个 desktop，无法唯一选择。" >&2
  printf '%s\n' "${MEDIAINFO_DESKTOP_FILES[@]}" >&2
  exit 1
fi

# 将选定的桌面入口放入 AppDir。
cp "$SOURCE_DIR/mediainfo.desktop" "$APPDIR/usr/share/applications/mediainfo.desktop"

###### 准备 AppRun ######

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
exec "$HERE/usr/bin/mediainfo" "$@"
APPRUN

# 为启动脚本添加执行权限。
chmod +x "$APPDIR/AppRun"

###### 核心打包 ######

# 再次运行 linuxdeploy，部署运行资源并生成中间 AppImage。
export ARCH=x86_64; linuxdeploy --appdir AppDir --output appimage

###### 整理产物 ######

# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
