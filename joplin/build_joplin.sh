#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 输出明确错误并立即终止构建。
die() {
  echo "错误：$*" >&2
  exit 1
}

[[ "$(uname -m)" == x86_64 ]] || die "当前仅支持 x86_64"

# 使用公共工作区入口统一设置路径，并清理、重建标准构建目录。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" joplin

DEB_FILE="$SOURCE_DIR/joplin.deb"
THEME_DEB_DIR="$SOURCE_DIR/theme-debs"

###### 准备构建环境 ######

# 通过公共 APT 入口安装 GTK3 插件、Joplin 运行时和当前脚本明确需要的依赖。
"$SCRIPT_DIR/../common/apt/install_packages.sh" \
  desktop-file-utils dpkg-dev pkgconf \
  libglib2.0-bin libglib2.0-dev libgirepository1.0-dev \
  libgtk-3-bin libgtk-3-dev libgdk-pixbuf2.0-bin libgdk-pixbuf-2.0-dev \
  librsvg2-dev librsvg2-common libpango1.0-dev \
  ibus-gtk3 libibus-1.0-5 \
  libasound2 libatk1.0-0 libatk-bridge2.0-0 libatspi2.0-0 libcairo2 libcups2 \
  libdbus-1-3 libdrm2 libgbm1 libgdk-pixbuf-2.0-0 libglib2.0-0 libgtk-3-0 \
  libnotify4 libnspr4 libnss3 libpango-1.0-0 libsecret-1-0 libuuid1 \
  libappindicator3-1 \
  libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 \
  libxfixes3 libxi6 libxinerama1 libxkbcommon0 libxrandr2 libxrender1 \
  libxshmfence1 libxss1 libxtst6 \
  xdg-utils shared-mime-info hicolor-icon-theme

###### 下载打包工具 ######

# 动态取得 linuxdeploy、GTK 插件、appimagetool 和 Type 2 runtime，并记录可用摘要。
"$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" gtk

###### 初始化 AppDir ######

# 通过公共入口运行第一次普通 linuxdeploy，只创建空 AppDir 基础目录。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

###### 下载并准备 Joplin ######

# 通过公共入口读取正式 semver Release，并解析唯一的 Linux x64 DEB 与官方摘要。
mapfile -t RELEASE_META < <(
  "$SCRIPT_DIR/../common/github/resolve_latest_stable_release_asset.sh" \
    "laurent22/joplin" \
    'Joplin-{version}.deb'
)
[[ ${#RELEASE_META[@]} -eq 3 ]] || die "无法解析唯一的 Joplin 正式版 DEB 元数据"

VERSION="${RELEASE_META[0]}"
DEB_URL="${RELEASE_META[1]}"
EXPECTED_SHA256="${RELEASE_META[2]}"
printf 'Joplin version: %s\n' "$VERSION"

# 下载并校验本次实际安装、解包的同一份官方 DEB。
"$SCRIPT_DIR/../common/download/download_file.sh" "$DEB_URL" "$DEB_FILE" "$EXPECTED_SHA256"

# 把同一官方 DEB 安装到隔离构建环境供依赖扫描，并由公共入口按上游布局解包到 AppDir。
"$SCRIPT_DIR/../common/apt/install_packages.sh" --no-update "$DEB_FILE"
"$SCRIPT_DIR/../common/archive/extract_archive.sh" "$DEB_FILE" "$APPDIR"
[[ -x "$APPDIR/opt/Joplin/joplin" ]] || die "缺少 Joplin 主程序"
[[ -f "$APPDIR/opt/Joplin/resources/app.asar" ]] || die "缺少 Joplin app.asar"

# 将 Ubuntu 22.04 的 Adwaita 图标与 GTK 主题包直接解包进 AppDir。
mkdir -p "$THEME_DEB_DIR"
(
  cd "$THEME_DEB_DIR"
  apt-get download adwaita-icon-theme adwaita-icon-theme-full gnome-themes-extra-data
)
for theme_deb in "$THEME_DEB_DIR"/*.deb; do
  "$SCRIPT_DIR/../common/archive/extract_archive.sh" "$theme_deb" "$APPDIR"
done

# 规范官方 desktop 条目，并保留 Joplin 的 URI 参数。
DESKTOP_FILE="$(find "$APPDIR/usr/share/applications" -maxdepth 1 -type f -iname '*joplin*.desktop' -print -quit)"
[[ -n "$DESKTOP_FILE" ]] || die "缺少 Joplin desktop 文件"
sed -i -e 's|^Exec=.*|Exec=joplin %U|' -e 's|^Icon=.*|Icon=joplin|' "$DESKTOP_FILE"
desktop-file-validate "$DESKTOP_FILE"

# linuxdeploy 不接受 1024x1024 图标；保留官方 512x512 及其他标准尺寸。
rm -f "$APPDIR/usr/share/icons/hicolor/1024x1024/apps/joplin.png"

###### 准备兼容运行库 ######

# NSS 核心库和 dlopen 模块必须来自同一套 Ubuntu 22.04 libnss3，避免与宿主机新版 NSS 混用。
MULTIARCH="$(dpkg-architecture -qDEB_HOST_MULTIARCH)"
cp -a \
  "/usr/lib/$MULTIARCH/libnss3.so" \
  "/usr/lib/$MULTIARCH/libnssutil3.so" \
  "/usr/lib/$MULTIARCH/libsmime3.so" \
  "/usr/lib/$MULTIARCH/libssl3.so" \
  "/usr/lib/$MULTIARCH/libfreebl3.so" \
  "/usr/lib/$MULTIARCH/libfreebl3.chk" \
  "/usr/lib/$MULTIARCH/libfreeblpriv3.so" \
  "/usr/lib/$MULTIARCH/libfreeblpriv3.chk" \
  "/usr/lib/$MULTIARCH/nss/libnssckbi.so" \
  "/usr/lib/$MULTIARCH/nss/libnssdbm3.so" \
  "/usr/lib/$MULTIARCH/nss/libnssdbm3.chk" \
  "/usr/lib/$MULTIARCH/nss/libsoftokn3.so" \
  "/usr/lib/$MULTIARCH/nss/libsoftokn3.chk" \
  "$APPDIR/usr/lib/"

###### 核心打包 ######

# 最终 AppImage 已解包并实际运行确认，直接写入包含准确路径的完整根 AppRun。
# GTK linuxdeploy 会自动把它保存为 AppRun.wrapped，并生成加载 GTK hook 的顶层 AppRun。
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash
set -Eeuo pipefail

HERE="$(dirname "$(readlink -f "${0}")")"

# 保留三个 linuxdeploy 基础目录，并仅把 Joplin 的真实程序 / 库目录加入对应变量。
export PATH="$HERE/opt/Joplin:$HERE/usr/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$HERE/opt/Joplin:$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$HERE/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
export GSETTINGS_SCHEMA_DIR="$HERE/usr/share/glib-2.0/schemas${GSETTINGS_SCHEMA_DIR:+:$GSETTINGS_SCHEMA_DIR}"
export GIO_MODULE_DIR="$HERE/usr/lib/x86_64-linux-gnu/gio/modules"

# 保留已经通过真实运行确认的深色主题与辅助功能兼容设置。
export GTK_THEME=Adwaita-dark
export NO_AT_BRIDGE=1

exec "$HERE/opt/Joplin/joplin" "$@"
APPRUN
chmod +x "$APPDIR/AppRun"
bash -n "$APPDIR/AppRun"

# 公共入口配置 linuxdeploy 通用环境；GTK3 只在当前 GTK 项目中追加。
source "$SCRIPT_DIR/../common/linuxdeploy/configure_environment.sh" \
  "$TOOLS_DIR" "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"

# Joplin 使用 GTK3；第二次 linuxdeploy 部署 GTK 资源并完成 AppRun 包装。
export DEPLOY_GTK_VERSION=3
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin gtk --output appimage

###### 整理产物 ######

# 忽略 linuxdeploy 中间 AppImage，由公共入口使用官方 appimagetool 和 Type 2 runtime 正式封装。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" \
  "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE"
[[ -s "$OUTFILE" ]] || die "最终 AppImage 未生成"

# 写入本次实际打包的软件版本。
printf '%s\n' "$VERSION" > "$DIST_DIR/version.txt"
