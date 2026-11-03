#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 本仓库兼容处理：为 AUR 当前 DEB 配置官方备用下载域名。
SOURCE_FALLBACK_ORIGIN=https://update.todesk.com

# 安装 AUR 软件包、运行依赖及 DEB 解包工具。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --aur-deb todesk-bin "$(uname -m)" --downloader aria2c --wayback --fallback-origin "$SOURCE_FALLBACK_ORIGIN" -- aria2 fcitx5-gtk dpkg pulseaudio xcb-util xcb-util-keysyms xcb-util-wm xcb-util-image xcb-util-renderutil xcb-util-cursor libpipewire

# 清掉上次的打包目录。
"$SCRIPT_DIR/../common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create work AppDir dist
mkdir -p AppDir/bin work

# 下载官方当前 DEB。
"$SCRIPT_DIR/../common/aur/download_deb_source.sh" \
  todesk-bin "$(uname -m)" work/todesk.deb \
  --downloader aria2c --wayback --fallback-origin "$SOURCE_FALLBACK_ORIGIN" --deb --version-file work/source-version.txt --package-version-file work/package-version.txt

# 解包官方 DEB。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" work/todesk.deb work/todesk-unpacked

# 整个程序目录原样放进 AppDir/bin。
cp -a work/todesk-unpacked/opt/todesk AppDir/bin/

# 本仓库兼容处理：补回配置目录、核对运行组件，并准备便携桌面入口。
bash "$SCRIPT_DIR/patches/prepare_appdir.sh" "$SCRIPT_DIR/AppDir/bin/todesk" /usr/share/applications/todesk.desktop work/todesk.desktop

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 成品里的应用名。
export APPNAME=ToDesk
# 包里的真实程序名。
export MAIN_BIN=ToDesk
# 让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS=ToDesk
# 使用系统里装好的图标。
export ICON=/usr/share/icons/hicolor/512x512/apps/todesk.png
# 使用系统里装好的桌面入口文件。
export DESKTOP="$SCRIPT_DIR/work/todesk.desktop"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME=todesk.AppImage
# 这是 GTK 3 程序。输入模块由 quick-sharun 自己收集。
export DEPLOY_GTK=1
# 本仓库兼容处理：保持闭源二进制和官方私有库原样。
export NO_STRIP=1
# 本仓库兼容处理：收集路径映射运行库，运行时由专属 hook 指向可写目录。
export PATH_MAPPING='/opt/todesk:${SHARUN_DIR}/bin/todesk'

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" text work/source-version.txt)"

# 收集程序及其运行依赖。
LD_LIBRARY_PATH="$SCRIPT_DIR/AppDir/bin/todesk/bin${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" quick-sharun AppDir/bin/* AppDir/bin/todesk/bin/ToDesk AppDir/bin/todesk/bin/ToDesk_Service AppDir/bin/todesk/bin/ToDesk_Session AppDir/bin/todesk/bin/CrashReport /usr/bin/pulseaudio /usr/lib/libappindicator3.so.1 /usr/lib/libdbusmenu-glib.so.4 /usr/lib/libdbusmenu-gtk3.so.4

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
ENV

# 本仓库兼容处理：核对四个便携入口与运行副本需要的真实程序都已收集。
for binary in ToDesk ToDesk_Service ToDesk_Session CrashReport; do
  [[ -x "AppDir/bin/$binary" && -x "AppDir/shared/bin/$binary" ]] || {
    echo "错误：缺少 ToDesk 包内入口或真实程序：$binary" >&2
    exit 1
  }
done

# 本仓库兼容处理：保存完整包版本，沿用升级时刷新程序副本并保留配置的判断。
mkdir -p AppDir/share/todesk-appimage
install -m 644 work/package-version.txt AppDir/share/todesk-appimage/package-version
# 本仓库兼容处理：保留多入口、可写配置目录和固定路径映射。
install -m 755 "$SCRIPT_DIR/patches/90-todesk-runtime.hook" AppDir/bin/90-todesk-runtime.hook

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" dist/todesk.AppImage "$VERSION" dist/version.txt
