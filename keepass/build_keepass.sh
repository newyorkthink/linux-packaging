#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 本程序专属处理：在仓库根目录预编译插件并写入 AppImage。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" --base

# 清掉上次的打包目录。
"$SCRIPT_DIR/../Common/build/prepare_x86_64_workspace.sh" "$REPO_ROOT" --skip-create AppDir

# 安装额外的打包工具和 Xorg 依赖。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" --reinstall gcc base-devel wget curl unzip gnupg binutils patchelf coreutils appstream-glib desktop-file-utils util-linux zsync xorg-server xorg-server-common

# 先安装 GTK2，让后一组 AUR 包能使用已安装的依赖。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" gtk2
# 安装依赖 GTK2 的 AUR 包和主题引擎。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" gtk-sharp-2 gtk-engine-murrine gtk-engines
# 安装 KeePass、主题和其余运行依赖。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" keepass dbus-glib bash hicolor-icon-theme mono argon2 libgcrypt xdotool xsel mono-msbuild gtk3 libappindicator libdbusmenu-glib libdbusmenu-gtk3 libnotify gdk-pixbuf2 librsvg materia-gtk-theme gnome-themes-extra-gtk2

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../Common/build/read_app_version.sh" pacman "keepass")"

# 安装 Mono WinForms 使用的 Fontconfig 和思源黑体。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" --reinstall fontconfig adobe-source-han-sans-cn-fonts

# 通过 AUR 安装 KPScript，源文件校验失败时等待 1800 秒再重新下载一次。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" --aur-source-retry kpscript 1800

# 确认 AUR 包已安装 KPScript 程序。
test -f /usr/share/keepass/KPScript.exe

# 设置托盘插件归档的下载和解包目录。
KEEBUNTU_WORK_DIR="/tmp/keebuntu-gtk-status-icon"

# 清理上次构建留下的托盘插件临时文件。
rm -rf "$KEEBUNTU_WORK_DIR"
# 创建托盘插件工作目录。
mkdir -p "$KEEBUNTU_WORK_DIR"

# 下载并校验同一正式 Release 的托盘归档和发布者校验清单。
KEEBUNTU_VERSION="$("$SCRIPT_DIR/../Common/github/download_tagged_release_asset.sh" --latest --checksum-asset SHA256SUMS newyorkthink/Keebuntu "keebuntu-gtk-status-icon-{version}.tar.gz" "$KEEBUNTU_WORK_DIR/keebuntu-gtk-status-icon.tar.gz")"
# 解包已经通过校验的托盘归档。
"$SCRIPT_DIR/../Common/archive/extract_archive.sh" "$KEEBUNTU_WORK_DIR/keebuntu-gtk-status-icon.tar.gz" "$KEEBUNTU_WORK_DIR"
# 本程序专属处理：安装托盘插件并固定其在功能插件之前加载。
bash "$SCRIPT_DIR/GtkStatusIcon.sh" "$KEEBUNTU_WORK_DIR/keebuntu-gtk-status-icon-$KEEBUNTU_VERSION"

# 指定鼠标滚轮兼容补丁的 C# 源文件。
MONO_MOUSE_WHEEL_FIX_SOURCE="$SCRIPT_DIR/MonoMouseWheelFix.cs"
test -f "$MONO_MOUSE_WHEEL_FIX_SOURCE"

# 创建功能插件和兼容插件的安装目录。
mkdir -p /usr/share/keepass/Plugins

# 设置 PLGX 构建工作目录。
PLGX_WORK_DIR="/tmp/keepass-plgx-build"
# 设置 PLGX 插件下载目录。
PLGX_DOWNLOAD_DIR="$PLGX_WORK_DIR/downloads"
# 设置 Mono 预编译使用的独立缓存根目录。
PLGX_CACHE_HOME="$PLGX_WORK_DIR/home"
# 指定 PLGX 预编译器的 C# 源文件。
PLGX_PRECOMPILER_SOURCE="$SCRIPT_DIR/PrecompilePlgx.cs"
# 指定本次生成的 PLGX 预编译器路径。
PLGX_PRECOMPILER_EXE="$PLGX_WORK_DIR/PrecompilePlgx.exe"

# 清理上次构建留下的 PLGX 临时文件。
rm -rf "$PLGX_WORK_DIR"
# 创建插件下载和预编译目录。
mkdir -p "$PLGX_DOWNLOAD_DIR" "$PLGX_CACHE_HOME"
# 确认 PLGX 预编译器源码存在。
test -f "$PLGX_PRECOMPILER_SOURCE"

# 下载 GitHub 当前正式 Release 的 KeePassOTP 插件。
"$SCRIPT_DIR/../Common/github/download_tagged_release_asset.sh" --latest Rookiestyle/KeePassOTP KeePassOTP.plgx "$PLGX_DOWNLOAD_DIR/KeePassOTP.plgx"
# 下载 GitHub 当前正式 Release 的 GlobalSearch 插件。
"$SCRIPT_DIR/../Common/github/download_tagged_release_asset.sh" --latest Rookiestyle/GlobalSearch GlobalSearch.plgx "$PLGX_DOWNLOAD_DIR/GlobalSearch.plgx"

# shellcheck source=patches/prepare_plugins.sh
# 本程序专属处理：预编译功能插件和 Mono 兼容补丁。
source "$SCRIPT_DIR/patches/prepare_plugins.sh"

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"

# 本程序专属处理：设置 KeePass 窗口标识。
export STARTUPWMCLASS=keepass
# 使用系统里装好的图标。
export ICON=/usr/share/icons/hicolor/1024x1024/apps/keepass.png
# 使用系统里装好的桌面入口文件。
export DESKTOP=/usr/share/applications/keepass.desktop
# 把 AppImage 写到仓库根目录的 dist。
export OUTPATH=./dist
# 固定最终 AppImage 的文件名。
export OUTNAME="keepass.AppImage"

# 检查 KeePass 目录中的简体中文语言文件
test -f "$SCRIPT_DIR/Chinese_Simplified.lngx" || {
  echo "Error: $SCRIPT_DIR/Chinese_Simplified.lngx not found."
  exit 1
}

# 收集程序及其运行依赖。
quick-sharun /usr/bin/keepass /usr/bin/mono* /etc/mono /usr/lib/mono /usr/lib/libMono*.so /usr/lib/libmono*.so /usr/lib/lib*sharpglue-2.so* /usr/lib/libdbus-glib-1.so* /usr/lib/libgtk-x11-2.0.so* /usr/lib/libgdk-x11-2.0.so* /usr/lib/gtk-2.0 /usr/lib/libgtk-3.so* /usr/lib/libgdk-3.so* /usr/lib/gtk-3.0 /usr/lib/libappindicator*.so* /usr/lib/libdbusmenu*.so* /usr/lib/libnotify.so* /usr/lib/libgdk_pixbuf-2.0.so* /usr/lib/librsvg-2.so* /usr/lib/libargon2.so* /usr/lib/libgcrypt.so* /usr/lib/libgpg-error.so* /usr/share/keepass /usr/share/themes/Materia-light /usr/share/icons/hicolor

# shellcheck source=patches/prepare_appdir.sh
# 本程序专属处理：部署语言、字体和运行配置，检查包内依赖并写入两个启动脚本。
source "$SCRIPT_DIR/patches/prepare_appdir.sh"

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../Common/build/save_appimage_version.sh" "dist/keepass.AppImage" "$VERSION" dist/version.txt
