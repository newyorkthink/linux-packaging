#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

WORK_DIR="$SCRIPT_DIR/.work"
TOOLS_DIR="$WORK_DIR/tools"
APPDIR="$SCRIPT_DIR/AppDir"
DIST_DIR="$SCRIPT_DIR/dist"
OUTFILE="$DIST_DIR/peazip.AppImage"
INTERMEDIATE_APPIMAGE="$WORK_DIR/peazip-intermediate.AppImage"
APPIMAGETOOL="$TOOLS_DIR/appimagetool-x86_64.AppImage"
RUNTIME_FILE="$TOOLS_DIR/runtime-x86_64"

# 输出错误信息并立即终止构建。
die() {
  echo "错误：$*" >&2
  exit 1
}

[[ "$(uname -m)" == x86_64 ]] || die "当前仅支持 x86_64。"

###### 准备构建环境 ######

# 只清理并重建 PeaZip 自己的构建目录；AppDir 由第一次 linuxdeploy 创建。
rm -rf "$WORK_DIR" "$APPDIR" "$DIST_DIR"
mkdir -p "$TOOLS_DIR" "$DIST_DIR"

# 准备 Ubuntu / linuxdeploy 打包所需的最小基础环境。
sudo apt-get update
sudo apt-get install -y aptitude
sudo aptitude install -y \
  build-essential git wget binutils patchelf file appstream-util \
  desktop-file-utils zsync ca-certificates

# 单独安装 PeaZip 的下载、DEB 解包和 Qt6 依赖部署环境。
sudo aptitude install -y \
  curl jq xz-utils zstd \
  qmake6 qt6-base-dev qt6-base-dev-tools qt6-qpa-plugins qt6-gtk-platformtheme \
  qt6-translations-l10n adwaita-qt6 fcitx5-frontend-qt6 \
  libxkbcommon-x11-0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
  libxcb-render-util0 libxcb-xinerama0 libxcb-xkb1

# 使用公共脚本动态下载并校验 linuxdeploy、Qt 插件、appimagetool 和 Type 2 runtime。
"$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" qt

# 配置两次 linuxdeploy 共用的 Qt6 工具、官方 runtime 和中间输出位置。
command -v qmake6 >/dev/null 2>&1 || die "缺少 Qt6 qmake。"
QMAKE6="$(command -v qmake6)"
export ARCH=x86_64
export APPIMAGE_EXTRACT_AND_RUN=1
export PATH="$TOOLS_DIR:$PATH"
export QMAKE="$QMAKE6"
export NO_STRIP=1
export LDAI_NO_APPSTREAM=1
export LDAI_OUTPUT="$INTERMEDIATE_APPIMAGE"
export LDAI_RUNTIME_FILE="$RUNTIME_FILE"

###### 初始化 AppDir ######

# 通过公共入口运行第一次普通 linuxdeploy，并核对空 AppDir 初始化结果。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR"

###### 下载并安装 PeaZip ######

# 从官方正式 Release 动态解析当前最新稳定版 Qt6 amd64 DEB。
mapfile -t PEAZIP_RELEASE < <(
  "$SCRIPT_DIR/../common/github/resolve_latest_stable_release_asset.sh" \
    peazip/PeaZip 'peazip_{version}.LINUX.Qt6-1_amd64.deb'
)
[[ ${#PEAZIP_RELEASE[@]} -eq 3 ]] || die "无法解析 PeaZip 最新稳定版资产。"
VERSION="${PEAZIP_RELEASE[0]}"
ASSET_URL="${PEAZIP_RELEASE[1]}"
ASSET_SHA256="${PEAZIP_RELEASE[2]}"
ASSET_NAME="peazip_${VERSION}.LINUX.Qt6-1_amd64.deb"
DEB_FILE="$WORK_DIR/$ASSET_NAME"

# 下载官方 Qt6 amd64 DEB，并使用 Release 提供的 SHA-256 校验内容。
"$SCRIPT_DIR/../common/download/download_file.sh" \
  "$ASSET_URL" "$DEB_FILE" "$ASSET_SHA256"

[[ "$(dpkg-deb -f "$DEB_FILE" Package)" == peazip ]] || die "官方 DEB 包名异常。"
[[ "$(dpkg-deb -f "$DEB_FILE" Version)" == "$VERSION" ]] || die "官方 DEB 版本异常。"
[[ "$(dpkg-deb -f "$DEB_FILE" Architecture)" == amd64 ]] || die "官方 DEB 架构异常。"

# 把同一个官方 DEB 安装到隔离构建环境，让 linuxdeploy 能解析应用及其依赖。
sudo apt-get install -y --no-install-recommends "$DEB_FILE"

# 把已经安装到构建环境的同一个 DEB 原样解包到 AppDir，保留上游目录布局。
dpkg-deb -x "$DEB_FILE" "$APPDIR"

PEAZIP_ROOT="$APPDIR/usr/lib/peazip"
ZH_CN_FILE="$APPDIR/usr/share/peazip/lang/zh-cn.txt"

# PeaZip 官方要求语言文件使用 UTF-8 BOM；仅在官方 DEB 缺失 BOM 时补入，中文正文保持原样。
ZH_CN_PREFIX="$(od -An -tx1 -N3 "$ZH_CN_FILE" | tr -d '[:space:]')"
if [[ "$ZH_CN_PREFIX" != efbbbf ]]; then
  ZH_CN_TEMP="$WORK_DIR/zh-cn.txt"
  printf '\xEF\xBB\xBF' > "$ZH_CN_TEMP"
  cat "$ZH_CN_FILE" >> "$ZH_CN_TEMP"
  install -m 0644 "$ZH_CN_TEMP" "$ZH_CN_FILE"
fi

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

###### 准备 AppRun ######

# 保留已经确认有效的显示、主题和 desktop Exec 启动方式，只固化各变量用途正确的最终路径。
cat > "$APPDIR/AppRun" <<'EOF_APPRUN'
#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"

export PATH="$HERE/usr/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$HERE/usr/lib/peazip:$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$HERE/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
export QT_PLUGIN_PATH="$HERE/usr/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
export QT_TRANSLATIONS_PATH="$HERE/usr/translations${QT_TRANSLATIONS_PATH:+:$QT_TRANSLATIONS_PATH}"
export GSETTINGS_SCHEMA_DIR="$HERE/usr/share/glib-2.0/schemas${GSETTINGS_SCHEMA_DIR:+:$GSETTINGS_SCHEMA_DIR}"
export NO_AT_BRIDGE=1

# PeaZip 用 AnsiString 读取 UTF-8 语言文件；使用 glibc 实际登记的 C.utf8，
# 避免 locale 名称未被识别后退回单字节代码页并把中文显示成 UTF-8 乱码。
export LANG=C.utf8
export LC_ALL=C.utf8

export QT_AUTO_SCREEN_SCALE_FACTOR=1
export QT_SCALE_FACTOR=1
export QT_STYLE_OVERRIDE=Adwaita-Dark
export QT_QPA_PLATFORMTHEME=Adwaita-Dark
export QT_QPA_PLATFORM=xcb
export QT_FONT_DPI=96

EXEC=$(grep -e '^Exec=.*' "${HERE}"/*.desktop | head -n 1 | cut -d "=" -f 2- | sed -e 's|%.||g')
exec ${EXEC} "$@"
EOF_APPRUN
chmod +x "$APPDIR/AppRun"

###### 核心打包 ######

# linuxdeploy 会扫描 AppDir 中全部 ELF。官方包内的 32 位旧后端依赖已淘汰的
# libncurses.so.5，因此先移出扫描范围，Qt 依赖部署完成后再原样放回。
BACKENDS_DIR="$WORK_DIR/peazip-backends"
mv "$PEAZIP_ROOT/res/bin" "$BACKENDS_DIR"

# 第二次 linuxdeploy 扫描 PeaZip 主程序时，优先找到上游随包的 Qt6Pas。
export LD_LIBRARY_PATH="$PEAZIP_ROOT${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# 原样执行已经验证有效的 Qt6 打包命令，由 linuxdeploy 部署 Qt6 并生成中间 AppImage。
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin qt --output appimage

# Qt6 依赖部署完成后，把官方归档后端原样恢复到 PeaZip 资源目录。
mv "$BACKENDS_DIR" "$PEAZIP_ROOT/res/bin"

###### 整理产物 ######

# 忽略 linuxdeploy 中间 AppImage，使用官方 appimagetool 和 Type 2 runtime
# 对同一个 AppDir 重新封装正式发布资产。
"$APPIMAGETOOL" -n "$APPDIR" "$OUTFILE" --runtime-file "$RUNTIME_FILE"

# 赋予最终 AppImage 执行权限。
chmod +x "$OUTFILE"
# 写入本次实际打包的软件版本，供正式发布流程读取。
printf '%s\n' "$VERSION" > "$DIST_DIR/version.txt"
# 输出最终 AppImage 的 SHA-256，供发布记录和资产完整性信息使用。
sha256sum "$OUTFILE"
