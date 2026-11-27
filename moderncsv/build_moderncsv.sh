#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" --base
# 安装运行依赖及 DEB 解包工具。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" dpkg fontconfig gtk3 libcups libglvnd libunwind libx11 libxcb libxkbcommon-x11 mesa wayland xcb-util xcb-util-cursor xcb-util-image xcb-util-keysyms xcb-util-renderutil xcb-util-wm

# 清掉上次的打包目录。
"$SCRIPT_DIR/../Common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir dist work

# 下载官方当前 DEB。
"$SCRIPT_DIR/../Common/download/download_apt_repository_deb.sh" https://www.moderncsv.com/release/apt stable main moderncsv amd64 https://www.moderncsv.com/release/apt/public.key work/app.deb work/source-version.txt

# 解包官方 DEB。
"$SCRIPT_DIR/../Common/archive/extract_archive.sh" work/app.deb work/unpacked

# 本程序专属处理：保留官方自带 Qt 运行时与原生插件目录。
SOURCE_DIR="$SCRIPT_DIR/work/unpacked/opt/moderncsv"

# 本程序专属处理：从 Debian 签名 APT 仓库下载并解包同代 Fcitx5 Qt 6 组件。
for pkg in fcitx5-frontend-qt6 libfcitx5-qt6-1 libfcitx5utils2; do
  # 本程序专属处理：验签下载当前 Fcitx5 兼容 DEB。
  "$SCRIPT_DIR/../Common/download/download_apt_repository_deb.sh" https://deb.debian.org/debian trixie main "$pkg" amd64 https://ftp-master.debian.org/keys/archive-key-13.asc "work/${pkg}.deb" "work/${pkg}.version"
  # 本程序专属处理：解包当前 Fcitx5 兼容 DEB。
  "$SCRIPT_DIR/../Common/archive/extract_archive.sh" "work/${pkg}.deb" "work/${pkg}"
done
# 本程序专属处理：补入 Fcitx5 Qt 6 输入法插件。
cp -a work/fcitx5-frontend-qt6/usr/lib/x86_64-linux-gnu/qt6/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so "$SOURCE_DIR/plugins/platforminputcontexts/"
# 本程序专属处理：补入 Fcitx5 Qt 6 D-Bus 运行库及完整符号链接链。
cp -a work/libfcitx5-qt6-1/usr/lib/x86_64-linux-gnu/libFcitx5Qt6DBusAddons.so.* "$SOURCE_DIR/lib/"
# 本程序专属处理：补入 Fcitx5 基础工具运行库及完整符号链接链。
cp -a work/libfcitx5utils2/usr/lib/x86_64-linux-gnu/libFcitx5Utils.so.* "$SOURCE_DIR/lib/"

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 成品里的应用名。
export APPNAME="Modern CSV"
# 包里的真实程序名。
export MAIN_BIN=moderncsv
# 让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS=moderncsv
# 使用官方 DEB 提供的图标。
export ICON="$SCRIPT_DIR/work/unpacked/usr/share/pixmaps/moderncsv.png"
# 使用官方 DEB 提供的桌面入口文件。
export DESKTOP="$SCRIPT_DIR/work/unpacked/usr/share/applications/moderncsv.desktop"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME=moderncsv.AppImage
# 本程序专属处理：部署官方自带目录中的 Qt 插件。
export DEPLOY_QT=1
# 本程序专属处理：保留原有的 OpenGL 部署设置。
export DEPLOY_OPENGL=1
# 本程序专属处理：指定官方自带 Qt 目录，避免混入系统 Qt。
export QT_LOCATION="$SOURCE_DIR"

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../Common/build/read_app_version.sh" text work/source-version.txt)"

# 收集程序及其运行依赖。
LD_LIBRARY_PATH="$SOURCE_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" quick-sharun "$SOURCE_DIR/moderncsv" "$SOURCE_DIR/lib/libFcitx5Qt6DBusAddons.so.1" "$SOURCE_DIR/lib/libFcitx5Utils.so.2" /usr/lib/libssl.so.3 /usr/lib/libcrypto.so.3

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
ENV

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../Common/build/save_appimage_version.sh" dist/moderncsv.AppImage "$VERSION" dist/version.txt
