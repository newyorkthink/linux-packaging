#!/usr/bin/env bash

############# 初始化脚本 #############

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

############# 准备构建目录 #############

# 设置构建路径，并清理、重建当前应用的 source、AppDir 和 dist 目录。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" "gufw"

############# 准备构建环境 #############

# 安装构建工具和应用所需的依赖包。
"$SCRIPT_DIR/../common/apt/install_packages.sh" \
  gufw python3 python3-minimal python3-gi gir1.2-gtk-3.0 gir1.2-glib-2.0 \
  gir1.2-pango-1.0 gir1.2-gdkpixbuf-2.0 gir1.2-atk-1.0 libgtk-3-0t64 \
  libgtk-3-common libgtk-3-bin librsvg2-bin adwaita-icon-theme \
  hicolor-icon-theme gnome-themes-extra-data locales \
  fcitx5-frontend-gtk3 ibus-gtk3

############# 下载打包工具 #############

# 下载并校验打包工具及所需插件，随后加载构建环境配置。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" gtk "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"

############ 初始化 AppDir #############

# 首次运行 linuxdeploy，创建 AppDir 的基础目录。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

############ 下载并准备应用 #############

# 本程序专属处理：公共解包入口不递归依赖，按当前解释器补齐 Python 运行包。
# 核心若已静态链接，ldd 没有共享 libpython；此时不追加空包名，构建继续。
PY_SERIES="$(python3 -c 'import sys; print("{}.{}".format(sys.version_info[0], sys.version_info[1]))')"
PY_BIN="$(readlink -f /usr/bin/python3)"
LIBPYTHON_FILE="$(ldd "$PY_BIN" 2>/dev/null | sed -n 's/.* => \(.*libpython[^ ]*\) .*/\1/p' | awk 'NR==1 { print; exit }')" || true
LIBPYTHON_PKG=""
if [[ -n "$LIBPYTHON_FILE" && -e "$LIBPYTHON_FILE" ]]; then
  LIBPYTHON_PKG="$(dpkg -S "$LIBPYTHON_FILE" | awk -F: 'NR==1 { split($1, names, ","); gsub(/ /, "", names[1]); print names[1]; exit }')"
fi
mapfile -t RUNTIME_PACKAGES < <(
  {
    printf '%s\n' \
      python3-minimal \
      "python${PY_SERIES}-minimal" \
      "python${PY_SERIES}" \
      "libpython${PY_SERIES}-minimal" \
      "libpython${PY_SERIES}-stdlib"
    if [[ -n "$LIBPYTHON_PKG" ]]; then
      printf '%s\n' "$LIBPYTHON_PKG"
    fi
    printf '%s\n' \
      python3-gi \
      gir1.2-glib-2.0 \
      gir1.2-gtk-3.0 \
      gir1.2-pango-1.0 \
      gir1.2-gdkpixbuf-2.0 \
      gir1.2-atk-1.0 \
      libgtk-3-0t64 \
      libgtk-3-common \
      adwaita-icon-theme \
      hicolor-icon-theme \
      gnome-themes-extra-data \
      fcitx5-frontend-gtk3 \
      ibus-gtk3
  } | awk 'NF && !seen[$0]++'
)
for package in "${RUNTIME_PACKAGES[@]}"; do
  status="$(dpkg-query -W -f='${Status}' "$package" 2>/dev/null || true)"
  [[ "$status" == "install ok installed" ]] || {
    echo "错误：构建环境缺少 $package。" >&2
    exit 1
  }
done

# 下载已安装版本的软件包并解包到 AppDir，成功后返回版本号。
VERSION="$("$SCRIPT_DIR/../common/apt/extract_installed_package.sh" "gufw" "$APPDIR" \
  "${RUNTIME_PACKAGES[@]}")"

########## 准备桌面资源和运行库 #########

# 本程序专属处理：改界面资源路径，并隔离宿主 ufw 的 Python 环境。
python3 "$SCRIPT_DIR/patches/prepare_gufw_sources.py" "$APPDIR"

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
"$SCRIPT_DIR/../common/linuxdeploy/prepare_locale.sh" zh_CN UTF-8 "$APPDIR/usr/lib/locale/zh_CN.UTF-8"

############# 准备 AppRun ##############

# 本程序专属处理：把拟采用的独立启动脚本写入根 AppRun，供第二次 linuxdeploy 包装。
install -Dm755 "$SCRIPT_DIR/AppRun" "$APPDIR/AppRun"
# 为启动脚本添加执行权限。
chmod +x "$APPDIR/AppRun"

############### 核心打包 ###############

# 指定 GTK 主版本。
export DEPLOY_GTK_VERSION=3

# 本程序专属处理：桌面入口是脚本，改对已解包的解释器、PyGObject 和 GTK3 收集依赖。
PY_APP="$(readlink -f "$APPDIR/usr/bin/python3")"
GI_SO="$(find "$APPDIR/usr/lib" -name '_gi*.so' -print -quit)"
GTK_SO="$(find "$APPDIR/usr/lib" -name 'libgtk-3.so.0' -print -quit)"
[[ -x "$PY_APP" && -n "$GI_SO" && -n "$GTK_SO" ]] || {
  echo "错误：未找到包内 Python、PyGObject 或 GTK3。" >&2
  exit 1
}
GI_SO="$(readlink -f "$GI_SO")"
GTK_SO="$(readlink -f "$GTK_SO")"

# 再次运行 linuxdeploy，部署运行资源并生成中间 AppImage。
export ARCH=x86_64; linuxdeploy --appdir AppDir \
  --deploy-deps-only "$PY_APP" --deploy-deps-only "$GI_SO" \
  --deploy-deps-only "$GTK_SO" --desktop-file "$APPDIR/usr/share/applications/gufw.desktop" \
  --plugin gtk --output appimage

############### 整理产物 ###############

# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
