#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" --base
# 安装运行依赖及 DEB 解包工具。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" dpkg fontconfig libglvnd libunwind libx11 libxcb libxkbcommon-x11 mesa xcb-util xcb-util-cursor xcb-util-image xcb-util-keysyms xcb-util-renderutil xcb-util-wm

# 清掉上次的打包目录。
"$SCRIPT_DIR/../Common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir dist work

# 下载归档中与模板匹配的最高版本官方 TAR。
"$SCRIPT_DIR/../Common/github/download_tagged_release_asset.sh" newyorkthink/linux-packaging original-package-archive 'ModernCSV-Linux-v{version}.tar.gz' work/app.tar.gz > work/source-version.txt

# 解包官方 TAR。
"$SCRIPT_DIR/../Common/archive/extract_archive.sh" work/app.tar.gz work/unpacked

# 本程序专属处理：定位官方可执行文件所在目录，保留自带 Qt 运行时。
SOURCE_BIN="$(find "$SCRIPT_DIR/work/unpacked" -type f -name moderncsv -executable -print -quit)"
if [[ -z "$SOURCE_BIN" ]]; then
  printf '错误：官方归档中没有可执行的 moderncsv。\n' >&2
  exit 1
fi
SOURCE_DIR="$(dirname -- "$SOURCE_BIN")"

# 本程序专属处理：先留存官方 Qt 6 XCB 插件，再移除原插件目录中的 Qt 5 插件。
cp -p -- "$SOURCE_DIR/plugins/platforms/libqxcb.so" work/libqxcb.so
rm -rf -- "$SOURCE_DIR/plugins"
mkdir -p "$SOURCE_DIR/plugins/"{platforms,platforminputcontexts,tls,styles}
mv -- work/libqxcb.so "$SOURCE_DIR/plugins/platforms/"

# 本程序专属处理：从 Debian Bookworm 签名仓库补齐同一 Qt 次版本的插件和配套库。
for pkg in libqt6gui6 libqt6network6 fcitx5-frontend-qt6 libfcitx5-qt6-1 libfcitx5utils2 adwaita-qt6 libadwaitaqt6-1 libadwaitaqt6priv1; do
  # 本程序专属处理：验签下载当前兼容 DEB。
  "$SCRIPT_DIR/../Common/download/download_apt_repository_deb.sh" https://deb.debian.org/debian bookworm main "$pkg" amd64 https://ftp-master.debian.org/keys/archive-key-12.asc "work/${pkg}.deb" "work/${pkg}.version"
  # 本程序专属处理：解包当前兼容 DEB。
  "$SCRIPT_DIR/../Common/archive/extract_archive.sh" "work/${pkg}.deb" "work/${pkg}"
done
BOOKWORM_LIB=usr/lib/x86_64-linux-gnu
BOOKWORM_PLUGINS="$BOOKWORM_LIB/qt6/plugins"
# 本程序专属处理：补入 Qt 6 的 Compose 和 IBus 输入插件。
cp -a "work/libqt6gui6/$BOOKWORM_PLUGINS/platforminputcontexts"/lib{compose,ibus}platforminputcontextplugin.so \
  "$SOURCE_DIR/plugins/platforminputcontexts/"
# 本程序专属处理：补入 Fcitx5 Qt 6 输入法插件。
cp -a "work/fcitx5-frontend-qt6/$BOOKWORM_PLUGINS/platforminputcontexts/libfcitx5platforminputcontextplugin.so" \
  "$SOURCE_DIR/plugins/platforminputcontexts/"
# 本程序专属处理：补入 Fcitx5 Qt 6 D-Bus 运行库及完整符号链接链。
cp -a "work/libfcitx5-qt6-1/$BOOKWORM_LIB"/libFcitx5Qt6DBusAddons.so.* "$SOURCE_DIR/lib/"
# 本程序专属处理：补入 Fcitx5 基础工具运行库及完整符号链接链。
cp -a "work/libfcitx5utils2/$BOOKWORM_LIB"/libFcitx5Utils.so.* "$SOURCE_DIR/lib/"
# 本程序专属处理：补入 Qt 6 的证书和 OpenSSL TLS 后端。
cp -a "work/libqt6network6/$BOOKWORM_PLUGINS/tls"/libq{certonly,openssl}backend.so "$SOURCE_DIR/plugins/tls/"
# 本程序专属处理：补入 Adwaita Qt 6 样式及两个运行库的完整符号链接链。
cp -a "work/adwaita-qt6/$BOOKWORM_PLUGINS/styles/adwaita.so" "$SOURCE_DIR/plugins/styles/"
cp -a "work/libadwaitaqt6-1/$BOOKWORM_LIB"/libadwaitaqt6.so.* "$SOURCE_DIR/lib/"
cp -a "work/libadwaitaqt6priv1/$BOOKWORM_LIB"/libadwaitaqt6priv.so.* "$SOURCE_DIR/lib/"

# 本程序专属处理：让桌面入口通过图标名查找应用图标，避免依赖宿主安装路径。
sed -i 's|^Icon=/opt/moderncsv/moderncsv\.png$|Icon=moderncsv|' "$SOURCE_DIR/moderncsv.desktop"

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 成品里的应用名。
export APPNAME="Modern CSV"
# 包里的真实程序名。
export MAIN_BIN=moderncsv
# 让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS=moderncsv
# 使用官方 TAR 提供的图标。
export ICON="$SOURCE_DIR/moderncsv.png"
# 使用官方 TAR 提供的桌面入口文件。
export DESKTOP="$SOURCE_DIR/moderncsv.desktop"
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
LD_LIBRARY_PATH="$SOURCE_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" quick-sharun "$SOURCE_DIR/moderncsv" "$SOURCE_DIR/lib/libFcitx5Qt6DBusAddons.so.1" "$SOURCE_DIR/lib/libFcitx5Utils.so.2" "$SOURCE_DIR/lib/libadwaitaqt6.so.1" "$SOURCE_DIR/lib/libadwaitaqt6priv.so.1" /usr/lib/libssl.so.3 /usr/lib/libcrypto.so.3

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
QT_STYLE_OVERRIDE=Adwaita-Dark
ENV

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../Common/build/save_appimage_version.sh" dist/moderncsv.AppImage "$VERSION" dist/version.txt
