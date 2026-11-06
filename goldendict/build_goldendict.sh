#!/usr/bin/env bash

############# 初始化脚本 #############

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

############# 准备构建目录 #############

# 设置构建路径，并清理、重建当前应用的 source、AppDir 和 dist 目录。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" goldendict

############# 准备构建环境 #############

# 安装构建工具和应用所需的依赖包。
"$SCRIPT_DIR/../common/apt/install_packages.sh" goldendict qt5-qmake qtdeclarative5-dev-tools qttranslations5-l10n fcitx5-frontend-qt5 locales libao4 libpulse0 gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-libav

# 读取本次打包使用的版本。
VERSION="$(dpkg-query -W -f='${Version}' goldendict)"

############# 下载打包工具 #############

# 下载并校验打包工具及所需插件，随后加载构建环境配置。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" qt,gstreamer "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"

# 指定 Qt 查询工具。
export QMAKE=/usr/lib/qt5/bin/qmake

# 本程序专属处理：指定 Qt5 的 QML 扫描环境，避免混用 Qt6。
export QT_SELECT=qt5

############ 初始化 AppDir #############

# 首次运行 linuxdeploy，创建 AppDir 的基础目录。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

############ 下载并准备应用 #############

# 本程序专属处理：下载并解包与当前安装版本一致的官方 DEB，保留完整发行版版本号。
"$SCRIPT_DIR/../common/apt/download_and_extract_packages.sh" "$APPDIR" "goldendict=$VERSION"

########## 准备桌面资源和运行库 #########

# 本程序专属处理：保留上游支持的程序旁 locale 资源访问路径。
ln -s ../share/goldendict/locale "$APPDIR/usr/bin/locale"

# 本程序专属处理：保留上游支持的程序旁 help 资源访问路径。
ln -s ../share/goldendict/help "$APPDIR/usr/bin/help"

# 本程序专属处理：创建中文字体、locale、Qt 输入法和翻译目录。
mkdir -p "$APPDIR/usr/share/fonts/truetype" "$APPDIR/usr/lib/locale" "$APPDIR/usr/etc/fonts" "$APPDIR/usr/plugins/platforminputcontexts" "$APPDIR/usr/translations"

# 本程序专属处理：带入基础包提供的文泉驿中文字体。
cp -a /usr/share/fonts/truetype/wqy "$APPDIR/usr/share/fonts/truetype/"

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
"$SCRIPT_DIR/../common/linuxdeploy/prepare_locale.sh" zh_CN UTF-8 "$APPDIR/usr/lib/locale/zh_CN.utf8"

# 本程序专属处理：读取当前 Qt5 的插件目录。
QT_PLUGINS="$("$QMAKE" -query QT_INSTALL_PLUGINS)"

# 本程序专属处理：带入 Qt5 的 compose、IBus 和 Fcitx5 输入接口，由 linuxdeploy 扫描依赖。
cp -a "$QT_PLUGINS/platforminputcontexts/libcomposeplatforminputcontextplugin.so" "$QT_PLUGINS/platforminputcontexts/libibusplatforminputcontextplugin.so" "$QT_PLUGINS/platforminputcontexts/libfcitx5platforminputcontextplugin.so" "$APPDIR/usr/plugins/platforminputcontexts/"

# 本程序专属处理：带入 Qt 自身的中文翻译，应用翻译已从官方 DEB 解包。
cp -a /usr/share/qt5/translations/*zh_CN.qm "$APPDIR/usr/translations/"

# 本程序专属处理：配置系统字体和包内中文字体的搜索路径。
cat > "$APPDIR/usr/etc/fonts/fonts.conf" <<'FONTS'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
  <dir prefix="relative">../../share/fonts</dir>
</fontconfig>
FONTS

############# 准备 AppRun ##############

# 在 AppDir 根目录创建完整的 AppRun 启动脚本。
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash

# 本程序专属处理：在命令执行失败时退出，沿用原启动入口的退出行为。
set -e

# 本程序专属处理：清除外层 AppImage 遗留的 gconv 搜索路径，避免 UTF-16 转换模块无法加载。
unset GCONV_PATH

# 获取脚本所在目录的绝对路径。
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 本程序专属处理：保留 AppDir 的目录描述符，让 libao 能通过稳定的包内绝对路径加载输出模块。
exec 9<"$HERE"

# 设置程序、运行库和共享数据的搜索路径。
export PATH="$HERE/usr/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$HERE/usr/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

# 本程序专属处理：使用同一套 Qt5 插件，输入法选择沿用桌面会话。
export QT_PLUGIN_PATH="$HERE/usr/plugins"

# 本程序专属处理：使用包内 Qt 中文翻译。
export QT_TRANSLATIONS_PATH="$HERE/usr/translations"

# 设置简体中文界面环境。
export LOCPATH="$HERE/usr/lib/locale"
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_MESSAGES=zh_CN.UTF-8

# 本程序专属处理：字体配置包含随包携带的中文字体。
export FONTCONFIG_FILE="$HERE/usr/etc/fonts/fonts.conf"

# 启动包内程序，并保留传入的命令行参数。
exec "$HERE/usr/bin/goldendict" "$@"
APPRUN

# 为启动脚本添加执行权限。
chmod +x "$APPDIR/AppRun"

############### 核心打包 ###############

# 本程序专属处理：回到项目目录，沿用现有 linuxdeploy 相对路径调用。
cd "$SCRIPT_DIR"

# 再次运行 linuxdeploy，部署运行资源并生成中间 AppImage。
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin qt --plugin gstreamer --output appimage --desktop-file "$APPDIR/usr/share/applications/org.goldendict.GoldenDict.desktop" --icon-file "$APPDIR/usr/share/pixmaps/goldendict.png"

############### 整理产物 ###############

# 本程序专属处理：在依赖部署后补齐 libao 输出模块，并重定位包内插件路径。
"$SCRIPT_DIR/patches/prepare_libao_runtime.sh" "$APPDIR"

# 本程序专属处理：按最终 AppDir 结构整理已有启动入口中的包内搜索路径。
"$SCRIPT_DIR/../common/linuxdeploy/normalize_apprun_paths.sh" "$APPDIR"

# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
