#!/usr/bin/env bash

# 任一步失败立即停止，只有正式封装成功后才记录软件版本。
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 只重建本项目的 source、AppDir 和 dist 构建目录。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" goldendict
# 在 Ubuntu 24.04 安装 Qt5、词典格式、中文转换和音频编译依赖。
"$SCRIPT_DIR/../common/apt/install_packages.sh" qtbase5-dev qt5-qmake qttools5-dev qttools5-dev-tools qtdeclarative5-dev libqt5webkit5-dev libqt5svg5-dev libqt5x11extras5-dev qtmultimedia5-dev libqt5multimedia5-plugins qttranslations5-l10n fcitx5-frontend-qt5 locales libvorbis-dev zlib1g-dev libhunspell-dev libxtst-dev liblzo2-dev libbz2-dev libao-dev libpulse-dev libavutil-dev libavformat-dev libavcodec-dev libswresample-dev libtiff-dev libeb16-dev libopencc-dev liblzma-dev libzstd-dev gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-libav
# 下载官方最新稳定版源码；公共入口输出本次实际版本。
VERSION="$("$SCRIPT_DIR/../common/github/download_latest_stable_source.sh" goldendict/goldendict "$SOURCE_DIR/goldendict.tar.gz")"
# 由公共入口解包源码，保留上游目录结构。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" "$SOURCE_DIR/goldendict.tar.gz" "$SOURCE_DIR/goldendict"
# 下载 libao 最新正式数字标签源码，以支持包内音频插件路径。
AO_VERSION="$("$SCRIPT_DIR/../common/github/download_latest_stable_source.sh" xiph/libao "$SOURCE_DIR/libao.tar.gz" tags)"
# 解包音频输出库源码。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" "$SOURCE_DIR/libao.tar.gz" "$SOURCE_DIR/libao"
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
# 禁止上游 git describe 把外层打包仓库的标签当成软件版本。
export GIT_CEILING_DIRECTORIES="$SOURCE_DIR"
# 第一次 linuxdeploy 只初始化空 AppDir。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

# 修正本应用的资源定位和版本；上游结构变化时明确失败，不静默漏补丁。
python3 - "$SOURCE_DIR" "$VERSION" <<'PY'
from pathlib import Path
import re
import sys
root, version = Path(sys.argv[1]), sys.argv[2]
gd, = (root / "goldendict").glob("*/goldendict.pro")
ao, = (root / "libao").glob("*/src/audio_out.c")
def replace_one(path, old, new):
    text = path.read_text()
    if text.count(old) != 1:
        raise SystemExit(f"上游源码结构变化，请复核补丁：{path.name}")
    path.write_text(text.replace(old, new))
text, count = re.subn(r"(?m)^VERSION\s*=.*$", f"VERSION = {version}", gd.read_text())
if count != 1:
    raise SystemExit("无法设置上游正式版本")
gd.write_text(text)
replace_one(gd.parent / "config.cc", "return PROGRAM_DATA_DIR;", 'return QCoreApplication::applicationDirPath() + "/../share/goldendict/";')
replace_one(gd.parent / "chinese.cc", 'QString configDir = "";', 'QString configDir = QCoreApplication::applicationDirPath() + "/../share/opencc/";')
replace_one(ao, "#ifndef SHARED_LIB_EXT", '''static const char *goldendict_ao_plugin_path(void)
{
    const char *path = getenv("GOLDENDICT_AO_PLUGIN_PATH");
    return path && *path ? path : AO_PLUGIN_PATH;
}
#undef AO_PLUGIN_PATH
#define AO_PLUGIN_PATH goldendict_ao_plugin_path()
#ifndef SHARED_LIB_EXT''')
PY

# 进入 libao 源码目录，保留 FFmpeg 音频后端的包内输出插件。
cd "$SOURCE_DIR"/libao/*/
# 生成上游 autotools 构建文件。
./autogen.sh
# 使用桌面 PulseAudio 或 PipeWire-Pulse 服务，不打包音频服务进程。
./configure --prefix=/usr --libdir=/usr/lib --disable-static --enable-pulse --disable-alsa --disable-esd --disable-arts --disable-nas
# 并行编译音频库和插件。
make -j"$(nproc)"
# 暂存音频库，插件使用固定的包内相对目录。
make DESTDIR="$SOURCE_DIR/ao-install" plugindir=/usr/lib/goldendict-ao install
# 创建运行库、插件和许可证目录。
mkdir -p "$APPDIR/usr/lib/goldendict-ao" "$APPDIR/usr/share/doc/libao"
# 只复制运行库，不带开发文件。
cp -a "$SOURCE_DIR"/ao-install/usr/lib/libao.so* "$APPDIR/usr/lib/"
# 复制 PulseAudio 输出插件，缺失时复制命令直接失败。
install -m755 "$SOURCE_DIR/ao-install/usr/lib/goldendict-ao/libpulse.so" "$APPDIR/usr/lib/goldendict-ao/"
# 保留音频库许可证和实际来源版本。
install -m644 COPYING "$APPDIR/usr/share/doc/libao/"
printf '%s\n' "$AO_VERSION" > "$APPDIR/usr/share/doc/libao/version.txt"

# 进入 GoldenDict 官方稳定版源码目录。
cd "$SOURCE_DIR"/goldendict/*/
# 生成 release 构建，启用简繁转换及 ZIM 词典支持。
"$QMAKE" goldendict.pro "CONFIG+=release chinese_conversion_support zim_support" "PREFIX=/usr"
# 编译主程序，每条关键命令独立一行。
make -j"$(nproc)"
# 安装主程序、上游翻译、帮助、desktop 和图标到 AppDir。
make INSTALL_ROOT="$APPDIR" install
# 保留主程序许可证。
install -Dm644 LICENSE.txt "$APPDIR/usr/share/doc/goldendict/LICENSE.txt"
# 复制 OpenCC 简繁转换配置及词库。
cp -a /usr/share/opencc "$APPDIR/usr/share/"
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
# FFmpeg 后端的 libao 从包内加载 PulseAudio 输出插件。
export GOLDENDICT_AO_PLUGIN_PATH="$HERE/usr/lib/goldendict-ao"
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
