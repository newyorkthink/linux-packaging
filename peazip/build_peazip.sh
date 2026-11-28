#!/usr/bin/env bash

############# 初始化脚本 #############

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

############# 准备构建目录 #############

# 设置构建路径，并清理、重建当前应用的 source、AppDir 和 dist 目录。
source "$SCRIPT_DIR/../Common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" "peazip"

############# 准备构建环境 #############

# 安装构建工具和应用所需的依赖包。
"$SCRIPT_DIR/../Common/apt/install_packages.sh" build-essential git wget binutils patchelf appstream-util desktop-file-utils zsync dpkg zstd qmake6 qt6-base-dev qt6-base-dev-tools qt6-qpa-plugins qt6-gtk-platformtheme qt6-translations-l10n adwaita-qt6 fcitx5-frontend-qt6 libxkbcommon-x11-0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-render-util0 libxcb-xinerama0 libxcb-xkb1

############# 下载打包工具 #############

# 下载并校验打包工具及所需插件，随后加载构建环境配置。
source "$SCRIPT_DIR/../Common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" qt "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"

############ 初始化 AppDir #############

# 首次运行 linuxdeploy，创建 AppDir 的基础目录。
"$SCRIPT_DIR/../Common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

############ 下载并准备应用 #############

# 下载并校验官方安装包，将其安装到构建环境并解包到 AppDir，成功后返回版本号。
VERSION="$("$SCRIPT_DIR/../Common/github/install_and_extract_latest_stable_release_deb.sh" peazip/PeaZip 'peazip_{version}.LINUX.Qt6-1_amd64.deb' "$SOURCE_DIR/peazip.deb" "$APPDIR" peazip amd64)"

########## 准备桌面资源和运行库 #########

# 本程序专属处理：定位官方程序目录与简体中文语言文件。
PEAZIP_ROOT="$APPDIR/usr/lib/peazip"
ZH_CN_FILE="$APPDIR/usr/share/peazip/lang/zh-cn.txt"

# 本程序专属处理：只在中文语言文件缺少 UTF-8 BOM 时补入，保留官方正文。
ZH_CN_PREFIX="$(od -An -tx1 -N3 "$ZH_CN_FILE" | tr -d '[:space:]')"
if [[ "$ZH_CN_PREFIX" != efbbbf ]]; then
  ZH_CN_TEMP="$SOURCE_DIR/zh-cn.txt"
  printf '\xEF\xBB\xBF' > "$ZH_CN_TEMP"
  cat "$ZH_CN_FILE" >> "$ZH_CN_TEMP"
  install -m 0644 "$ZH_CN_TEMP" "$ZH_CN_FILE"
fi

# 本程序专属处理：扫描前把官方绝对链接临时换成等价相对链接。
ln -sfn ../lib/peazip/peazip "$APPDIR/usr/bin/peazip"
ln -sfn ../../../share/peazip "$PEAZIP_ROOT/res/share"

# 本程序专属处理：准备 Qt6Pas 和桌面主题插件的部署目录，复制随包 Qt6Pas。
mkdir -p "$APPDIR/usr/lib" "$APPDIR/usr/plugins/styles" "$APPDIR/usr/plugins/platformthemes"
cp -a "$PEAZIP_ROOT"/libQt6Pas.so.6* "$APPDIR/usr/lib/"

# 本程序专属处理：从当前 Qt6 环境收集 Adwaita 和 GTK3 主题插件及其运行库。
QT6_PLUGIN_ROOT="$(qmake6 -query QT_INSTALL_PLUGINS)"
QT6_LIB_ROOT="$(qmake6 -query QT_INSTALL_LIBS)"
cp -a "$QT6_PLUGIN_ROOT/styles/adwaita.so" "$APPDIR/usr/plugins/styles/"
cp -a "$QT6_PLUGIN_ROOT/platformthemes/libqgtk3.so" "$APPDIR/usr/plugins/platformthemes/"
cp -a "$QT6_LIB_ROOT"/libadwaitaqt6.so.1* "$APPDIR/usr/lib/"
cp -a "$QT6_LIB_ROOT"/libadwaitaqt6priv.so.1* "$APPDIR/usr/lib/"

# 本程序专属处理：原样编译已验证的 UTF-8 兼容层。
gcc -std=c11 -O2 -fPIC -shared -Wall -Wextra -Werror -Wpedantic \
  "$SCRIPT_DIR/peazip_utf8_fix.c" \
  -o "$PEAZIP_ROOT/libpeazip-utf8-fix.so" \
  -ldl

############# 准备 AppRun ##############

# 在 AppDir 根目录创建完整的 AppRun 启动脚本。
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash

# 获取脚本所在目录的绝对路径。
HERE="$(dirname "$(readlink -f "${0}")")"

# 设置程序、运行库和共享数据的搜索路径。
export PATH="$HERE/usr/lib/peazip:$HERE/usr/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$HERE/usr/lib/peazip:$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$HERE/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

# 本程序专属处理：设置包内 Qt 插件和翻译资源的搜索目录。
export QT_PLUGIN_PATH="$HERE/usr/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
export QT_TRANSLATIONS_PATH="$HERE/usr/translations${QT_TRANSLATIONS_PATH:+:$QT_TRANSLATIONS_PATH}"

# 本程序专属处理：沿用包内 GTK schema 搜索路径和辅助功能兼容设置。
export GSETTINGS_SCHEMA_DIR="$HERE/usr/share/glib-2.0/schemas${GSETTINGS_SCHEMA_DIR:+:$GSETTINGS_SCHEMA_DIR}"
export NO_AT_BRIDGE=1

# 本程序专属处理：仅为 PeaZip 主进程预加载 UTF-8 兼容层，由库恢复原环境。
export PEAZIP_ORIGINAL_LD_PRELOAD="${LD_PRELOAD-}"
export LD_PRELOAD="$HERE/usr/lib/peazip/libpeazip-utf8-fix.so${LD_PRELOAD:+:$LD_PRELOAD}"

# 设置界面自动缩放。
export QT_AUTO_SCREEN_SCALE_FACTOR=1
export QT_SCALE_FACTOR=1

# 本程序专属处理：沿用 Adwaita-Dark 样式和平台主题。
export QT_STYLE_OVERRIDE=Adwaita-Dark
export QT_QPA_PLATFORMTHEME=Adwaita-Dark

# 本程序专属处理：沿用已验证的 XCB 显示后端。
export QT_QPA_PLATFORM=xcb

# 设置界面字体 DPI。
export QT_FONT_DPI=96

# 本程序专属处理：沿用已实机确认的 desktop Exec 解析方式，并转交命令行参数。
EXEC=$(grep -e '^Exec=.*' "${HERE}"/*.desktop | head -n 1 | cut -d "=" -f 2- | sed -e 's|%.||g')
exec ${EXEC} "$@"
APPRUN

# 为启动脚本添加执行权限。
chmod +x "$APPDIR/AppRun"

############### 核心打包 ###############

# 指定 Qt 查询工具。
export QMAKE=qmake6

# 本程序专属处理：保留运行库的原始符号。
export NO_STRIP=1

# 本程序专属处理：扫描前临时移出依赖旧版 libncurses 的 32 位归档后端。
BACKENDS_DIR="$SOURCE_DIR/peazip-backends"
mv "$PEAZIP_ROOT/res/bin" "$BACKENDS_DIR"

# 本程序专属处理：扫描时优先使用官方安装包自带的 Qt6Pas。
export LD_LIBRARY_PATH="$PEAZIP_ROOT${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# 再次运行 linuxdeploy，部署运行资源并生成中间 AppImage。
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin qt --output appimage

############### 整理产物 ###############

# 本程序专属处理：Qt 部署完成后原样恢复官方归档后端。
mv "$BACKENDS_DIR" "$PEAZIP_ROOT/res/bin"

# 本程序专属处理：移除最终包中含 .. 的程序转发链接，保持 7-Zip 可解包。
rm -f "$APPDIR/usr/bin/peazip"

# 本程序专属处理：将 res/share 的相对链接改为真实资源目录，保留主程序所需的相邻布局。
rm -f "$PEAZIP_ROOT/res/share"
mkdir -p "$PEAZIP_ROOT/res/share"
cp -a "$APPDIR/usr/share/peazip/." "$PEAZIP_ROOT/res/share/"

# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../Common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
