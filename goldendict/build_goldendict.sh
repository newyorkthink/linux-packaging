#!/usr/bin/env bash

# 任一步失败立即停止，只有正式封装成功后才记录软件版本。
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 只重建本项目的 source、AppDir 和 dist 构建目录。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" goldendict
# 安装 Ubuntu 官方仓库的原版 GoldenDict DEB 和所需运行组件，不编译主程序或依赖。
"$SCRIPT_DIR/../common/apt/install_packages.sh" goldendict qt5-qmake qttranslations5-l10n fcitx5-frontend-qt5 locales gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-libav
# 从本次实际安装的官方包读取版本，保留发行版修订号，不锁版本。
VERSION="$(dpkg-query -W -f='${Version}' goldendict)"
# 准备官方 linuxdeploy、Qt 插件、appimagetool 和 Type 2 runtime。
"$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" qt
# 下载官方 GStreamer 插件当前默认分支，公共入口记录所用提交。
"$SCRIPT_DIR/../common/github/download_default_branch_source.sh" linuxdeploy/linuxdeploy-plugin-gstreamer "$SOURCE_DIR/gstreamer-plugin.tar.gz"
# 解包官方插件源码。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" "$SOURCE_DIR/gstreamer-plugin.tar.gz" "$SOURCE_DIR/gstreamer-plugin"
# 把官方脚本插件放入 linuxdeploy 工具搜索路径。
install -m755 "$SOURCE_DIR"/gstreamer-plugin/*/linuxdeploy-plugin-gstreamer.sh "$TOOLS_DIR/linuxdeploy-plugin-gstreamer"
# 使用公共环境设置中间产物路径和免 FUSE 的构建方式。
source "$SCRIPT_DIR/../common/linuxdeploy/configure_environment.sh" "$TOOLS_DIR" "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"
# 明确使用 Ubuntu 的 Qt5 qmake，避免混用 Qt6。
export QMAKE=/usr/lib/qt5/bin/qmake
# 第一次 linuxdeploy 只初始化空 AppDir。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"
# 解包同版本官方 DEB，完整保留主程序、翻译、帮助、图标及许可证。
"$SCRIPT_DIR/../common/apt/download_and_extract_packages.sh" "$APPDIR" "goldendict=$VERSION"
# 使用上游支持的程序旁 locale 回退路径，不修改官方二进制。
ln -s ../share/goldendict/locale "$APPDIR/usr/bin/locale"
# 使用上游支持的程序旁 help 回退路径。
ln -s ../share/goldendict/help "$APPDIR/usr/bin/help"
# 创建中文字体、locale、Qt 输入法和翻译目录。
mkdir -p "$APPDIR/usr/share/fonts/truetype" "$APPDIR/usr/lib/locale" "$APPDIR/usr/etc/fonts" "$APPDIR/usr/plugins/platforminputcontexts" "$APPDIR/usr/translations"
# 带入基础包提供的文泉驿中文字体。
cp -a /usr/share/fonts/truetype/wqy "$APPDIR/usr/share/fonts/truetype/"
# 生成独立中文 locale，不修改宿主 locale 配置。
localedef --no-archive -i zh_CN -f UTF-8 "$APPDIR/usr/lib/locale/zh_CN.utf8"
QT_PLUGINS="$("$QMAKE" -query QT_INSTALL_PLUGINS)"
# 带入 Qt5 的 compose、IBus 和 Fcitx5 输入接口，由 linuxdeploy 扫描依赖。
cp -a "$QT_PLUGINS/platforminputcontexts/libcomposeplatforminputcontextplugin.so" "$QT_PLUGINS/platforminputcontexts/libibusplatforminputcontextplugin.so" "$QT_PLUGINS/platforminputcontexts/libfcitx5platforminputcontextplugin.so" "$APPDIR/usr/plugins/platforminputcontexts/"
# 带入 Qt 自身的中文翻译，应用翻译已由 make install 安装。
cp -a /usr/share/qt5/translations/*zh_CN.qm "$APPDIR/usr/translations/"
# 字体配置同时读取系统字体和包内中文字体。
cat > "$APPDIR/usr/etc/fonts/fonts.conf" <<'FONTS'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
  <dir prefix="relative">../../share/fonts</dir>
</fontconfig>
FONTS

# 在第二次 linuxdeploy 前写完整入口，由官方插件生成实际 hook 和 AppRun.wrapped。
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash
set -e
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# 优先使用包内可执行文件。
export PATH="$HERE/usr/bin${PATH:+:$PATH}"
# 优先使用包内运行库。
export LD_LIBRARY_PATH="$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
# 保留系统共享数据目录。
export XDG_DATA_DIRS="$HERE/usr/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
# 使用同一套 Qt5 插件，输入法选择沿用桌面会话。
export QT_PLUGIN_PATH="$HERE/usr/plugins"
# 使用包内 Qt 中文翻译。
export QT_TRANSLATIONS_PATH="$HERE/usr/translations"
# 读取包内中文 locale。
export LOCPATH="$HERE/usr/lib/locale"
# 新配置默认使用中文界面，已有用户界面语言设置仍由上游处理。
export LANG=zh_CN.UTF-8
# 设置中文翻译回退顺序。
export LANGUAGE=zh_CN:zh
# 使用中文消息语言。
export LC_MESSAGES=zh_CN.UTF-8
# 字体配置包含随包携带的中文字体。
export FONTCONFIG_FILE="$HERE/usr/etc/fonts/fonts.conf"
# 启动主程序并完整传递参数，用户配置仍由上游保存在家目录。
exec "$HERE/usr/bin/goldendict" "$@"
APPRUN
# 赋予入口执行权限。
chmod +x "$APPDIR/AppRun"
# 回到项目目录，保留标准两阶段 linuxdeploy 命令及输出插件。
cd "$SCRIPT_DIR"
# Qt 与 GStreamer 官方插件负责递归封装运行库、多媒体插件和启动 hook。
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin qt --plugin gstreamer --output appimage --desktop-file "$APPDIR/usr/share/applications/org.goldendict.GoldenDict.desktop" --icon-file "$APPDIR/usr/share/pixmaps/goldendict.png"
# 第二次 linuxdeploy 完成后统一整理生成入口的包内路径。
"$SCRIPT_DIR/../common/linuxdeploy/normalize_apprun_paths.sh" "$APPDIR"
# 使用官方 appimagetool 正式封装，并在成功后写入 dist/version.txt。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
