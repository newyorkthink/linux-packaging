#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# XnView MP 自带较旧的 Qt 和媒体运行库，因此在 Ubuntu 22.04 中完成实际打包，
# 避免 linuxdeploy 混入 Ubuntu 24.04 的媒体库。
if [[ "${GITHUB_ACTIONS:-}" == "true" && "${XNVIEWMP_JAMMY_INNER:-0}" != "1" ]]; then
  command -v docker >/dev/null 2>&1 || {
    echo "错误：XnView MP 的 Jammy 构建需要 Docker。" >&2
    exit 1
  }
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  exec docker run --rm \
    -e XNVIEWMP_JAMMY_INNER=1 \
    -e CI=1 \
    -e GH_TOKEN="${GH_TOKEN:-}" \
    -v "$REPO_ROOT:/workspace" \
    -w /workspace/xnviewmp \
    ubuntu:22.04 \
    bash ./build_xnviewmp.sh
fi

SOURCE_DIR="$SCRIPT_DIR/source"
APPDIR="$SCRIPT_DIR/AppDir"
DIST_DIR="$SCRIPT_DIR/dist"
OUTFILE="$DIST_DIR/xnviewmp.AppImage"
EXTRACT_DIR="$SOURCE_DIR/extracted"
CHECKSUMS="$SOURCE_DIR/XnView_MP-CHECKSUMS.txt"
TOOLS_DIR="$SOURCE_DIR/tools"
LINUXDEPLOY="$TOOLS_DIR/linuxdeploy-x86_64.AppImage"
QT_PLUGIN="$TOOLS_DIR/linuxdeploy-plugin-qt-x86_64.AppImage"
APPIMAGETOOL="$TOOLS_DIR/appimagetool-x86_64.AppImage"
RUNTIME_FILE="$TOOLS_DIR/runtime-x86_64"
INTERMEDIATE_APPIMAGE="$SOURCE_DIR/xnviewmp-linuxdeploy-intermediate.AppImage"

## 输出明确错误并立即终止构建。
die() {
  echo "错误：$*" >&2
  exit 1
}

## 从官方 continuous Release 下载当前打包工具并校验官方 SHA-256。
download_tool() {
  local repo="$1" asset="$2" output="$3" metadata url digest

  metadata="$(curl -fsSL --retry 3 --retry-all-errors --connect-timeout 20 --max-time 120 \
    "${api_headers[@]}" "https://api.github.com/repos/$repo/releases/tags/continuous")"
  url="$(jq -er --arg name "$asset" '.assets[] | select(.name == $name) | .browser_download_url' <<< "$metadata")"
  digest="$(jq -er --arg name "$asset" '.assets[] | select(.name == $name) | .digest' <<< "$metadata")"
  [[ "$digest" =~ ^sha256:[[:xdigit:]]{64}$ ]] || die "官方工具没有有效的 SHA-256：$repo/$asset"

  curl -fL --retry 3 --retry-all-errors --connect-timeout 20 --max-time 300 \
    "$url" -o "$output"
  printf '%s  %s\n' "${digest#sha256:}" "$output" | sha256sum -c -
}

[[ "$(uname -m)" == x86_64 ]] || die "当前仅支持 x86_64"

###### 准备构建环境 ######

# 只清理并重建当前项目自己的构建目录。
rm -rf "$SOURCE_DIR" "$APPDIR" "$DIST_DIR"
mkdir -p "$TOOLS_DIR" "$EXTRACT_DIR" "$DIST_DIR"

# 根据当前环境选择 apt-get 调用方式。
if command -v sudo >/dev/null 2>&1; then
  APT=(sudo apt-get)
else
  APT=(apt-get)
fi

# 安装下载、解包、Qt5 插件部署和媒体运行库收集所需依赖。
"${APT[@]}" update
DEBIAN_FRONTEND=noninteractive "${APT[@]}" install -y --no-install-recommends \
  ca-certificates coreutils curl desktop-file-utils file findutils gawk grep jq tar xz-utils \
  qtchooser qt5-qmake qt5-qmake-bin qtbase5-dev qtbase5-dev-tools qttools5-dev-tools \
  qtdeclarative5-dev qtdeclarative5-dev-tools \
  qml-module-qtqml qml-module-qtqml-models2 \
  qml-module-qtquick2 qml-module-qtquick-window2 qml-module-qtquick-layouts \
  qml-module-qtquick-controls qml-module-qtquick-controls2 qml-module-qtquick-templates2 \
  qml-module-qtgraphicaleffects qml-module-qt-labs-platform qml-module-qt-labs-settings \
  libqt5svg5 qttranslations5-l10n qt5-gtk-platformtheme qtwayland5 \
  fcitx5-frontend-qt5 libfcitx5-qt1 \
  libqt5multimedia5 libqt5multimedia5-plugins libqt5multimediagsttools5 \
  libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
  libpulse0 libpulse-mainloop-glib0 \
  libva2 libva-drm2 libva-x11-2 \
  libwayland-client0 libwayland-cursor0 libwayland-egl1 libwayland-server0 libudev1 \
  libxkbcommon-x11-0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
  libxcb-render-util0 libxcb-xinerama0 libxcb-xkb1

# 确认后续构建依赖的基础命令均可用。
for command_name in curl desktop-file-validate find jq readlink sed sha256sum tar; do
  command -v "$command_name" >/dev/null 2>&1 || die "缺少必需命令：$command_name"
done

# Qt 插件必须直接使用 Qt5 的真实工具，不能落到没有选中版本的 qtchooser wrapper。
QT5_BIN_DIR=/usr/lib/qt5/bin
for qt_tool in qmake qmlimportscanner; do
  [[ -x "$QT5_BIN_DIR/$qt_tool" ]] || die "缺少 Qt5 工具：$QT5_BIN_DIR/$qt_tool"
done

# 准备 GitHub API 请求头；有令牌时用于提高官方 API 访问额度。
api_headers=(
  -H 'Accept: application/vnd.github+json'
  -H 'X-GitHub-Api-Version: 2022-11-28'
)
if [[ -n "${GH_TOKEN:-}" ]]; then
  api_headers+=( -H "Authorization: Bearer $GH_TOKEN" )
fi

###### 下载打包工具 ######

# 动态下载 linuxdeploy、Qt 插件、appimagetool 和官方 Type 2 runtime。
download_tool linuxdeploy/linuxdeploy linuxdeploy-x86_64.AppImage "$LINUXDEPLOY"
download_tool linuxdeploy/linuxdeploy-plugin-qt linuxdeploy-plugin-qt-x86_64.AppImage "$QT_PLUGIN"
download_tool AppImage/appimagetool appimagetool-x86_64.AppImage "$APPIMAGETOOL"
download_tool AppImage/type2-runtime runtime-x86_64 "$RUNTIME_FILE"
chmod +x "$LINUXDEPLOY" "$QT_PLUGIN" "$APPIMAGETOOL"
ln -sfn linuxdeploy-x86_64.AppImage "$TOOLS_DIR/linuxdeploy"

###### 初始化 AppDir ######

# 配置 linuxdeploy、Qt5 qmake 和中间输出位置。
export ARCH=x86_64
export APPIMAGE_EXTRACT_AND_RUN=1
export QT_SELECT=qt5
export PATH="$QT5_BIN_DIR:$TOOLS_DIR:$PATH"
export QMAKE="$QT5_BIN_DIR/qmake"
export NO_STRIP=1
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

###### 下载并准备 XnView MP ######

# 从 XnView 官方校验清单动态解析当前最新稳定版 Linux x64 归档。
curl -fL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 20 --max-time 120 \
  https://download.xnview.com/versions/XnView_MP/XnView_MP-CHECKSUMS.txt \
  -o "$CHECKSUMS"
sed -i 's/\r$//' "$CHECKSUMS"

TGZ_NAME="$(
  awk '{print $2}' "$CHECKSUMS" |
    grep -E '^XnView_MP-[0-9]+(\.[0-9]+)+-linux-x64\.tgz$' |
    sort -V |
    tail -n 1
)"
[[ -n "$TGZ_NAME" ]] || die "官方校验清单中没有稳定版 Linux x64 归档"
VERSION="$(sed -nE 's/^XnView_MP-([0-9]+(\.[0-9]+)+)-linux-x64\.tgz$/\1/p' <<< "$TGZ_NAME")"
[[ -n "$VERSION" ]] || die "无法从 $TGZ_NAME 解析 XnView MP 版本"
TGZ="$SOURCE_DIR/$TGZ_NAME"
TGZ_URL="https://download.xnview.com/versions/XnView_MP/$TGZ_NAME"
TGZ_SHA256="$(awk -v name="$TGZ_NAME" '$2 == name {print $1; exit}' "$CHECKSUMS")"
[[ "$TGZ_SHA256" =~ ^[[:xdigit:]]{64}$ ]] || die "官方归档没有有效的 SHA-256"

printf '[XnView MP] official stable source: %s\n' "$TGZ_URL"
curl -fL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 20 --max-time 900 \
  "$TGZ_URL" -o "$TGZ"
printf '%s  %s\n' "$TGZ_SHA256" "$TGZ" | sha256sum -c -

# 解包官方归档并定位唯一的 XnView 主程序目录。
tar -xzf "$TGZ" -C "$EXTRACT_DIR"
mapfile -d '' xnview_bins < <(find "$EXTRACT_DIR" -type f -name XnView -perm -u+x -print0)
[[ ${#xnview_bins[@]} -eq 1 ]] || die "预期找到一个 XnView 可执行文件，实际找到 ${#xnview_bins[@]} 个"
SOURCE_APP_DIR="$(dirname "${xnview_bins[0]}")"

# 保持上游 /opt/XnView 布局；不预建或填充 AppDir/usr/bin。
mkdir -p "$APPDIR/opt/XnView" "$APPDIR/usr/share/applications"
cp -a "$SOURCE_APP_DIR/." "$APPDIR/opt/XnView/"
DESKTOP_FILE="$APPDIR/usr/share/applications/XnView.desktop"
ICON_FILE="$APPDIR/opt/XnView/xnview.png"
cp -a "$APPDIR/opt/XnView/XnView.desktop" "$DESKTOP_FILE"

[[ -x "$APPDIR/opt/XnView/XnView" ]] || die "缺少 XnView 可执行文件"
[[ -e "$ICON_FILE" ]] || die "缺少 XnView 图标"
[[ -e "$APPDIR/opt/XnView/lib/libmdk.so" ]] || die "缺少 XnView 媒体引擎"

# 规范官方 desktop 条目，并让 Exec 名称对应 /opt 中的真实主程序。
sed -i \
  -e 's|^Icon=.*|Icon=xnview|' \
  -e 's|^Exec=.*|Exec=XnView|' \
  -e '/^Value=/d' \
  -e '/^Encoding=/d' \
  -e 's/^Terminal=0$/Terminal=false/' \
  "$DESKTOP_FILE"
desktop-file-validate "$DESKTOP_FILE"

###### 准备兼容运行库 ######

# 复制 Qt5 翻译和 XCB 平台库，继续优先使用 XnView 自带 Qt。
mkdir -p "$APPDIR/usr/lib" "$APPDIR/usr/translations"
if [[ -d /usr/share/qt5/translations ]]; then
  cp -a /usr/share/qt5/translations/. "$APPDIR/usr/translations/"
fi
cp -a "$APPDIR/opt/XnView/lib"/libQt5XcbQpa.so* "$APPDIR/usr/lib/"

# 按明确的库名模式复制当前应用需要的 Jammy 运行库。
copy_runtime_glob() {
  local pattern="$1"
  local files=()
  mapfile -t files < <(compgen -G "$pattern" || true)
  ((${#files[@]} > 0)) || die "找不到必需的运行库：$pattern"
  cp -a "${files[@]}" "$APPDIR/usr/lib/"
}

# 补入已有兼容基线所需的 GStreamer、PulseAudio、VA-API、Wayland 和 udev 库。
for runtime_lib in \
  libgstreamer-1.0.so.0 \
  libgstapp-1.0.so.0 \
  libgstbase-1.0.so.0 \
  libgstaudio-1.0.so.0 \
  libgstvideo-1.0.so.0 \
  libgstpbutils-1.0.so.0 \
  libgsttag-1.0.so.0 \
  libgstallocators-1.0.so.0 \
  libgstfft-1.0.so.0 \
  libgstgl-1.0.so.0 \
  libpulse.so.0 \
  libpulse-mainloop-glib.so.0 \
  libva.so.2 \
  libva-drm.so.2 \
  libva-x11.so.2 \
  libwayland-client.so.0 \
  libwayland-cursor.so.0 \
  libwayland-egl.so.1 \
  libwayland-server.so.0 \
  libudev.so.1; do
  copy_runtime_glob "/usr/lib/x86_64-linux-gnu/${runtime_lib}*"
done
copy_runtime_glob "/usr/lib/x86_64-linux-gnu/pulseaudio/libpulsecommon-*.so"

###### 核心打包 ######

# 第二次 linuxdeploy 扫描上游 /opt 布局时，优先使用 XnView 自带运行库并保留 AppDir/usr/lib。
export LD_LIBRARY_PATH="$APPDIR/opt/XnView:$APPDIR/opt/XnView/lib:$APPDIR/opt/XnView/Plugins:$APPDIR/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

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
# XnView 的真实程序位于 /opt，因此在对应变量前继续加入上游 /opt 路径。
export PATH="$HERE/opt/XnView:$HERE/usr/bin:${PATH:-}"
export LD_LIBRARY_PATH="$HERE/opt/XnView:$HERE/opt/XnView/lib:$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$HERE/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

# Qt 专用目录按最终 AppDir 的实际结构成对加入 /opt 与 /usr 路径。
export QT_PLUGIN_PATH="$HERE/opt/XnView/lib:$HERE/opt/XnView/Plugins:$HERE/usr/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
export QML_IMPORT_PATH="$HERE/opt/XnView/qml:$HERE/usr/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
export QML2_IMPORT_PATH="$HERE/opt/XnView/qml:$HERE/usr/qml${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
export QT_TRANSLATIONS_PATH="$HERE/usr/translations${QT_TRANSLATIONS_PATH:+:$QT_TRANSLATIONS_PATH}"

export QT_AUTO_SCREEN_SCALE_FACTOR=1
# XnView 官方针对视频播放时的 XCB OpenGL 上下文问题建议使用 EGL 集成。
export QT_QPA_PLATFORM=xcb
export QT_XCB_GL_INTEGRATION=xcb_egl
export QT_FONT_DPI=96

exec "$HERE/opt/XnView/XnView" "$@"
EOF_APPRUN
chmod +x "$APPDIR/AppRun"

# XnView MP 使用 Qt5；第二次 linuxdeploy 部署 Qt 资源并完成 AppRun 包装。
export QMAKE="$QT5_BIN_DIR/qmake"
export ARCH=x86_64; linuxdeploy \
  --appdir AppDir \
  --desktop-file "$DESKTOP_FILE" \
  --icon-file "$ICON_FILE" \
  --plugin qt \
  --output appimage

# 第二次 linuxdeploy 完成后，统一按最终 AppDir 整理 AppRun 中的路径型 export。
"$SCRIPT_DIR/../common/linuxdeploy/normalize_apprun_paths.sh" "$APPDIR"

###### 整理产物 ######

# 忽略 linuxdeploy 中间 AppImage，使用官方 appimagetool 和 Type 2 runtime
# 对同一个 AppDir 重新封装正式发布资产。
"$APPIMAGETOOL" -n "$APPDIR" "$OUTFILE" --runtime-file "$RUNTIME_FILE"
[[ -s "$OUTFILE" ]] || die "最终 AppImage 未生成"
chmod +x "$OUTFILE"

# 写入本次实际打包的软件版本，并输出正式资产 SHA-256。
printf '%s\n' "$VERSION" > "$DIST_DIR/version.txt"
sha256sum "$OUTFILE"
