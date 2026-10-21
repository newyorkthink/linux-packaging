#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 使用公共工作区入口统一设置路径、检查架构，并清理、重建标准构建目录。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" baidunetdisk

DEB_FILE="$SOURCE_DIR/baidunetdisk.deb"
APP_ROOT="$APPDIR/opt/baidunetdisk"

###### 准备构建环境 ######

# 通过公共 APT 入口安装 GTK3 插件、百度网盘运行时和当前脚本明确需要的依赖。
"$SCRIPT_DIR/../common/apt/install_packages.sh" \
  dpkg-dev pkgconf \
  libglib2.0-bin libglib2.0-dev libgirepository1.0-dev \
  libgtk-3-bin libgtk-3-dev libgdk-pixbuf2.0-bin libgdk-pixbuf-2.0-dev \
  librsvg2-dev librsvg2-common libpango1.0-dev \
  ibus-gtk3 libibus-1.0-5 \
  libasound2 libatk1.0-0 libatk-bridge2.0-0 libatspi2.0-0 libcairo2 libcups2 \
  libdbus-1-3 libdrm2 libgbm1 libgdk-pixbuf-2.0-0 libglib2.0-0 libgtk-3-0 \
  libgtkmm-2.4-1v5 libnotify4 libnss3 libnspr4 libpango-1.0-0 libsecret-1-0 \
  libappindicator3-1 \
  libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 \
  libxfixes3 libxi6 libxkbcommon0 libxrandr2 libxrender1 libxss1 libxtst6 \
  xdg-utils shared-mime-info hicolor-icon-theme

###### 下载打包工具 ######

# 动态取得 linuxdeploy、带 GIO 修复的 GTK 插件、appimagetool 和 Type 2 runtime。
"$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" gtk

###### 初始化 AppDir ######

# 通过公共入口运行第一次普通 linuxdeploy，只创建空 AppDir 基础目录。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

###### 下载并准备百度网盘 ######

# 公共 JSON DEB 下载入口负责元数据读取、URL / 文件名 / DEB 元数据校验和实际下载；
# 百度 API、字段、域名、资产名、包名与架构约束作为当前应用参数传入。
VERSION="$("$SCRIPT_DIR/../common/download/download_json_deb_asset.sh" \
  'https://pan.baidu.com/disk/cmsdata?do=client' \
  '.linux.version | sub("^百度网盘Linux电脑客户端"; "") | sub("^V"; "")' \
  '.linux.url_1' \
  '^https://([[:alnum:]-]+[.])+(baidu[.]com|baidupcs[.]com)/' \
  'baidunetdisk_{version}_amd64.deb' \
  baidunetdisk amd64 "$DEB_FILE")"

# 把同一官方 DEB 安装到隔离构建环境供依赖扫描，并由公共入口按上游布局解包到 AppDir。
"$SCRIPT_DIR/../common/apt/install_packages.sh" --no-update "$DEB_FILE"
"$SCRIPT_DIR/../common/archive/extract_archive.sh" "$DEB_FILE" "$APPDIR"

# 通过公共 APT 入口下载并解包 Ubuntu 22.04 的 Adwaita 图标与 GTK 主题包。
"$SCRIPT_DIR/../common/apt/download_and_extract_packages.sh" "$APPDIR" \
  adwaita-icon-theme adwaita-icon-theme-full gnome-themes-extra-data

# 规范官方 desktop 条目，并保留上游已经使用的 --no-sandbox 与 URI 参数。
DESKTOP_FILE="$(find "$APPDIR/usr/share/applications" -maxdepth 1 -type f -name 'baidunetdisk.desktop' -print -quit)"
sed -i \
  -e 's|^Exec=.*|Exec=baidunetdisk --no-sandbox %U|' \
  -e 's|^Icon=.*|Icon=baidunetdisk|' \
  -e '/^Encoding=/d' \
  -e '/^Value=/d' \
  -e 's/^Terminal=0$/Terminal=false/' \
  "$DESKTOP_FILE"

# 选取官方包中实际存在的百度网盘图标交给 linuxdeploy。
ICON_FILE="$(find "$APPDIR/usr/share/icons" "$APP_ROOT" \
  -type f \( -iname 'baidunetdisk.png' -o -iname 'baidunetdisk.svg' \) \
  -printf '%s\t%p\n' 2>/dev/null | sort -n | tail -n 1 | cut -f2-)"

###### 准备兼容运行库 ######

# NSS 核心库和 dlopen 模块必须来自同一套 Ubuntu 22.04 libnss3；复制清单由公共入口统一维护。
"$SCRIPT_DIR/../common/linuxdeploy/copy_nss_runtime.sh" "$APPDIR/usr/lib"

# 百度网盘通过 Koffi 动态加载 GTKmm 2.4，并按上游依赖推荐使用 AppIndicator。
MULTIARCH="$(dpkg-architecture -qDEB_HOST_MULTIARCH)"
GTKMM2_LIB="/usr/lib/$MULTIARCH/libgtkmm-2.4.so.1"
APPINDICATOR_LIB="/usr/lib/$MULTIARCH/libappindicator3.so.1"

###### 核心打包 ######

# 最终 AppImage 已解包确认目录，直接写入包含准确路径的完整根 AppRun。
# GTK linuxdeploy 会自动把它保存为 AppRun.wrapped，并生成加载 GTK hook 的顶层 AppRun。
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash
set -Eeuo pipefail

HERE="$(dirname "$(readlink -f "${0}")")"

# 保留三个 linuxdeploy 基础目录，并把百度网盘真实程序目录加入对应变量。
export PATH="$HERE/opt/baidunetdisk:$HERE/usr/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$HERE/opt/baidunetdisk:$HERE/usr/lib:$HERE/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$HERE/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
export GSETTINGS_SCHEMA_DIR="$HERE/usr/share/glib-2.0/schemas${GSETTINGS_SCHEMA_DIR:+:$GSETTINGS_SCHEMA_DIR}"
export GIO_MODULE_DIR="$HERE/usr/lib/x86_64-linux-gnu/gio/modules"

exec "$HERE/opt/baidunetdisk/baidunetdisk" --no-sandbox "$@"
APPRUN
chmod +x "$APPDIR/AppRun"

# 公共入口配置 linuxdeploy 通用环境；GTK3 和精确动态库仍由当前项目追加。
source "$SCRIPT_DIR/../common/linuxdeploy/configure_environment.sh" \
  "$TOOLS_DIR" "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"

# 百度网盘使用 GTK3；第二次 linuxdeploy 部署 GTK 资源、精确动态库并完成 AppRun 包装。
export DEPLOY_GTK_VERSION=3
export ARCH=x86_64; linuxdeploy \
  --appdir AppDir \
  --desktop-file "$DESKTOP_FILE" \
  --icon-file "$ICON_FILE" \
  -l "$GTKMM2_LIB" \
  -l "$APPINDICATOR_LIB" \
  --plugin gtk \
  --output appimage

###### 整理产物 ######

# 忽略 linuxdeploy 中间 AppImage；公共入口负责正式封装、产物检查、SHA-256 和成功后的版本元数据。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" \
  "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
