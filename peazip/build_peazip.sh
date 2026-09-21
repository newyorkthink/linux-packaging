#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

###### 准备构建环境 ######

# 公共入口统一设置标准路径，并清理、重建 source、AppDir、dist 和 tools。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" peazip

DEB_FILE="$SOURCE_DIR/peazip.deb"
PEAZIP_ROOT="$APPDIR/usr/lib/peazip"
ZH_CN_FILE="$APPDIR/usr/share/peazip/lang/zh-cn.txt"

# 通过公共 APT 入口安装 linuxdeploy 基础工具和 PeaZip 明确需要的 Qt6 构建、运行依赖。
"$SCRIPT_DIR/../common/apt/install_packages.sh" \
  build-essential git wget binutils patchelf appstream-util desktop-file-utils zsync dpkg zstd \
  qmake6 qt6-base-dev qt6-base-dev-tools qt6-qpa-plugins qt6-gtk-platformtheme \
  qt6-translations-l10n adwaita-qt6 fcitx5-frontend-qt6 \
  libxkbcommon-x11-0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
  libxcb-render-util0 libxcb-xinerama0 libxcb-xkb1

# 使用公共脚本动态下载并校验 linuxdeploy、Qt 插件、appimagetool 和 Type 2 runtime。
"$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" qt

###### 初始化 AppDir ######

# 通过公共入口运行第一次普通 linuxdeploy，并核对空 AppDir 初始化结果。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

###### 下载并安装 PeaZip ######

# 公共入口选择正式 semver Release、核对唯一 Qt6 amd64 DEB 与 GitHub SHA-256，并下载同一资产。
VERSION="$("$SCRIPT_DIR/../common/github/download_latest_stable_release_asset.sh" \
  peazip/PeaZip 'peazip_{version}.LINUX.Qt6-1_amd64.deb' "$DEB_FILE")"

[[ "$(dpkg-deb -f "$DEB_FILE" Package)" == peazip ]]
[[ "$(dpkg-deb -f "$DEB_FILE" Version)" == "$VERSION" ]]
[[ "$(dpkg-deb -f "$DEB_FILE" Architecture)" == amd64 ]]

# 把同一个官方 DEB 安装到隔离构建环境，让 linuxdeploy 能解析应用及其依赖。
"$SCRIPT_DIR/../common/apt/install_packages.sh" --no-update "$DEB_FILE"

# 由公共归档入口把同一个官方 DEB 按上游布局解包到 AppDir。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" "$DEB_FILE" "$APPDIR"

# PeaZip 官方要求语言文件使用 UTF-8 BOM；仅在官方 DEB 缺失 BOM 时补入，中文正文保持原样。
ZH_CN_PREFIX="$(od -An -tx1 -N3 "$ZH_CN_FILE" | tr -d '[:space:]')"
if [[ "$ZH_CN_PREFIX" != efbbbf ]]; then
  ZH_CN_TEMP="$SOURCE_DIR/zh-cn.txt"
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

# PeaZip 11.2.0 会把语言文件的 UTF-8 字节按单字节字符交给 Qt6Pas。
# 在唯一的 Pascal WideString -> Qt QString 边界严格还原这类乱码。
gcc -std=c11 -O2 -fPIC -shared -Wall -Wextra -Werror -Wpedantic \
  "$SCRIPT_DIR/peazip_utf8_fix.c" \
  -o "$PEAZIP_ROOT/libpeazip-utf8-fix.so" \
  -ldl

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

# 只给 PeaZip 主进程加载 UTF-8 兼容层；库构造函数会立即恢复原环境，
# 避免 PeaZip 启动的 7z 等子进程继续继承该兼容层。
export PEAZIP_ORIGINAL_LD_PRELOAD="${LD_PRELOAD-}"
export LD_PRELOAD="$HERE/usr/lib/peazip/libpeazip-utf8-fix.so${LD_PRELOAD:+:$LD_PRELOAD}"

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

# 公共入口设置技术栈无关的 linuxdeploy 环境；Qt6 qmake 与 NO_STRIP 仍由当前项目追加。
source "$SCRIPT_DIR/../common/linuxdeploy/configure_environment.sh" \
  "$TOOLS_DIR" "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"
export QMAKE=qmake6
export NO_STRIP=1

# linuxdeploy 会扫描 AppDir 中全部 ELF。官方包内的 32 位旧后端依赖已淘汰的
# libncurses.so.5，因此先移出扫描范围，Qt 依赖部署完成后再原样放回。
BACKENDS_DIR="$SOURCE_DIR/peazip-backends"
mv "$PEAZIP_ROOT/res/bin" "$BACKENDS_DIR"

# 第二次 linuxdeploy 扫描 PeaZip 主程序时，优先找到上游随包的 Qt6Pas。
export LD_LIBRARY_PATH="$PEAZIP_ROOT${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# 原样执行已经验证有效的 Qt6 打包命令，由 linuxdeploy 部署 Qt6 并生成中间 AppImage。
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin qt --output appimage

# Qt6 依赖部署完成后，把官方归档后端原样恢复到 PeaZip 资源目录。
mv "$BACKENDS_DIR" "$PEAZIP_ROOT/res/bin"

###### 整理产物 ######

# 公共入口使用官方 appimagetool 和 Type 2 runtime 封装正式资产，并在成功后写入版本元数据。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" \
  "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
