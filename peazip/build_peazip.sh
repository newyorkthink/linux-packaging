#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

WORK_DIR="$SCRIPT_DIR/.work"
APPDIR="$SCRIPT_DIR/AppDir"
DIST_DIR="$SCRIPT_DIR/dist"
OUTFILE="$DIST_DIR/peazip.AppImage"

# 输出错误信息并立即终止构建。
die() {
  echo "错误：$*" >&2
  exit 1
}

# 从官方 continuous Release 下载指定构建工具并校验 SHA-256。
download_tool() {
  local repo="$1" asset="$2" output="$3" metadata url digest

  metadata="$(curl -fsSL --retry 3 --retry-all-errors --connect-timeout 20 --max-time 120 \
    "${api_headers[@]}" "https://api.github.com/repos/$repo/releases/tags/continuous")"
  url="$(jq -er --arg name "$asset" '.assets[] | select(.name == $name) | .browser_download_url' <<< "$metadata")"
  digest="$(jq -er --arg name "$asset" '.assets[] | select(.name == $name) | .digest' <<< "$metadata")"
  [[ "$digest" =~ ^sha256:[[:xdigit:]]{64}$ ]] || die "官方工具缺少有效 SHA-256：$repo/$asset"

  curl -fL --retry 3 --retry-all-errors --connect-timeout 20 --max-time 300 \
    "$url" -o "$output"
  printf '%s  %s\n' "${digest#sha256:}" "$output" | sha256sum -c -
}

[[ "$(uname -m)" == x86_64 ]] || die "当前仅支持 x86_64。"

rm -rf "$WORK_DIR" "$APPDIR" "$DIST_DIR"
mkdir -p "$WORK_DIR/tools" "$APPDIR" "$DIST_DIR"

# 安装下载、解包、linuxdeploy 和 Qt6 依赖部署所需的软件包。
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  ca-certificates curl jq file binutils patchelf desktop-file-utils xz-utils zstd \
  qmake6 qt6-base-dev qt6-base-dev-tools qt6-qpa-plugins qt6-gtk-platformtheme \
  qt6-translations-l10n adwaita-qt6 fcitx5-frontend-qt6 \
  libxkbcommon-x11-0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
  libxcb-render-util0 libxcb-xinerama0 libxcb-xkb1

# 准备 GitHub API 请求头；存在令牌时同时用于提高 API 访问额度。
api_headers=(
  -H 'Accept: application/vnd.github+json'
  -H 'X-GitHub-Api-Version: 2022-11-28'
)
if [[ -n "${GH_TOKEN:-}" ]]; then
  api_headers+=( -H "Authorization: Bearer $GH_TOKEN" )
fi

###### 下载 PeaZip ######

# 读取 PeaZip 官方最新稳定版 Release 元数据。
RELEASE_JSON="$WORK_DIR/peazip-release.json"
curl -fL --retry 3 --retry-all-errors --connect-timeout 20 --max-time 120 \
  "${api_headers[@]}" https://api.github.com/repos/peazip/PeaZip/releases/latest \
  -o "$RELEASE_JSON"

VERSION="$(jq -er '.tag_name | select(test("^[0-9]+(\\.[0-9]+){2}$"))' "$RELEASE_JSON")"
ASSET_NAME="peazip_${VERSION}.LINUX.Qt6-1_amd64.deb"
ASSET_URL="$(jq -er --arg name "$ASSET_NAME" '.assets[] | select(.name == $name) | .browser_download_url' "$RELEASE_JSON")"
ASSET_DIGEST="$(jq -er --arg name "$ASSET_NAME" '.assets[] | select(.name == $name) | .digest' "$RELEASE_JSON")"
[[ "$ASSET_DIGEST" =~ ^sha256:[[:xdigit:]]{64}$ ]] || die "PeaZip DEB 缺少有效 SHA-256。"

DEB_FILE="$WORK_DIR/$ASSET_NAME"
# 下载官方 Qt6 amd64 DEB，并使用 Release 提供的摘要确认下载内容。
curl -fL --retry 3 --retry-all-errors --connect-timeout 20 --max-time 600 \
  "$ASSET_URL" -o "$DEB_FILE"
printf '%s  %s\n' "${ASSET_DIGEST#sha256:}" "$DEB_FILE" | sha256sum -c -

[[ "$(dpkg-deb -f "$DEB_FILE" Package)" == peazip ]] || die "官方 DEB 包名异常。"
[[ "$(dpkg-deb -f "$DEB_FILE" Version)" == "$VERSION" ]] || die "官方 DEB 版本异常。"
[[ "$(dpkg-deb -f "$DEB_FILE" Architecture)" == amd64 ]] || die "官方 DEB 架构异常。"

# 把官方 DEB 内容原样解包到 AppDir，保留 PeaZip 的程序和资源目录布局。
dpkg-deb -x "$DEB_FILE" "$APPDIR"

PEAZIP_ROOT="$APPDIR/usr/lib/peazip"
DESKTOP_FILE="$APPDIR/usr/share/applications/peazip.desktop"
ICON_FILE="$APPDIR/usr/share/icons/hicolor/256x256/apps/peazip.png"

# 官方 DEB 使用绝对链接，AppImage 内改为等价相对链接。
ln -sfn ../lib/peazip/peazip "$APPDIR/usr/bin/peazip"
ln -sfn ../../../share/peazip "$PEAZIP_ROOT/res/share"

# 给 Qt plugin 提供 Qt6Pas、Adwaita 和 GTK3 theme 部署入口。
mkdir -p "$APPDIR/usr/lib" "$APPDIR/usr/plugins/styles" "$APPDIR/usr/plugins/platformthemes"
cp -a "$PEAZIP_ROOT"/libQt6Pas.so.6* "$APPDIR/usr/lib/"

QT6_PLUGIN_ROOT="$(qmake6 -query QT_INSTALL_PLUGINS)"
QT6_LIB_ROOT="$(qmake6 -query QT_INSTALL_LIBS)"
cp -a "$QT6_PLUGIN_ROOT/styles/adwaita.so" "$APPDIR/usr/plugins/styles/"
cp -a "$QT6_PLUGIN_ROOT/platformthemes/libqgtk3.so" "$APPDIR/usr/plugins/platformthemes/"
cp -a "$QT6_LIB_ROOT"/libadwaitaqt6.so.1* "$APPDIR/usr/lib/"
cp -a "$QT6_LIB_ROOT"/libadwaitaqt6priv.so.1* "$APPDIR/usr/lib/"

desktop-file-validate "$DESKTOP_FILE"

# 按旧版稳定 AppImage 的启动环境生成自定义 AppRun，交给 linuxdeploy 包装。
cat > "$APPDIR/AppRun" <<'EOF_APPRUN'
#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"

export PATH="$HERE"/usr:"$HERE"/usr/bin:"$HERE"/usr/lib:"$HERE"/usr/plugins:"$HERE"/usr/share:${PATH:+:$PATH}
export LD_LIBRARY_PATH="$HERE"/usr:"$HERE"/usr/bin:"$HERE"/usr/lib:"$HERE"/usr/plugins:"$HERE"/usr/share:${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
export QT_PLUGIN_PATH="$HERE"/usr:"$HERE"/usr/bin:"$HERE"/usr/lib:"$HERE"/usr/plugins:"$HERE"/usr/share:${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}
export XDG_DATA_DIRS="$HERE"/usr:"$HERE"/usr/bin:"$HERE"/usr/lib:"$HERE"/usr/plugins:"$HERE"/usr/share:${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}
export GSETTINGS_SCHEMA_DIR="${HERE}"/usr/share/glib-2.0/schemas/:"${GSETTINGS_SCHEMA_DIR}"
export NO_AT_BRIDGE=1

export QT_AUTO_SCREEN_SCALE_FACTOR=1
export QT_SCALE_FACTOR=1
export QT_STYLE_OVERRIDE=Adwaita-Dark
export QT_QPA_PLATFORMTHEME=Adwaita-Dark
export QT_QPA_PLATFORM=xcb
export QT_FONT_DPI=96

EXEC=$(grep -e '^Exec=.*' "${HERE}"/*.desktop | head -n 1 | cut -d "=" -f 2- | sed -e 's|%.||g')
exec ${EXEC} "$@"
EOF_APPRUN
# 赋予自定义 AppRun 执行权限。
chmod +x "$APPDIR/AppRun"

###### 核心打包 ######

# 下载 linuxdeploy、Qt 输入插件、官方 appimagetool 和 Type 2 runtime。
download_tool linuxdeploy/linuxdeploy linuxdeploy-x86_64.AppImage \
  "$WORK_DIR/tools/linuxdeploy-x86_64.AppImage"
download_tool linuxdeploy/linuxdeploy-plugin-qt linuxdeploy-plugin-qt-x86_64.AppImage \
  "$WORK_DIR/tools/linuxdeploy-plugin-qt-x86_64.AppImage"
download_tool AppImage/appimagetool appimagetool-x86_64.AppImage \
  "$WORK_DIR/tools/appimagetool-x86_64.AppImage"
download_tool AppImage/type2-runtime runtime-x86_64 \
  "$WORK_DIR/tools/runtime-x86_64"
# 赋予三个 AppImage 构建工具执行权限。
chmod +x "$WORK_DIR/tools"/*.AppImage

# linuxdeploy 会扫描 AppDir 中全部 ELF。官方包内的 32 位旧后端依赖已淘汰的
# libncurses.so.5，因此先移出扫描范围，Qt 依赖部署完成后再原样放回。
BACKENDS_DIR="$WORK_DIR/peazip-backends"
mv "$PEAZIP_ROOT/res/bin" "$BACKENDS_DIR"

# 配置 linuxdeploy、Qt6 qmake 和依赖部署所需的构建环境。
export ARCH=x86_64
export APPIMAGE_EXTRACT_AND_RUN=1
export PATH="$WORK_DIR/tools:$PATH"
export QMAKE=/usr/bin/qmake6
export NO_STRIP=1
export LDAI_NO_APPSTREAM=1
export LD_LIBRARY_PATH="$PEAZIP_ROOT${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# 使用 linuxdeploy 收集 PeaZip 主程序、pea 和 Qt6 所需的运行依赖。
"$WORK_DIR/tools/linuxdeploy-x86_64.AppImage" \
  --appdir "$APPDIR" \
  --desktop-file "$DESKTOP_FILE" \
  --icon-file "$ICON_FILE" \
  --executable "$PEAZIP_ROOT/peazip" \
  --executable "$PEAZIP_ROOT/pea" \
  --plugin qt

# Qt6 依赖部署完成后，把官方归档后端原样恢复到 PeaZip 资源目录。
mv "$BACKENDS_DIR" "$PEAZIP_ROOT/res/bin"

# 使用官方 appimagetool 和明确的 Type 2 runtime 封装最终 AppImage。
"$WORK_DIR/tools/appimagetool-x86_64.AppImage" \
  -n "$APPDIR" "$OUTFILE" \
  --runtime-file "$WORK_DIR/tools/runtime-x86_64"

###### 整理产物 ######

# 赋予最终 AppImage 执行权限。
chmod +x "$OUTFILE"
# 写入本次实际打包的软件版本，供正式发布流程读取。
printf '%s\n' "$VERSION" > "$DIST_DIR/version.txt"
# 输出最终 AppImage 的 SHA-256，供发布记录和资产完整性信息使用。
sha256sum "$OUTFILE"
