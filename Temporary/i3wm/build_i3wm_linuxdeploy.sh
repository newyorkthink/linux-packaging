#!/usr/bin/env bash

############# 初始化脚本 #############

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

############# 准备构建目录 #############

# 设置构建路径，并清理、重建当前应用的 source、AppDir 和 dist 目录。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" "i3"

############# 准备构建环境 #############

# 安装构建工具和应用所需的依赖包。
"$SCRIPT_DIR/../common/apt/install_packages.sh" i3-wm i3status suckless-tools xss-lock librsvg2-bin

############# 下载打包工具 #############

# 下载并校验打包工具及所需插件，随后加载构建环境配置。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" "" "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"

############ 初始化 AppDir #############

# 首次运行 linuxdeploy，创建 AppDir 的基础目录。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

############ 下载并准备应用 #############

# 下载已安装版本的软件包并解包到 AppDir，成功后返回版本号。
VERSION="$("$SCRIPT_DIR/../common/apt/extract_installed_package.sh" "i3-wm" "$APPDIR")"

########## 准备桌面资源和运行库 #########

# 本程序专属处理：将配套软件包解包到独立暂存目录，按白名单复制 6 个工具并排除 slock、i3lock 等锁屏及无关程序。
COMPANION_DIR="$SOURCE_DIR/companion-stage"
mkdir -p "$COMPANION_DIR"
"$SCRIPT_DIR/../common/apt/extract_installed_package.sh" "i3status" "$COMPANION_DIR" suckless-tools xss-lock >/dev/null

# 本程序专属处理：复制已确认保留的配套命令及默认状态栏配置。
cp -a "$COMPANION_DIR/usr/bin/i3status" "$APPDIR/usr/bin/i3status"
cp -a "$COMPANION_DIR/usr/bin/dmenu_path" "$APPDIR/usr/bin/dmenu_path"
cp -a "$COMPANION_DIR/usr/bin/dmenu_run" "$APPDIR/usr/bin/dmenu_run"
cp -a "$COMPANION_DIR/usr/bin/stest" "$APPDIR/usr/bin/stest"
cp -a "$COMPANION_DIR/usr/bin/xss-lock" "$APPDIR/usr/bin/xss-lock"
if [[ -f "$COMPANION_DIR/usr/bin/dmenu" && ! -L "$COMPANION_DIR/usr/bin/dmenu" ]]; then
  cp -a "$COMPANION_DIR/usr/bin/dmenu" "$APPDIR/usr/bin/dmenu"
elif [[ -e "$COMPANION_DIR/usr/bin/dmenu" ]]; then
  cp -L "$COMPANION_DIR/usr/bin/dmenu" "$APPDIR/usr/bin/dmenu"
elif [[ -e "$COMPANION_DIR/usr/bin/dmenu.default" ]]; then
  cp -L "$COMPANION_DIR/usr/bin/dmenu.default" "$APPDIR/usr/bin/dmenu"
elif [[ -e "$COMPANION_DIR/usr/bin/dmenu.xft" ]]; then
  cp -L "$COMPANION_DIR/usr/bin/dmenu.xft" "$APPDIR/usr/bin/dmenu"
else
  echo "错误：未在 suckless-tools 暂存目录中找到 dmenu。" >&2
  exit 1
fi
mkdir -p "$APPDIR/etc"
cp -a "$COMPANION_DIR/etc/i3status.conf" "$APPDIR/etc/i3status.conf"

# 本程序专属处理：统一 i3-with-shmlog 为相对软链接，避免指向宿主路径。
ln -sfn i3 "$APPDIR/usr/bin/i3-with-shmlog"

# 本程序专属处理：核对 20 个内置工具齐全，并确认未混入锁屏程序。
for expected_tool in i3 i3bar i3-config-wizard i3-dmenu-desktop i3-dump-log i3-input i3-migrate-config-to-v4 i3-msg i3-nagbar i3-save-tree i3-sensible-editor i3-sensible-pager i3-sensible-terminal i3-with-shmlog i3status dmenu dmenu_path dmenu_run stest xss-lock; do
  [[ -e "$APPDIR/usr/bin/$expected_tool" ]] || {
    echo "错误：AppDir 缺少预期工具：$expected_tool" >&2
    exit 1
  }
done
for excluded_tool in slock i3lock; do
  [[ ! -e "$APPDIR/usr/bin/$excluded_tool" ]] || {
    echo "错误：AppDir 不得包含锁屏程序：$excluded_tool" >&2
    exit 1
  }
done

# 本程序专属处理：复制默认配置到 XDG 回退目录，使无个人配置时无需路径映射即可回退到包内默认配置。
mkdir -p "$APPDIR/etc/xdg/i3" "$APPDIR/etc/xdg/i3status"
cp -a "$APPDIR/etc/i3/." "$APPDIR/etc/xdg/i3/"
cp -a "$APPDIR/etc/i3status.conf" "$APPDIR/etc/xdg/i3status/config"

# 本程序专属处理：部署官方 SVG 图标，并补齐桌面入口所需的图标、分类与窗口类字段。
mkdir -p "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/scalable/apps"
cp -a "$SCRIPT_DIR/patches/i3.svg" "$APPDIR/usr/share/icons/hicolor/scalable/apps/i3.svg"
rm -f "$APPDIR/usr/share/applications/i3-with-shmlog.desktop"
DESKTOP_FILE="$APPDIR/usr/share/applications/i3.desktop"
[[ -f "$DESKTOP_FILE" ]] || {
  echo "错误：未在 i3-wm 包中找到桌面入口：$DESKTOP_FILE" >&2
  exit 1
}
if grep -q '^Icon=' "$DESKTOP_FILE"; then
  sed -i 's|^Icon=.*$|Icon=i3|' "$DESKTOP_FILE"
else
  printf 'Icon=i3\n' >> "$DESKTOP_FILE"
fi
if grep -q '^Categories=' "$DESKTOP_FILE"; then
  sed -i 's|^Categories=.*$|Categories=System;|' "$DESKTOP_FILE"
else
  printf 'Categories=System;\n' >> "$DESKTOP_FILE"
fi
if grep -q '^StartupWMClass=' "$DESKTOP_FILE"; then
  sed -i 's|^StartupWMClass=.*$|StartupWMClass=i3|' "$DESKTOP_FILE"
else
  printf 'StartupWMClass=i3\n' >> "$DESKTOP_FILE"
fi

############# 准备 AppRun ##############

# 在 AppDir 根目录创建完整的 AppRun 启动脚本。
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
HERE="$(dirname "$(readlink -f "${0}")")"

# 本程序专属处理：先解析入口名，再清除外层 AppImage 变量，避免从 i3 启动的其他 AppImage 误读挂载目录。
TOOL="$(basename -- "${ARGV0:-${APPIMAGE:-$0}}")"
unset APPDIR APPIMAGE ARGV0 OWD

# 本程序专属处理：仅前置仅含 20 个 i3 套件命令的目录，并追加默认配置回退目录；
# 不导出 LD_LIBRARY_PATH，包内 ELF 通过 linuxdeploy 写入的 RPATH 查找运行库，避免污染桌面子进程。
export PATH="$HERE/usr/bin${PATH:+:$PATH}"
export XDG_CONFIG_DIRS="${XDG_CONFIG_DIRS:-/etc/xdg}:$HERE/etc/xdg"

# 本程序专属处理：按软链接名或首参数分派全部 20 个内置工具，默认启动 i3。
case "$TOOL" in
  i3|i3bar|i3-config-wizard|i3-dmenu-desktop|i3-dump-log|i3-input|i3-migrate-config-to-v4|i3-msg|i3-nagbar|i3-save-tree|i3-sensible-editor|i3-sensible-pager|i3-sensible-terminal|i3-with-shmlog|i3status|dmenu|dmenu_path|dmenu_run|stest|xss-lock)
    ;;
  *)
    case "${1:-}" in
      i3|i3bar|i3-config-wizard|i3-dmenu-desktop|i3-dump-log|i3-input|i3-migrate-config-to-v4|i3-msg|i3-nagbar|i3-save-tree|i3-sensible-editor|i3-sensible-pager|i3-sensible-terminal|i3-with-shmlog|i3status|dmenu|dmenu_path|dmenu_run|stest|xss-lock)
        TOOL="$1"
        shift
        ;;
      *)
        TOOL="i3"
        ;;
    esac
    ;;
esac

# 启动包内程序，并保留传入的命令行参数。
exec "$HERE/usr/bin/$TOOL" "$@"
APPRUN

# 为启动脚本添加执行权限。
chmod +x "$APPDIR/AppRun"

############### 核心打包 ###############

# 本程序专属处理：构建期附加 PulseAudio 私有库目录，供 linuxdeploy 解析 i3status 依赖的 libpulsecommon。
export LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu/pulseaudio${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# 再次运行 linuxdeploy，部署运行资源并生成中间 AppImage。
export ARCH=x86_64; linuxdeploy --appdir AppDir --output appimage

############### 整理产物 ###############

# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
