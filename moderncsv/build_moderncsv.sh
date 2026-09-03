#!/usr/bin/env bash
set -e

SOURCE_DIR="$PWD/moderncsv-source"
COMPAT_DIR="/tmp/moderncsv-qt6-compat"

rm -rf AppDir dist "$SOURCE_DIR" "$COMPAT_DIR" || true

ARCH="$(uname -m)"
export ARCH

export STARTUPWMCLASS=moderncsv
export ICON="$SOURCE_DIR/moderncsv.png"
export DESKTOP="$SOURCE_DIR/moderncsv.desktop"
export OUTPATH=./dist
export OUTNAME="moderncsv.AppImage"
export DEPLOY_OPENGL=1
export QT_LOCATION="$SOURCE_DIR"

###### 准备构建环境 ######

# 安装 quick-sharun / AppImage 打包所需的通用最小基础工具。
yay -S --noconfirm base-devel git wget curl jq binutils patchelf file coreutils findutils \
  grep sed gawk tar gzip xz unzip rsync util-linux appstream-glib \
  desktop-file-utils zsync ca-certificates

# 安装 Modern CSV 官方 Qt6 运行时实际需要的非 Qt 系统依赖，不混入通用基础包。
yay -S --noconfirm openssl mesa libglvnd libxkbcommon-x11 xcb-util xcb-util-cursor xcb-util-image xcb-util-keysyms xcb-util-renderutil xcb-util-wm xdg-utils fontconfig

mkdir -p "$SOURCE_DIR" "$COMPAT_DIR" ./dist

###### 下载上游文件 ######

# 下载并完整提取官方 Linux tar 包，保留官方 Qt 6.4.3 runtime。
wget --retry-connrefused --tries=30 \
  https://www.moderncsv.com/release/ModernCSV-Linux-v2.4.3.tar.gz \
  -O /tmp/ModernCSV-Linux.tar.gz

tar -xzf /tmp/ModernCSV-Linux.tar.gz -C "$SOURCE_DIR" --strip-components=1

###### 准备兼容的 Qt6 插件 ######

# 保存官方 Qt6 XCB platform plugin，删除官方 tar 中其余仍链接 Qt5 的 plugin。
cp -a "$SOURCE_DIR/plugins/platforms/libqxcb.so" /tmp/moderncsv-libqxcb.so
rm -rf "$SOURCE_DIR/plugins"
mkdir -p "$SOURCE_DIR/plugins/platforms" "$SOURCE_DIR/plugins/platforminputcontexts" "$SOURCE_DIR/plugins/tls"
cp -a /tmp/moderncsv-libqxcb.so "$SOURCE_DIR/plugins/platforms/libqxcb.so"

# 下载与官方 Qt 6.4.3 runtime 同一 Qt 6.4 系列的 Debian Bookworm Qt6 / Fcitx5 兼容组件。
wget --retry-connrefused --tries=30 \
  https://deb.debian.org/debian/pool/main/q/qt6-base/libqt6gui6_6.4.2+dfsg-10_amd64.deb \
  -O /tmp/libqt6gui6.deb

wget --retry-connrefused --tries=30 \
  https://deb.debian.org/debian/pool/main/q/qt6-base/libqt6network6_6.4.2+dfsg-10_amd64.deb \
  -O /tmp/libqt6network6.deb

wget --retry-connrefused --tries=30 \
  https://deb.debian.org/debian/pool/main/f/fcitx5-qt/fcitx5-frontend-qt6_5.0.16-1+b3_amd64.deb \
  -O /tmp/fcitx5-frontend-qt6.deb

wget --retry-connrefused --tries=30 \
  https://deb.debian.org/debian/pool/main/f/fcitx5-qt/libfcitx5-qt6-1_5.0.16-1+b3_amd64.deb \
  -O /tmp/libfcitx5-qt6-1.deb

wget --retry-connrefused --tries=30 \
  https://deb.debian.org/debian/pool/main/f/fcitx5/libfcitx5utils2_5.0.21-3_amd64.deb \
  -O /tmp/libfcitx5utils2.deb

extract_deb() {
  local deb_file="$1"
  local dest_dir="$2"
  local data_member

  data_member="$(ar t "$deb_file" | awk '/^data[.]tar[.]/ {print; exit}')"
  mkdir -p "$dest_dir"
  ar p "$deb_file" "$data_member" | bsdtar -xf - -C "$dest_dir"
}

extract_deb /tmp/libqt6gui6.deb "$COMPAT_DIR/libqt6gui6"
extract_deb /tmp/libqt6network6.deb "$COMPAT_DIR/libqt6network6"
extract_deb /tmp/fcitx5-frontend-qt6.deb "$COMPAT_DIR/fcitx5-frontend-qt6"
extract_deb /tmp/libfcitx5-qt6-1.deb "$COMPAT_DIR/libfcitx5-qt6-1"
extract_deb /tmp/libfcitx5utils2.deb "$COMPAT_DIR/libfcitx5utils2"

# 补入 Qt 6.4.2 Compose / IBus 输入上下文、Fcitx5 Qt6 输入上下文和 TLS backend。
cp -a "$COMPAT_DIR/libqt6gui6/usr/lib/x86_64-linux-gnu/qt6/plugins/platforminputcontexts/." \
  "$SOURCE_DIR/plugins/platforminputcontexts/"
cp -a "$COMPAT_DIR/fcitx5-frontend-qt6/usr/lib/x86_64-linux-gnu/qt6/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so" \
  "$SOURCE_DIR/plugins/platforminputcontexts/"
cp -a "$COMPAT_DIR/libqt6network6/usr/lib/x86_64-linux-gnu/qt6/plugins/tls/." \
  "$SOURCE_DIR/plugins/tls/"

# 补入 Fcitx5 Qt6 输入插件所需运行库的完整 SONAME 链，避免只复制符号链接而丢失真实版本文件。
cp -a "$COMPAT_DIR/libfcitx5-qt6-1/usr/lib/x86_64-linux-gnu/"libFcitx5Qt6DBusAddons.so.* \
  "$SOURCE_DIR/lib/"
cp -a "$COMPAT_DIR/libfcitx5utils2/usr/lib/x86_64-linux-gnu/"libFcitx5Utils.so.* \
  "$SOURCE_DIR/lib/"

###### 核心打包 ######

# 构建期仅让动态链接器从官方 Qt 6.4.3 lib 目录解析显式 Fcitx5 输入依赖，避免误用构建机 Qt。
LD_LIBRARY_PATH="$SOURCE_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
quick-sharun \
  "$SOURCE_DIR/moderncsv" \
  "$SOURCE_DIR/lib/libFcitx5Qt6DBusAddons.so.1" \
  "$SOURCE_DIR/lib/libFcitx5Utils.so.2"

quick-sharun --make-appimage
