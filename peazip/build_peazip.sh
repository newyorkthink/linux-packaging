#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
cd "$SCRIPT_DIR"

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

download_release_asset() {
  local repo="$1"
  local tag="$2"
  local asset="$3"
  local output="$4"
  local metadata="$WORK_DIR/${repo//\//-}-${tag}.json"
  local url digest

  curl -fL \
    --retry 5 \
    --retry-all-errors \
    --retry-delay 2 \
    --connect-timeout 20 \
    --max-time 120 \
    "${api_headers[@]}" \
    "https://api.github.com/repos/$repo/releases/tags/$tag" \
    -o "$metadata"

  url="$(jq -er --arg name "$asset" '.assets[] | select(.name == $name) | .browser_download_url' "$metadata")"
  digest="$(jq -er --arg name "$asset" '.assets[] | select(.name == $name) | .digest' "$metadata")"
  [[ "$url" == "https://github.com/$repo/releases/download/$tag/$asset" ]] || \
    die "官方工具资产 URL 不符合预期：$repo/$asset"
  [[ "$digest" =~ ^sha256:[0-9a-fA-F]{64}$ ]] || \
    die "官方工具缺少有效 SHA-256：$repo/$asset"

  curl -fL \
    --retry 5 \
    --retry-all-errors \
    --retry-delay 2 \
    --connect-timeout 20 \
    --max-time 300 \
    "$url" \
    -o "$output"
  printf '%s  %s\n' "${digest#sha256:}" "$output" | sha256sum -c -
}

###### 准备构建环境 ######

HOST_ARCH="$(uname -m)"
readonly HOST_ARCH
[[ "$HOST_ARCH" == x86_64 ]] || die "当前仅支持 x86_64，检测到：$HOST_ARCH"

readonly WORK_DIR="$SCRIPT_DIR/.work"
readonly PACKAGE_ROOT="$WORK_DIR/package"
readonly TOOLS_DIR="$WORK_DIR/tools"
readonly VERIFY_DIR="$WORK_DIR/verify-appimage"
readonly APPDIR="$SCRIPT_DIR/AppDir"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly OUTFILE="$DIST_DIR/peazip.AppImage"

# 只清理 PeaZip 当前应用目录内的构建文件和旧产物。
rm -rf "$WORK_DIR" "$APPDIR" "$DIST_DIR"
mkdir -p "$PACKAGE_ROOT" "$TOOLS_DIR" "$APPDIR" "$DIST_DIR"

# linuxdeploy + appimagetool 路线固定在 Ubuntu 24.04 构建。
sudo apt-get update
sudo apt-get install -y aptitude

# 安装打包工具、Qt6/XCB、Adwaita Dark 和 Qt6 中文输入所需组件。
sudo aptitude install -y \
  build-essential git wget curl jq binutils patchelf file coreutils findutils \
  grep sed gawk tar gzip xz-utils unzip rsync util-linux appstream-util \
  desktop-file-utils zsync ca-certificates zstd \
  qmake6 qt6-base-dev qt6-base-dev-tools qt6-qpa-plugins \
  qt6-gtk-platformtheme qt6-translations-l10n adwaita-qt6 \
  fcitx5-frontend-qt6 libx11-6 libxkbcommon-x11-0 \
  libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-render-util0 \
  libxcb-xinerama0 libxcb-xkb1

api_headers=(
  -H 'Accept: application/vnd.github+json'
  -H 'X-GitHub-Api-Version: 2022-11-28'
)
if [[ -n "${GH_TOKEN:-}" ]]; then
  api_headers+=( -H "Authorization: Bearer $GH_TOKEN" )
fi

###### 下载并校验官方最新稳定版 ######

readonly RELEASE_API='https://api.github.com/repos/peazip/PeaZip/releases/latest'
readonly RELEASE_JSON="$WORK_DIR/peazip-release.json"

curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  --max-time 120 \
  "${api_headers[@]}" \
  "$RELEASE_API" \
  -o "$RELEASE_JSON"

jq -e '.draft == false and .prerelease == false' "$RELEASE_JSON" >/dev/null
VERSION="$(jq -er '.tag_name | strings | select(length > 0)' "$RELEASE_JSON")"
readonly VERSION
[[ "$VERSION" =~ ^[0-9]+([.][0-9]+){2}$ ]] || die "PeaZip Release tag 格式异常：$VERSION"

ASSET_NAME="peazip_${VERSION}.LINUX.Qt6-1_amd64.deb"
readonly ASSET_NAME
mapfile -t asset_rows < <(
  jq -r --arg name "$ASSET_NAME" \
    '.assets[] | select(.name == $name) | [.browser_download_url, (.digest // "")] | @tsv' \
    "$RELEASE_JSON"
)
[[ ${#asset_rows[@]} -eq 1 ]] || die "官方 Release 中应且只能有一个 $ASSET_NAME。"

IFS=$'\t' read -r ASSET_URL ASSET_DIGEST <<< "${asset_rows[0]}"
readonly ASSET_URL ASSET_DIGEST
readonly EXPECTED_URL="https://github.com/peazip/PeaZip/releases/download/${VERSION}/${ASSET_NAME}"
[[ "$ASSET_URL" == "$EXPECTED_URL" ]] || die "PeaZip Release 资产 URL 不符合预期：$ASSET_URL"
[[ "$ASSET_DIGEST" =~ ^sha256:[0-9a-fA-F]{64}$ ]] || die "官方 Release 缺少有效的 SHA-256 digest。"

readonly DEB_FILE="$WORK_DIR/$ASSET_NAME"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  --max-time 600 \
  "$ASSET_URL" \
  -o "$DEB_FILE"

[[ -s "$DEB_FILE" ]] || die "PeaZip 官方 DEB 下载结果为空。"
file "$DEB_FILE" | grep -q 'Debian binary package' || die "下载文件不是 Debian 软件包。"

EXPECTED_SHA256="${ASSET_DIGEST#sha256:}"
EXPECTED_SHA256="${EXPECTED_SHA256,,}"
ACTUAL_SHA256="$(sha256sum "$DEB_FILE" | awk '{print $1}')"
readonly EXPECTED_SHA256 ACTUAL_SHA256
[[ "$ACTUAL_SHA256" == "$EXPECTED_SHA256" ]] || die "PeaZip 官方 DEB SHA-256 校验失败。"
printf 'PeaZip version: %s\nPeaZip DEB SHA-256: %s\n' "$VERSION" "$ACTUAL_SHA256"

###### 解包并核对官方 DEB ######

dpkg-deb -x "$DEB_FILE" "$PACKAGE_ROOT"
PACKAGE_NAME="$(dpkg-deb -f "$DEB_FILE" Package)"
PACKAGE_VERSION="$(dpkg-deb -f "$DEB_FILE" Version)"
PACKAGE_ARCH="$(dpkg-deb -f "$DEB_FILE" Architecture)"
readonly PACKAGE_NAME PACKAGE_VERSION PACKAGE_ARCH
[[ "$PACKAGE_NAME" == peazip ]] || die "官方 DEB 包名异常：$PACKAGE_NAME"
[[ "$PACKAGE_VERSION" == "$VERSION" ]] || die "Release tag 与 DEB 版本不一致：$VERSION / $PACKAGE_VERSION"
[[ "$PACKAGE_ARCH" == amd64 ]] || die "官方 DEB 架构不是 amd64：$PACKAGE_ARCH"

readonly SOURCE_APP_ROOT="$PACKAGE_ROOT/usr/lib/peazip"
readonly SOURCE_MAIN="$SOURCE_APP_ROOT/peazip"
readonly SOURCE_HELPER="$SOURCE_APP_ROOT/pea"
readonly SOURCE_BACKENDS="$SOURCE_APP_ROOT/res/bin"
readonly SOURCE_SHARE="$PACKAGE_ROOT/usr/share/peazip"
readonly SOURCE_DESKTOP="$PACKAGE_ROOT/usr/share/applications/peazip.desktop"
readonly SOURCE_ICON="$PACKAGE_ROOT/usr/share/icons/hicolor/256x256/apps/peazip.png"

[[ -x "$SOURCE_MAIN" ]] || die "官方 DEB 缺少 PeaZip 主程序。"
[[ -x "$SOURCE_HELPER" ]] || die "官方 DEB 缺少 pea 辅助程序。"
[[ -x "$SOURCE_BACKENDS/7z/7z" ]] || die "官方 DEB 缺少 7z 解压后端。"
[[ -f "$SOURCE_SHARE/lang/zh-cn.txt" ]] || die "官方 DEB 缺少简体中文语言文件。"
[[ -f "$SOURCE_SHARE/themes/main-dark.theme.7z" ]] || die "官方 DEB 缺少黑色主题资源。"
[[ -f "$SOURCE_DESKTOP" ]] || die "官方 DEB 缺少 desktop 文件。"
[[ -f "$SOURCE_ICON" ]] || die "官方 DEB 缺少 256x256 PNG 图标。"
file "$SOURCE_MAIN" | grep -q 'ELF 64-bit.*x86-64' || die "PeaZip 主程序不是 x86_64 ELF。"
readelf -d "$SOURCE_MAIN" | grep -q 'Shared library: \[libQt6Pas.so.6\]' || \
  die "PeaZip 主程序不再使用预期的 Qt6Pas 入口。"

###### 下载官方打包工具 ######

download_release_asset \
  linuxdeploy/linuxdeploy continuous linuxdeploy-x86_64.AppImage \
  "$TOOLS_DIR/linuxdeploy-x86_64.AppImage"
download_release_asset \
  linuxdeploy/linuxdeploy-plugin-qt continuous linuxdeploy-plugin-qt-x86_64.AppImage \
  "$TOOLS_DIR/linuxdeploy-plugin-qt-x86_64.AppImage"
download_release_asset \
  AppImage/appimagetool continuous appimagetool-x86_64.AppImage \
  "$TOOLS_DIR/appimagetool-x86_64.AppImage"
download_release_asset \
  AppImage/type2-runtime continuous runtime-x86_64 \
  "$TOOLS_DIR/runtime-x86_64"
chmod +x \
  "$TOOLS_DIR/linuxdeploy-x86_64.AppImage" \
  "$TOOLS_DIR/linuxdeploy-plugin-qt-x86_64.AppImage" \
  "$TOOLS_DIR/appimagetool-x86_64.AppImage"

###### 准备 AppDir ######

# 完整保留官方 /usr 布局，使主程序、res 后端、语言和主题继续相邻可达。
cp -a "$PACKAGE_ROOT/usr" "$APPDIR/usr"

# 官方 DEB 的绝对链接只适用于系统安装；AppImage 内改为等价相对链接。
[[ -L "$APPDIR/usr/bin/peazip" ]] || die "官方 PeaZip 命令入口不是预期的符号链接。"
[[ "$(readlink "$APPDIR/usr/bin/peazip")" == /usr/lib/peazip/peazip ]] || \
  die "官方 PeaZip 命令入口目标发生变化。"
ln -sfn ../lib/peazip/peazip "$APPDIR/usr/bin/peazip"

[[ -L "$APPDIR/usr/lib/peazip/res/share" ]] || die "官方 PeaZip 资源入口不是预期的符号链接。"
[[ "$(readlink "$APPDIR/usr/lib/peazip/res/share")" == /usr/share/peazip ]] || \
  die "官方 PeaZip 资源链接目标发生变化。"
ln -sfn ../../../share/peazip "$APPDIR/usr/lib/peazip/res/share"

# Qt 插件从 usr/lib 识别 Qt 主版本；保留程序目录原件并复制 Qt6Pas 作为部署种子。
cp -a "$APPDIR/usr/lib/peazip"/libQt6Pas.so.6* "$APPDIR/usr/lib/"

desktop-file-validate "$APPDIR/usr/share/applications/peazip.desktop"

# Adwaita 和 GTK3 platform theme 属于可选 Qt6 plugin，明确放入 AppDir 供 linuxdeploy 收集依赖。
QT6_PLUGIN_ROOT="$(qmake6 -query QT_INSTALL_PLUGINS)"
QT6_LIB_ROOT="$(qmake6 -query QT_INSTALL_LIBS)"
readonly QT6_PLUGIN_ROOT QT6_LIB_ROOT
[[ -f "$QT6_PLUGIN_ROOT/styles/adwaita.so" ]] || die "构建环境缺少 Qt6 Adwaita 样式插件。"
[[ -f "$QT6_PLUGIN_ROOT/platformthemes/libqgtk3.so" ]] || die "构建环境缺少 Qt6 GTK3 platform theme。"
[[ -e "$QT6_LIB_ROOT/libadwaitaqt6.so.1" ]] || die "构建环境缺少 Qt6 Adwaita 样式运行库。"
[[ -e "$QT6_LIB_ROOT/libadwaitaqt6priv.so.1" ]] || die "构建环境缺少 Qt6 Adwaita 私有运行库。"
mkdir -p "$APPDIR/usr/plugins/styles" "$APPDIR/usr/plugins/platformthemes"
cp -a "$QT6_PLUGIN_ROOT/styles/adwaita.so" "$APPDIR/usr/plugins/styles/"
cp -a "$QT6_PLUGIN_ROOT/platformthemes/libqgtk3.so" "$APPDIR/usr/plugins/platformthemes/"
# linuxdeploy 不会自动递归部署手工加入的 Adwaita plugin 依赖，明确复制 SONAME 链。
cp -a "$QT6_LIB_ROOT"/libadwaitaqt6.so.1* "$APPDIR/usr/lib/"
cp -a "$QT6_LIB_ROOT"/libadwaitaqt6priv.so.1* "$APPDIR/usr/lib/"

# 新版 Qt6 plugin 不生成 AppRun hook；预先创建的真实 AppRun 会直接保留。
cat > "$APPDIR/AppRun" <<'EOF_APPRUN'
#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(dirname "$(readlink -f "$0")")"

export PATH="$ROOT/usr/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$ROOT/usr/lib/peazip:$ROOT/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export QT_PLUGIN_PATH="$ROOT/usr/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
export XDG_DATA_DIRS="$ROOT/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
export NO_AT_BRIDGE=1

export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_MESSAGES=zh_CN.UTF-8

# PeaZip 不按系统 locale 自动选择界面语言；首次启动只初始化一次简体中文。
# 标记创建后不再注入参数，用户后续在设置中选择其他语言不会被覆盖。
PEAZIP_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/peazip"
PEAZIP_LANGUAGE_MARKER="$PEAZIP_CONFIG_DIR/.appimage-zh-cn-initialized"
if [[ ! -e "$PEAZIP_LANGUAGE_MARKER" ]]; then
  mkdir -p "$PEAZIP_CONFIG_DIR" 2>/dev/null || true
  touch "$PEAZIP_LANGUAGE_MARKER" 2>/dev/null || true
  set -- -peaziplanguage zh-cn.txt "$@"
fi

export QT_AUTO_SCREEN_SCALE_FACTOR=1
export QT_SCALE_FACTOR=1
export QT_STYLE_OVERRIDE=Adwaita-Dark
export QT_QPA_PLATFORMTHEME=Adwaita-Dark
export QT_QPA_PLATFORM=xcb
export QT_FONT_DPI=96

exec "$ROOT/usr/lib/peazip/peazip" "$@"
EOF_APPRUN
chmod +x "$APPDIR/AppRun"
bash -n "$APPDIR/AppRun"

###### 核心打包 ######

export ARCH=x86_64
export APPIMAGE_EXTRACT_AND_RUN=1
export PATH="$TOOLS_DIR:$PATH"
export QMAKE=/usr/bin/qmake6
export NO_STRIP=1
export LDAI_NO_APPSTREAM=1
export LD_LIBRARY_PATH="$APPDIR/usr/lib/peazip${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

linuxdeploy_args=(
  --appdir "$APPDIR"
  --desktop-file "$APPDIR/usr/share/applications/peazip.desktop"
  --icon-file "$APPDIR/usr/share/icons/hicolor/256x256/apps/peazip.png"
  --executable "$APPDIR/usr/lib/peazip/peazip"
  --executable "$APPDIR/usr/lib/peazip/pea"
  --plugin qt
)

# 将真实参与解压的 64 位动态后端交给 linuxdeploy 收集普通 ELF 依赖。
while IFS= read -r -d '' backend; do
  if file "$backend" | grep -q 'ELF 64-bit' && \
     readelf -d "$backend" 2>/dev/null | grep -q '(NEEDED)'; then
    linuxdeploy_args+=( --executable "$backend" )
  fi
done < <(find "$APPDIR/usr/lib/peazip/res/bin" -type f -perm -u+x -print0 | sort -z)

# linuxdeploy 只整理 AppDir 和收集依赖，不负责最终 AppImage 封装。
"$TOOLS_DIR/linuxdeploy-x86_64.AppImage" "${linuxdeploy_args[@]}"

[[ -x "$APPDIR/AppRun" ]] || die "linuxdeploy 未保留最终 AppRun。"
[[ ! -L "$APPDIR/AppRun" ]] || die "linuxdeploy 把真实 AppRun 替换成了符号链接。"

# 最终由官方 appimagetool 使用明确下载并校验的 Type 2 runtime 封装。
"$TOOLS_DIR/appimagetool-x86_64.AppImage" \
  -n "$APPDIR" "$OUTFILE" \
  --runtime-file "$TOOLS_DIR/runtime-x86_64"

###### 整理产物 ######

[[ -s "$OUTFILE" ]] || die "未生成预期文件：$OUTFILE"
chmod +x "$OUTFILE"

# 解包最终产物，确认本次故障涉及的程序、资源、主题和输入组件全部位于实际启动链中。
mkdir -p "$VERIFY_DIR"
(
  cd "$VERIFY_DIR"
  "$OUTFILE" --appimage-extract >/dev/null
)
readonly VERIFY_ROOT="$VERIFY_DIR/squashfs-root"
[[ -x "$VERIFY_ROOT/AppRun" && ! -L "$VERIFY_ROOT/AppRun" ]] || die "最终 AppImage 的 AppRun 异常。"
[[ -x "$VERIFY_ROOT/usr/lib/peazip/peazip" ]] || die "最终 AppImage 缺少 PeaZip 主程序。"
[[ -x "$VERIFY_ROOT/usr/lib/peazip/res/bin/7z/7z" ]] || die "最终 AppImage 缺少 7z 解压后端。"
[[ "$(readlink "$VERIFY_ROOT/usr/lib/peazip/res/share")" == ../../../share/peazip ]] || \
  die "最终 AppImage 的 PeaZip 资源链接异常。"
[[ -f "$VERIFY_ROOT/usr/share/peazip/lang/zh-cn.txt" ]] || die "最终 AppImage 缺少简体中文语言文件。"
[[ -f "$VERIFY_ROOT/usr/share/peazip/themes/main-dark.theme.7z" ]] || die "最终 AppImage 缺少黑色主题资源。"
[[ -f "$VERIFY_ROOT/usr/plugins/styles/adwaita.so" ]] || die "最终 AppImage 缺少 Qt6 Adwaita 样式。"
[[ -f "$VERIFY_ROOT/usr/plugins/platformthemes/libqgtk3.so" ]] || die "最终 AppImage 缺少 Qt6 GTK3 platform theme。"
[[ -e "$VERIFY_ROOT/usr/lib/libadwaitaqt6.so.1" ]] || die "最终 AppImage 缺少 Qt6 Adwaita 样式运行库。"
[[ -e "$VERIFY_ROOT/usr/lib/libadwaitaqt6priv.so.1" ]] || die "最终 AppImage 缺少 Qt6 Adwaita 私有运行库。"
[[ -f "$VERIFY_ROOT/usr/plugins/platforms/libqxcb.so" ]] || die "最终 AppImage 缺少 Qt6 XCB 平台插件。"
[[ -f "$VERIFY_ROOT/usr/plugins/platforminputcontexts/libcomposeplatforminputcontextplugin.so" ]] || \
  die "最终 AppImage 缺少 Qt6 Compose 输入插件。"
[[ -f "$VERIFY_ROOT/usr/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so" ]] || \
  die "最终 AppImage 缺少 Qt6 Fcitx5 输入插件。"
[[ -f "$VERIFY_ROOT/usr/plugins/platforminputcontexts/libibusplatforminputcontextplugin.so" ]] || \
  die "最终 AppImage 缺少 Qt6 IBus 输入插件。"
grep -Fqx 'export LANG=zh_CN.UTF-8' "$VERIFY_ROOT/AppRun"
grep -Fqx 'export LANGUAGE=zh_CN:zh' "$VERIFY_ROOT/AppRun"
grep -Fqx '  set -- -peaziplanguage zh-cn.txt "$@"' "$VERIFY_ROOT/AppRun"
grep -Fqx 'export QT_STYLE_OVERRIDE=Adwaita-Dark' "$VERIFY_ROOT/AppRun"
grep -Fqx 'export QT_QPA_PLATFORM=xcb' "$VERIFY_ROOT/AppRun"
# shellcheck disable=SC2016 # 此处按字面核对最终 AppRun 中的变量引用。
grep -Fqx 'exec "$ROOT/usr/lib/peazip/peazip" "$@"' "$VERIFY_ROOT/AppRun"

verify_elf_dependencies() {
  local elf="$1"
  local label="$2"
  local output

  output="$(
    LD_LIBRARY_PATH="$VERIFY_ROOT/usr/lib/peazip:$VERIFY_ROOT/usr/lib" \
      ldd "$elf"
  )"
  printf '%s dependencies:\n%s\n' "$label" "$output"
  if grep -Fq 'not found' <<< "$output"; then
    die "最终 AppImage 的 $label 仍有未解析的共享库。"
  fi

  printf '%s' "$output"
}

verify_elf_dependencies "$VERIFY_ROOT/usr/lib/peazip/peazip" 'PeaZip 主程序' >/dev/null
ADWAITA_LDD="$(verify_elf_dependencies "$VERIFY_ROOT/usr/plugins/styles/adwaita.so" 'Qt6 Adwaita 样式')"
grep -Fq "libadwaitaqt6.so.1 => $VERIFY_ROOT/usr/lib/libadwaitaqt6.so.1" <<< "$ADWAITA_LDD" || \
  die "Qt6 Adwaita 样式没有使用 AppImage 内的公开运行库。"
grep -Fq "libadwaitaqt6priv.so.1 => $VERIFY_ROOT/usr/lib/libadwaitaqt6priv.so.1" <<< "$ADWAITA_LDD" || \
  die "Qt6 Adwaita 样式没有使用 AppImage 内的私有运行库。"
verify_elf_dependencies "$VERIFY_ROOT/usr/plugins/platformthemes/libqgtk3.so" 'Qt6 GTK3 platform theme' >/dev/null
verify_elf_dependencies "$VERIFY_ROOT/usr/plugins/platforms/libqxcb.so" 'Qt6 XCB 平台插件' >/dev/null
verify_elf_dependencies \
  "$VERIFY_ROOT/usr/plugins/platforminputcontexts/libcomposeplatforminputcontextplugin.so" \
  'Qt6 Compose 输入插件' >/dev/null
verify_elf_dependencies \
  "$VERIFY_ROOT/usr/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so" \
  'Qt6 Fcitx5 输入插件' >/dev/null
verify_elf_dependencies \
  "$VERIFY_ROOT/usr/plugins/platforminputcontexts/libibusplatforminputcontextplugin.so" \
  'Qt6 IBus 输入插件' >/dev/null

printf '%s\n' "$VERSION" > "$DIST_DIR/version.txt"
sha256sum "$OUTFILE"
printf '已生成：%s（PeaZip %s）\n' "$OUTFILE" "$VERSION"
