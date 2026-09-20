#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SOURCE_DIR="$SCRIPT_DIR/source"
APPDIR="$SCRIPT_DIR/AppDir"
DIST_DIR="$SCRIPT_DIR/dist"
OUTFILE="$DIST_DIR/xnconvert.AppImage"
CHECKSUMS="$SOURCE_DIR/XnConvert-CHECKSUMS.txt"
DEB="$SOURCE_DIR/XnConvert.deb"
TOOLS_DIR="$SOURCE_DIR/tools"
APPIMAGETOOL="$TOOLS_DIR/appimagetool-x86_64.AppImage"
RUNTIME_FILE="$TOOLS_DIR/runtime-x86_64"
INTERMEDIATE_APPIMAGE="$SOURCE_DIR/xnconvert-linuxdeploy-intermediate.AppImage"
DESKTOP_FILE="$APPDIR/usr/share/applications/XnConvert.desktop"
ICON_FILE="$APPDIR/opt/XnConvert/xnconvert.png"

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

# 根据当前权限选择 apt-get 调用方式，root 环境不经过 sudo。
if ((EUID == 0)); then
  APT=(apt-get)
elif command -v sudo >/dev/null 2>&1; then
  APT=(sudo apt-get)
else
  die "安装构建依赖需要 root 或 sudo"
fi

# 安装下载、DEB 解包、Qt5 部署、中文输入和 XCB 平台插件所需依赖。
"${APT[@]}" update
DEBIAN_FRONTEND=noninteractive "${APT[@]}" install -y --no-install-recommends \
  ca-certificates coreutils curl desktop-file-utils dpkg file findutils gawk grep jq sed xz-utils \
  qtchooser qt5-qmake qt5-qmake-bin qtbase5-dev qtbase5-dev-tools libqt5svg5 \
  qttranslations5-l10n qt5-gtk-platformtheme qtwayland5 \
  fcitx5-frontend-qt5 libfcitx5-qt1 \
  libxkbcommon-x11-0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
  libxcb-render-util0 libxcb-xinerama0 libxcb-xkb1

# 确认后续构建依赖的基础命令均可用。
for command_name in curl desktop-file-validate dpkg-deb find jq readlink sed sha256sum sort; do
  command -v "$command_name" >/dev/null 2>&1 || die "缺少必需命令：$command_name"
done

# XnConvert 使用 Qt5，Qt 插件必须使用同一主版本的真实 qmake。
QT5_BIN_DIR=/usr/lib/qt5/bin
[[ -x "$QT5_BIN_DIR/qmake" ]] || die "缺少 Qt5 工具：$QT5_BIN_DIR/qmake"

###### 下载打包工具 ######

# 使用公共脚本动态下载并校验 linuxdeploy、Qt 插件、appimagetool 和 Type 2 runtime。
"$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" qt

###### 初始化 AppDir ######

# 配置 linuxdeploy、Qt5 qmake 和中间输出位置。
export ARCH=x86_64
export APPIMAGE_EXTRACT_AND_RUN=1
export QT_SELECT=qt5
export PATH="$QT5_BIN_DIR:$TOOLS_DIR:$PATH"
export QMAKE="$QT5_BIN_DIR/qmake"
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

###### 下载并准备 XnConvert ######

# 从 XnConvert 官方校验清单动态解析当前最新稳定版 Linux x64 DEB。
"$SCRIPT_DIR/../common/download/download_file.sh" \
  "https://download.xnview.com/versions/XnConvert/XnConvert-CHECKSUMS.txt" \
  "$CHECKSUMS"
sed -i 's/\r$//' "$CHECKSUMS"

DEB_NAME="$(
  awk '{print $2}' "$CHECKSUMS" |
    grep -E '^XnConvert-[0-9]+(\.[0-9]+)+-linux-x64\.deb$' |
    sort -V |
    tail -n 1
)"
[[ -n "$DEB_NAME" ]] || die "官方校验清单中没有稳定版 Linux x64 DEB"
VERSION="$(sed -nE 's/^XnConvert-([0-9]+(\.[0-9]+)+)-linux-x64\.deb$/\1/p' <<< "$DEB_NAME")"
[[ -n "$VERSION" ]] || die "无法从 $DEB_NAME 解析 XnConvert 版本"
DEB_URL="https://download.xnview.com/versions/XnConvert/$DEB_NAME"
DEB_SHA256="$(awk -v name="$DEB_NAME" '$2 == name {print $1; exit}' "$CHECKSUMS")"
[[ "$DEB_SHA256" =~ ^[[:xdigit:]]{64}$ ]] || die "官方 DEB 没有有效的 SHA-256"

printf '[XnConvert] official stable source: %s\n' "$DEB_URL"
"$SCRIPT_DIR/../common/download/download_file.sh" "$DEB_URL" "$DEB" "$DEB_SHA256"

# 把同一官方 DEB 安装到隔离构建环境供依赖扫描，并按上游布局解压到 AppDir。
DEBIAN_FRONTEND=noninteractive "${APT[@]}" install -y --no-install-recommends "$DEB"
dpkg-deb -x "$DEB" "$APPDIR"

[[ -x "$APPDIR/opt/XnConvert/XnConvert" ]] || die "缺少 XnConvert 主程序"
[[ -x "$APPDIR/usr/bin/xnconvert" ]] || die "缺少 XnConvert 官方命令入口"
[[ -f "$DESKTOP_FILE" ]] || die "缺少 XnConvert desktop 文件"
[[ -f "$ICON_FILE" ]] || die "缺少 XnConvert 图标"
[[ -f "$APPDIR/opt/XnConvert/lib/platforms/libqxcb.so" ]] || die "缺少 XnConvert 自带 qxcb 插件"

# 官方命令入口原本写死系统 /opt；保留这个真实入口，但统一转入根 AppRun 启动链。
cat > "$APPDIR/usr/bin/xnconvert" <<'EOF_LAUNCHER'
#!/usr/bin/env bash
set -Eeuo pipefail

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "$HERE/../..")"

exec "$ROOT/AppRun" "$@"
EOF_LAUNCHER
chmod +x "$APPDIR/usr/bin/xnconvert"

# 官方 desktop 使用绝对图标路径；改成 AppImage 可发现的图标名称。
sed -i 's|^Icon=.*|Icon=xnconvert|' "$DESKTOP_FILE"
desktop-file-validate "$DESKTOP_FILE"

###### 准备 Qt5 运行资源 ######

# 保留已经验证的 Qt5 翻译、XCB 平台库和图标部署方式。
mkdir -p \
  "$APPDIR/usr/lib" \
  "$APPDIR/usr/translations" \
  "$APPDIR/usr/share/icons/hicolor/256x256/apps"
if [[ -d /usr/share/qt5/translations ]]; then
  cp -a /usr/share/qt5/translations/. "$APPDIR/usr/translations/"
fi
cp -a "$APPDIR/opt/XnConvert/lib"/libQt5XcbQpa.so* "$APPDIR/usr/lib/"
cp -a "$ICON_FILE" "$APPDIR/usr/share/icons/hicolor/256x256/apps/xnconvert.png"
[[ -e "$APPDIR/usr/lib/libQt5XcbQpa.so.5" ]] || die "缺少 Qt5 XCB 平台运行库"

###### 核心打包 ######

# 应用文件进入 AppDir 后，在第二次 linuxdeploy 前写入完整根 AppRun。
# Qt linuxdeploy 会自动把它保存为 AppRun.wrapped，并生成加载 Qt hook 的顶层 AppRun。
cat > "$APPDIR/AppRun" <<'EOF_APPRUN'
#!/usr/bin/env bash
set -Eeuo pipefail

HERE="$(dirname "$(readlink -f "${0}")")"

# 保留中文界面环境；输入法仍由 Qt 插件和宿主桌面负责。
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh

# 所有 linuxdeploy AppRun 都保留 AppDir/usr 下的 bin、lib、share 三个基础搜索目录。
export PATH="$HERE/opt/XnConvert:$HERE/usr/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$HERE/opt/XnConvert/lib:$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$HERE/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

# XnConvert 自带 Qt plugin 位于 opt/XnConvert/lib，中文输入插件由 linuxdeploy 放入 usr/plugins。
# opt/XnConvert/Plugins 是应用自己的图片格式解码库，不属于 QT_PLUGIN_PATH。
export QT_PLUGIN_PATH="$HERE/opt/XnConvert/lib:$HERE/usr/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
export QT_QPA_PLATFORM_PLUGIN_PATH="$HERE/opt/XnConvert/lib/platforms:$HERE/usr/plugins/platforms${QT_QPA_PLATFORM_PLUGIN_PATH:+:$QT_QPA_PLATFORM_PLUGIN_PATH}"
# XnConvert 会读取自身 language 目录；linuxdeploy 同时把对应翻译链接到 usr/translations。
export QT_TRANSLATIONS_PATH="$HERE/usr/translations${QT_TRANSLATIONS_PATH:+:$QT_TRANSLATIONS_PATH}"
export QT_QPA_PLATFORM=xcb

exec "$HERE/opt/XnConvert/XnConvert" "$@"
EOF_APPRUN
chmod +x "$APPDIR/AppRun"

# 第二次 linuxdeploy 扫描上游 /opt 布局时，优先使用 XnConvert 自带运行库。
export LD_LIBRARY_PATH="$APPDIR/opt/XnConvert/lib:$APPDIR/opt/XnConvert/Plugins:$APPDIR/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export QMAKE="$QT5_BIN_DIR/qmake"

# XnConvert 使用 Qt5；第二次 linuxdeploy 部署 Qt 资源并完成 AppRun 包装。
export ARCH=x86_64; linuxdeploy \
  --appdir AppDir \
  --desktop-file "$DESKTOP_FILE" \
  --icon-file "$ICON_FILE" \
  --plugin qt \
  --output appimage

# 新版正式成品尚待用户确认，先按最终 AppDir 整理 AppRun 中的路径型 export。
"$SCRIPT_DIR/../common/linuxdeploy/normalize_apprun_paths.sh" "$APPDIR"

###### 整理产物 ######

# 忽略 linuxdeploy 中间 AppImage，使用官方 appimagetool 和 Type 2 runtime
# 对同一个 AppDir 重新封装正式发布资产。
"$APPIMAGETOOL" -n "$APPDIR" "$OUTFILE" --runtime-file "$RUNTIME_FILE"
[[ -s "$OUTFILE" ]] || die "最终 AppImage 未生成"
chmod +x "$OUTFILE"

# 构建成功后输出统一的软件版本元数据和正式资产 SHA-256。
printf '%s\n' "$VERSION" > "$DIST_DIR/version.txt"
sha256sum "$OUTFILE"
