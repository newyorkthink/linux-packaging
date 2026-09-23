#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 使用公共工作区入口统一设置路径，并清理、重建标准构建目录。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" binance

DEB_FILE="$SOURCE_DIR/binance.deb"

###### 准备构建环境 ######

# 通过公共 APT 入口安装 GTK3 插件、Binance 官方 Depends 和主程序直接链接的运行库。
"$SCRIPT_DIR/../common/apt/install_packages.sh" \
  dpkg-dev pkgconf \
  libglib2.0-bin libglib2.0-dev libgirepository1.0-dev \
  libgtk-3-bin libgtk-3-dev libgdk-pixbuf2.0-bin libgdk-pixbuf-2.0-dev \
  librsvg2-dev librsvg2-common libpango1.0-dev \
  ibus-gtk3 libibus-1.0-5 \
  libasound2 libatk1.0-0 libatk-bridge2.0-0 libatspi2.0-0 libcairo2 libcups2 \
  libdbus-1-3 libdrm2 libexpat1 libgbm1 libgdk-pixbuf-2.0-0 libglib2.0-0 \
  libgtk-3-0 libnotify4 libnotify-dev libnspr4 libnss3 libpango-1.0-0 \
  libsecret-1-0 libuuid1 libxss1 libxtst6 \
  libx11-6 libxcb1 libxcomposite1 libxdamage1 libxext6 libxfixes3 \
  libxkbcommon0 libxrandr2 \
  xdg-utils shared-mime-info hicolor-icon-theme

###### 下载打包工具 ######

# 动态取得 linuxdeploy、GTK 插件、appimagetool 和 Type 2 runtime，并记录可用摘要。
"$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" gtk

###### 初始化 AppDir ######

# 通过公共入口运行第一次普通 linuxdeploy，只创建空 AppDir 基础目录。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

###### 下载并准备 Binance ######

# 公共入口选择正式 semver Release、核对唯一 Linux amd64 DEB 与官方摘要，并下载同一资产。
VERSION="$("$SCRIPT_DIR/../common/github/download_latest_stable_release_asset.sh" \
  "binance/desktop" 'binance-{version}-amd64-linux.deb' "$DEB_FILE" binance amd64)"

# 把同一官方 DEB 安装到隔离构建环境供依赖扫描，并由公共入口按上游布局解包到 AppDir。
"$SCRIPT_DIR/../common/apt/install_packages.sh" --no-update "$DEB_FILE"
"$SCRIPT_DIR/../common/archive/extract_archive.sh" "$DEB_FILE" "$APPDIR"

# 通过公共 APT 入口下载并解包 Ubuntu 22.04 的 Adwaita 图标与 GTK 主题包。
"$SCRIPT_DIR/../common/apt/download_and_extract_packages.sh" "$APPDIR" \
  adwaita-icon-theme adwaita-icon-theme-full gnome-themes-extra-data

# 规范官方 desktop 条目，避免 Exec 指向宿主机绝对路径。
DESKTOP_FILE="$(find "$APPDIR/usr/share/applications" -maxdepth 1 -type f -name 'binance.desktop' -print -quit)"
sed -i -e 's|^Exec=.*|Exec=binance %U|' -e 's|^Icon=.*|Icon=binance|' "$DESKTOP_FILE"
ICON_FILE="$APPDIR/usr/share/icons/hicolor/512x512/apps/binance.png"

###### 准备兼容运行库 ######

# NSS 核心库和 dlopen 模块必须来自同一套 Ubuntu 22.04 libnss3；复制清单由公共入口统一维护。
"$SCRIPT_DIR/../common/linuxdeploy/copy_nss_runtime.sh" "$APPDIR/usr/lib"

# keytar.node 直接链接 libsecret；主程序按文件名 dlopen libnotify.so。二者都不会出现在主程序 NEEDED 中。
MULTIARCH="$(dpkg-architecture -qDEB_HOST_MULTIARCH)"
LIBSECRET_LIB="/usr/lib/$MULTIARCH/libsecret-1.so.0"
LIBNOTIFY_LIB="/usr/lib/$MULTIARCH/libnotify.so"

###### 核心打包 ######

# 目录尚未由成品确认，先写入包含基础路径的完整根 AppRun，再由公共脚本按最终 AppDir 整理。
# GTK linuxdeploy 若生成 hook，会把这份 AppRun 保存为 AppRun.wrapped。
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash
set -Eeuo pipefail

HERE="$(dirname "$(readlink -f "${0}")")"

# 保留三个 linuxdeploy 基础目录，并仅把 Binance 的真实程序目录加入对应变量。
export PATH="$HERE/opt/Binance:$HERE/usr/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$HERE/opt/Binance:$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$HERE/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
export GSETTINGS_SCHEMA_DIR="$HERE/usr/share/glib-2.0/schemas${GSETTINGS_SCHEMA_DIR:+:$GSETTINGS_SCHEMA_DIR}"
export GIO_MODULE_DIR="$HERE/usr/lib/x86_64-linux-gnu/gio/modules"

exec "$HERE/opt/Binance/binance" "$@"
APPRUN
chmod +x "$APPDIR/AppRun"

# 公共入口配置 linuxdeploy 通用环境；GTK3 和精确动态库仍由当前项目追加。
source "$SCRIPT_DIR/../common/linuxdeploy/configure_environment.sh" \
  "$TOOLS_DIR" "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"

# Binance 主程序链接 GTK3；第二次 linuxdeploy 部署 GTK 资源、精确动态库并完成 AppRun 包装。
export DEPLOY_GTK_VERSION=3
export ARCH=x86_64; linuxdeploy \
  --appdir AppDir \
  --desktop-file "$DESKTOP_FILE" \
  --icon-file "$ICON_FILE" \
  -l "$LIBSECRET_LIB" \
  -l "$LIBNOTIFY_LIB" \
  --plugin gtk \
  --output appimage

# 成品目录尚未确认，只整理现有路径型 export，不改 exec 或补 hook。
"$SCRIPT_DIR/../common/linuxdeploy/normalize_apprun_paths.sh" "$APPDIR"

###### 整理产物 ######

# 忽略 linuxdeploy 中间 AppImage；公共入口负责正式封装、产物检查、SHA-256 和成功后的版本元数据。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" \
  "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
