#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SOURCE_DIR="$SCRIPT_DIR/source"
APPDIR="$SCRIPT_DIR/AppDir"
DIST_DIR="$SCRIPT_DIR/dist"
TOOLS_DIR="$SOURCE_DIR/tools"
DEB_FILE="$SOURCE_DIR/joplin.deb"
THEME_DEB_DIR="$SOURCE_DIR/theme-debs"
LINUXDEPLOY="$TOOLS_DIR/linuxdeploy-x86_64.AppImage"
APPIMAGETOOL="$TOOLS_DIR/appimagetool-x86_64.AppImage"
RUNTIME_FILE="$TOOLS_DIR/runtime-x86_64"
INTERMEDIATE_APPIMAGE="$SOURCE_DIR/joplin-linuxdeploy-intermediate.AppImage"
OUTFILE="$DIST_DIR/joplin.AppImage"

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

# 安装下载、DEB 处理、GTK3 插件和 Joplin 运行时所需依赖。
"${APT[@]}" update
DEBIAN_FRONTEND=noninteractive "${APT[@]}" install -y --no-install-recommends \
  ca-certificates curl desktop-file-utils dpkg-dev file findutils gawk grep jq pkgconf sed \
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

# 确认后续构建依赖的基础命令均可用。
for command_name in curl desktop-file-validate dpkg-deb find jq readlink sed sha256sum; do
  command -v "$command_name" >/dev/null 2>&1 || die "缺少必需命令：$command_name"
done

###### 下载打包工具 ######

# 动态取得 linuxdeploy、GTK 插件、appimagetool 和 Type 2 runtime，并记录可用摘要。
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

# 第一次只让 linuxdeploy 创建空 AppDir 的 usr/bin、usr/lib、usr/share 等基础目录。
# 当前 linuxdeploy 会因空 AppDir 尚无 desktop 而在输出阶段返回 1；只接受“目录已创建且没有文件”的结果。
set +e
export ARCH=x86_64; linuxdeploy --appdir AppDir --output appimage
FIRST_LINUXDEPLOY_STATUS=$?
set -e

if [[ "$FIRST_LINUXDEPLOY_STATUS" -ne 0 && "$FIRST_LINUXDEPLOY_STATUS" -ne 1 ]]; then
  die "第一次空 AppDir 初始化异常退出：$FIRST_LINUXDEPLOY_STATUS"
fi
for required_dir in "$APPDIR/usr/bin" "$APPDIR/usr/lib" "$APPDIR/usr/share"; do
  [[ -d "$required_dir" ]] || die "第一次 linuxdeploy 未创建基础目录：$required_dir"
done
[[ -z "$(find "$APPDIR" -type f -print -quit)" ]] || die "第一次 linuxdeploy 初始化后 AppDir 中出现了非预期文件"

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

# 把官方 DEB 安装进隔离构建环境，使 linuxdeploy 能解析同一应用及其依赖。
DEBIAN_FRONTEND=noninteractive "${APT[@]}" install -y --no-install-recommends "$DEB_FILE"

# 保持上游 /opt/Joplin 与 /usr/share 布局解包到 AppDir。
dpkg-deb -x "$DEB_FILE" "$APPDIR"
[[ -x "$APPDIR/opt/Joplin/joplin" ]] || die "缺少 Joplin 主程序"
[[ -f "$APPDIR/opt/Joplin/resources/app.asar" ]] || die "缺少 Joplin app.asar"

# 将 Ubuntu 22.04 的 Adwaita 图标与 GTK 主题包直接解包进 AppDir。
mkdir -p "$THEME_DEB_DIR"
(
  cd "$THEME_DEB_DIR"
  apt-get download adwaita-icon-theme adwaita-icon-theme-full gnome-themes-extra-data
)
for theme_deb in "$THEME_DEB_DIR"/*.deb; do
  dpkg-deb -x "$theme_deb" "$APPDIR"
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

# 应用文件进入 AppDir 后，在第二次 linuxdeploy 前写入完整根 AppRun。
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

# Joplin 使用 GTK3；第二次 linuxdeploy 部署 GTK 资源并完成 AppRun 包装。
export DEPLOY_GTK_VERSION=3
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin gtk --output appimage

# 当前首次按新规范生成的目录仍需根据第二次 linuxdeploy 结果整理一次路径型 export。
"$SCRIPT_DIR/../common/linuxdeploy/normalize_apprun_paths.sh" "$APPDIR"

###### 整理产物 ######

# 忽略 linuxdeploy 中间 AppImage，使用官方 appimagetool 和 Type 2 runtime
# 对同一个 AppDir 重新封装正式发布资产。
export ARCH=x86_64; "$APPIMAGETOOL" -n ./AppDir "$OUTFILE" --runtime-file "$RUNTIME_FILE"
[[ -s "$OUTFILE" ]] || die "最终 AppImage 未生成"
chmod +x "$OUTFILE"

# 写入本次实际打包的软件版本，并输出正式资产 SHA-256。
printf '%s\n' "$VERSION" > "$DIST_DIR/version.txt"
sha256sum "$OUTFILE"
