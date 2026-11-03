#!/usr/bin/env bash

############# 初始化脚本 #############

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 安装统一的 Arch AppImage 基础包
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base

############# 准备构建目录 #############

# 设置构建路径，并清理、重建当前应用的 source、AppDir 和 dist 目录。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" ventoy --temporary-source

############# 准备构建环境 #############

# 安装构建工具和应用所需的依赖包。
"$SCRIPT_DIR/../common/arch/install_packages.sh" wget jq git tar gzip coreutils file desktop-file-utils gtk3 squashfs-tools

############ 下载并准备应用 #############

# 本程序专属处理：下载并校验同一 Release 的官方归档与校验清单，返回实际版本。
VERSION="$("$SCRIPT_DIR/../common/github/download_latest_stable_release_asset.sh" ventoy/Ventoy 'ventoy-{version}-linux.tar.gz' "$SOURCE_DIR/ventoy-linux.tar.gz" --latest-with-checksum sha256.txt "$SOURCE_DIR/ventoy-commit")"

# 本程序专属处理：解包本次下载的官方归档。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" "$SOURCE_DIR/ventoy-linux.tar.gz" "$SOURCE_DIR"

# 本程序专属处理：完整复制 Ventoy 官方 Linux 包，不重排或删减上游目录结构。
mkdir -p "$APPDIR/ventoy"
cp -a "$SOURCE_DIR/ventoy-$VERSION/." "$APPDIR/ventoy/"

########## 准备桌面资源和运行库 #########

# 本程序专属处理：写入 Ventoy 的桌面入口。
cat > "$APPDIR/ventoy.desktop" <<'EOF_DESKTOP'
[Desktop Entry]
Type=Application
Icon=ventoy
Name=Ventoy
Exec=ventoygui
Terminal=false
Hidden=false
Categories=Utility;
Comment=Ventoy2Disk GUI
EOF_DESKTOP

# 本程序专属处理：图标固定读取当前 Ventoy Release tag 对应的不可变 commit，避免跟随 main 漂移。
"$SCRIPT_DIR/../common/download/download_file.sh" "https://raw.githubusercontent.com/ventoy/Ventoy/$(<"$SOURCE_DIR/ventoy-commit")/ICON/logo_72.png" "$APPDIR/ventoy.png"

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
"$SCRIPT_DIR/../common/linuxdeploy/prepare_locale.sh" zh_CN UTF-8 "$APPDIR/usr/lib/locale/zh_CN.UTF-8"

############# 准备 AppRun ##############

# 在 AppDir 根目录创建完整的 AppRun 启动脚本。
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
HERE="$(dirname "$(readlink -f "${0}")")"

# 设置简体中文界面环境。
export LOCPATH="$HERE/usr/lib/locale${LOCPATH:+:$LOCPATH}"
export LANG=zh_CN.UTF-8

# 本程序专属处理：指定 Ventoy 的 GUI 入口。
MAIN="$HERE/ventoy/VentoyGUI.x86_64"

# 本程序专属处理：设置包内程序和运行库的搜索路径。
export LD_LIBRARY_PATH="$HERE/ventoy/"
export PATH="$HERE/ventoy/:$PATH"

# 本程序专属处理：禁用无障碍桥接。
export NO_AT_BRIDGE=1

# 启动包内程序，并保留传入的命令行参数。
exec "$MAIN" "$@"
APPRUN

# 为启动脚本添加执行权限。
chmod +x "$APPDIR/AppRun"

############# 下载打包工具 #############

# 下载并校验最终封装工具及运行时，并设置执行权限。
"$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" --appimagetool "$APPIMAGETOOL" "$RUNTIME_FILE" --release-ref latest

############### 整理产物 ###############

# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
