#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SOURCE_DIR="$SCRIPT_DIR/source"
APPDIR="$SCRIPT_DIR/AppDir"
DIST_DIR="$SCRIPT_DIR/dist"
TOOLS_DIR="$SOURCE_DIR/tools"
CLIENT_JSON_FILE="$SOURCE_DIR/client.json"
DEB_FILE="$SOURCE_DIR/baidunetdisk.deb"
THEME_DEB_DIR="$SOURCE_DIR/theme-debs"
LINUXDEPLOY="$TOOLS_DIR/linuxdeploy-x86_64.AppImage"
APPIMAGETOOL="$TOOLS_DIR/appimagetool-x86_64.AppImage"
RUNTIME_FILE="$TOOLS_DIR/runtime-x86_64"
INTERMEDIATE_APPIMAGE="$SOURCE_DIR/baidunetdisk-linuxdeploy-intermediate.AppImage"
OUTFILE="$DIST_DIR/baidunetdisk.AppImage"
CLIENT_API='https://pan.baidu.com/disk/cmsdata?do=client'

# 输出明确错误并立即终止构建。
die() {
  echo "错误：$*" >&2
  exit 1
}

[[ "$(uname -m)" == x86_64 ]] || die "当前仅支持 x86_64"

###### 准备构建环境 ######

# 只清理并重建当前项目自己的构建目录。
rm -rf "$SOURCE_DIR" "$APPDIR" "$DIST_DIR"
mkdir -p "$TOOLS_DIR" "$DIST_DIR"

# 根据当前环境选择 apt-get 调用方式。
if command -v sudo >/dev/null 2>&1; then
  APT=(sudo apt-get)
else
  APT=(apt-get)
fi

# 安装下载、DEB 处理、GTK3 插件和百度网盘运行时所需依赖。
"${APT[@]}" update
DEBIAN_FRONTEND=noninteractive "${APT[@]}" install -y --no-install-recommends \
  ca-certificates curl desktop-file-utils dpkg-dev file findutils gawk grep jq pkgconf sed \
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

# 确认后续构建依赖的基础命令均可用。
for command_name in curl cut desktop-file-validate dpkg-architecture dpkg-deb file find jq readlink sed sha256sum sort tail; do
  command -v "$command_name" >/dev/null 2>&1 || die "缺少必需命令：$command_name"
done

###### 下载打包工具 ######

# 动态取得 linuxdeploy、带 GIO 修复的 GTK 插件、appimagetool 和 Type 2 runtime。
"$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" gtk

###### 初始化 AppDir ######

# 配置 linuxdeploy 和中间输出位置；最终发布资产不会使用该中间文件。
export ARCH=x86_64
export APPIMAGE_EXTRACT_AND_RUN=1
export PATH="$TOOLS_DIR:$PATH"
export LINUXDEPLOY="$LINUXDEPLOY"
export LDAI_NO_APPSTREAM=1
export LDAI_OUTPUT="$INTERMEDIATE_APPIMAGE"
export LDAI_RUNTIME_FILE="$RUNTIME_FILE"

# 通过公共入口运行第一次普通 linuxdeploy，并核对空 AppDir 初始化结果。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR"

###### 下载并准备百度网盘 ######

# 读取百度网盘官方接口返回的当前 Linux 版本和 DEB 下载地址。
"$SCRIPT_DIR/../common/download/download_file.sh" "$CLIENT_API" "$CLIENT_JSON_FILE"
RAW_VERSION="$(jq -er '.linux.version // empty' "$CLIENT_JSON_FILE")"
DEB_URL="$(jq -er '.linux.url_1 // empty' "$CLIENT_JSON_FILE")"

if [[ "$RAW_VERSION" =~ ^(百度网盘Linux电脑客户端)?V?([0-9]+([.][0-9]+)+)$ ]]; then
  VERSION="${BASH_REMATCH[2]}"
else
  die "官方接口返回了无法识别的版本：$RAW_VERSION"
fi
[[ "$DEB_URL" == https://*.baidu.com/* || "$DEB_URL" == https://*.baidupcs.com/* ]] || \
  die "官方接口返回了非百度 HTTPS 地址：$DEB_URL"
[[ "${DEB_URL##*/}" == "baidunetdisk_${VERSION}_amd64.deb" ]] || \
  die "官方 DEB 地址与版本不一致：$DEB_URL"
printf '百度网盘版本：%s\n' "$VERSION"

# 官方接口未提供摘要；公共下载入口负责 HTTPS、重试和输出本次文件 SHA-256。
"$SCRIPT_DIR/../common/download/download_file.sh" "$DEB_URL" "$DEB_FILE"
file "$DEB_FILE" | grep -q 'Debian binary package' || die "下载文件不是 Debian 软件包"
sha256sum "$DEB_FILE"
[[ "$(dpkg-deb -f "$DEB_FILE" Package)" == baidunetdisk ]] || die "官方 DEB 包名异常"
[[ "$(dpkg-deb -f "$DEB_FILE" Version)" == "$VERSION" ]] || die "官方 DEB 版本不一致"
[[ "$(dpkg-deb -f "$DEB_FILE" Architecture)" == amd64 ]] || die "官方 DEB 架构不是 amd64"

# 把同一份官方 DEB 安装进隔离构建环境供 linuxdeploy 解析，并按上游布局解包到 AppDir。
DEBIAN_FRONTEND=noninteractive "${APT[@]}" install -y --no-install-recommends "$DEB_FILE"
dpkg-deb -x "$DEB_FILE" "$APPDIR"
APP_ROOT="$APPDIR/opt/baidunetdisk"
MAIN_BIN="$APP_ROOT/baidunetdisk"
[[ -x "$MAIN_BIN" ]] || die "缺少百度网盘主程序"
[[ -f "$APP_ROOT/resources/app.asar" ]] || die "缺少百度网盘 app.asar"

# 将 Ubuntu 22.04 的 Adwaita 图标与 GTK 主题包直接解包进 AppDir。
mkdir -p "$THEME_DEB_DIR"
(
  cd "$THEME_DEB_DIR"
  apt-get download adwaita-icon-theme adwaita-icon-theme-full gnome-themes-extra-data
)
for theme_deb in "$THEME_DEB_DIR"/*.deb; do
  dpkg-deb -x "$theme_deb" "$APPDIR"
done

# 规范官方 desktop 条目，并保留上游已经使用的 --no-sandbox 与 URI 参数。
DESKTOP_FILE="$(find "$APPDIR/usr/share/applications" -maxdepth 1 -type f -name 'baidunetdisk.desktop' -print -quit)"
[[ -n "$DESKTOP_FILE" ]] || die "缺少百度网盘 desktop 文件"
sed -i \
  -e 's|^Exec=.*|Exec=baidunetdisk --no-sandbox %U|' \
  -e 's|^Icon=.*|Icon=baidunetdisk|' \
  -e '/^Encoding=/d' \
  -e '/^Value=/d' \
  -e 's/^Terminal=0$/Terminal=false/' \
  "$DESKTOP_FILE"
desktop-file-validate "$DESKTOP_FILE"

# 选取官方包中实际存在的百度网盘图标交给 linuxdeploy。
ICON_FILE="$(find "$APPDIR/usr/share/icons" "$APP_ROOT" \
  -type f \( -iname 'baidunetdisk.png' -o -iname 'baidunetdisk.svg' \) \
  -printf '%s\t%p\n' 2>/dev/null | sort -n | tail -n 1 | cut -f2-)"
[[ -n "$ICON_FILE" ]] || die "官方包中没有百度网盘图标"

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

# 百度网盘通过 Koffi 动态加载 GTKmm 2.4，并按上游依赖推荐使用 AppIndicator。
GTKMM2_LIB="/usr/lib/$MULTIARCH/libgtkmm-2.4.so.1"
APPINDICATOR_LIB="/usr/lib/$MULTIARCH/libappindicator3.so.1"
[[ -e "$GTKMM2_LIB" ]] || die "缺少 GTKmm 2.4 运行库：$GTKMM2_LIB"
[[ -e "$APPINDICATOR_LIB" ]] || die "缺少 AppIndicator 运行库：$APPINDICATOR_LIB"

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
bash -n "$APPDIR/AppRun"

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

# 忽略 linuxdeploy 中间 AppImage，使用官方 appimagetool 和 Type 2 runtime
# 对同一个 AppDir 重新封装正式发布资产。
export ARCH=x86_64; "$APPIMAGETOOL" -n ./AppDir "$OUTFILE" --runtime-file "$RUNTIME_FILE"
[[ -s "$OUTFILE" ]] || die "最终 AppImage 未生成"
chmod +x "$OUTFILE"

# 写入本次实际打包的软件版本，并输出正式资产 SHA-256。
printf '%s\n' "$VERSION" > "$DIST_DIR/version.txt"
sha256sum "$OUTFILE"
