#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

############# 准备构建目录 #############

# 设置构建路径，并清理、重建当前应用的 source、AppDir 和 dist 目录。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" remmina

############# 准备构建环境 #############

# 安装构建工具和应用所需的依赖包。
"$SCRIPT_DIR/../common/apt/install_packages.sh" dpkg-dev pkgconf bubblewrap dbus-x11 gnome-themes-extra language-pack-gnome-zh-hans-base gstreamer1.0-gl gstreamer1.0-libav gstreamer1.0-plugins-bad gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-x libgdk-pixbuf2.0-bin libgdk-pixbuf-2.0-dev libgirepository1.0-dev libglib2.0-bin libglib2.0-dev libgtk-3-bin libgtk-3-dev libpango1.0-dev librsvg2-bin librsvg2-dev libwebkit2gtk-4.1-dev fcitx5-frontend-gtk3 ibus-gtk3 remmina remmina-common remmina-plugin-rdp remmina-plugin-vnc remmina-plugin-exec remmina-plugin-secret remmina-plugin-www remmina-plugin-spice freerdp3-x11 xdg-dbus-proxy

############# 下载打包工具 #############

# 下载并校验打包工具及所需插件，随后加载构建环境配置。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" gtk,gstreamer "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"

############ 初始化 AppDir #############

# 首次运行 linuxdeploy，创建 AppDir 的基础目录。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

############ 下载并准备应用 #############

# 下载已安装版本的软件包并解包到 AppDir，成功后返回版本号。
VERSION="$("$SCRIPT_DIR/../common/apt/extract_installed_package.sh" remmina "$APPDIR" remmina-common remmina-plugin-rdp remmina-plugin-vnc remmina-plugin-exec remmina-plugin-secret remmina-plugin-www remmina-plugin-spice)"

# 输出 Remmina 版本，供现有工作流读取版本元数据。
echo "Remmina 版本：$VERSION"

########## 准备桌面资源和运行库 #########

# 下载并解包应用所需的图标与主题资源。
"$SCRIPT_DIR/../common/apt/download_and_extract_packages.sh" "$APPDIR" adwaita-icon-theme gnome-themes-extra-data

# Remmina 需要补齐协议插件、翻译、WebKitGTK、FreeRDP、OpenSSL provider 和 GTK 输入模块。
"$SCRIPT_DIR/patches/prepare_runtime.sh" "$APPDIR"

# Remmina 和 WebKitGTK 的模块按需加载，显式收集这些模块的运行依赖。
LINUXDEPLOY_LIBRARIES=()
while IFS= read -r library; do
  LINUXDEPLOY_LIBRARIES+=(-l "$library")
done < <(find "$APPDIR/plugins" "$APPDIR/webkit" -type f -name '*.so*' -print | sort)

############# 准备 AppRun ##############

# Remmina Local Terminal 调用 $SHELL 时不会指定工作目录，会继承 Remmina 进程当前目录。
# Remmina 又必须进入 AppDir 才能加载 /proc/self/cwd/plugins，因此使用 shell wrapper 恢复 AppImage 启动目录。
cat > "$APPDIR/usr/bin/remmina-local-shell" <<'LOCAL_SHELL'
#!/bin/sh

# 在命令执行失败时退出。
set -e

host_shell="${REMMINA_HOST_SHELL:-/bin/sh}"
target_dir="${REMMINA_LAUNCH_CWD:-${HOME:-/}}"

if [ ! -d "$target_dir" ]; then
  target_dir="${HOME:-/}"
fi

cd "$target_dir"
export SHELL="$host_shell"
exec "$host_shell" "$@"
LOCAL_SHELL

# 为 Local Terminal 的 shell wrapper 添加执行权限。
chmod +x "$APPDIR/usr/bin/remmina-local-shell"

# 在 AppDir 根目录创建完整的 AppRun 启动脚本。
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
HERE="$(dirname "$(readlink -f "${0}")")"
APPDIR="$HERE"
export APPDIR

# 保存 AppImage 启动时的当前目录；Local Terminal 通过 wrapper 回到这里。
export REMMINA_LAUNCH_CWD="$PWD"

# 保存宿主原始 shell，随后把 SHELL 指向 Local Terminal wrapper。
if [[ -n "${SHELL:-}" && -x "$SHELL" ]]; then
  export REMMINA_HOST_SHELL="$SHELL"
elif [[ -x /bin/bash ]]; then
  export REMMINA_HOST_SHELL=/bin/bash
else
  export REMMINA_HOST_SHELL=/bin/sh
fi
export SHELL="$APPDIR/usr/bin/remmina-local-shell"

# linuxdeploy GTK hook 会强制 Adwaita:light；取消强制值，让应用跟随宿主主题。
unset GTK_DATA_PREFIX
unset GTK_THEME
unset APPIMAGE_GTK_THEME

LIBDIR="$APPDIR/usr/lib/x86_64-linux-gnu"

# 设置程序、运行库和共享数据的搜索路径。
export PATH="$HERE/usr/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$LIBDIR:$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$HERE/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

# GTK 运行环境：指定 GSettings schema 和 GIO 动态模块的目录。
export GSETTINGS_SCHEMA_DIR="$HERE/usr/share/glib-2.0/schemas"
if [[ -d "$LIBDIR/gio/modules" ]]; then
  export GIO_MODULE_DIR="$LIBDIR/gio/modules"
fi

# Remmina 的 GObject Introspection 组件使用包内 typelib。
if [[ -d "$LIBDIR/girepository-1.0" ]]; then
  export GI_TYPELIB_PATH="$LIBDIR/girepository-1.0:${GI_TYPELIB_PATH:-}"
fi

# 设置简体中文界面环境。
export LANGUAGE="zh_CN:zh"

# 本 AppImage 面向本地/工作组 Windows RDP：默认禁用 Kerberos/U2U，直接使用可用的 NTLM/NLA。
# 只在 rdp_auth_filter 不存在或为空时写入；已有非空自定义值保持原样。
REMMINA_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME:-/tmp}/.config}"
REMMINA_PREF_FILE="$REMMINA_CONFIG_HOME/remmina/remmina.pref"
mkdir -p "$(dirname "$REMMINA_PREF_FILE")"

if [[ ! -f "$REMMINA_PREF_FILE" ]]; then
  printf '%s\n' '[remmina_pref]' 'rdp_auth_filter=!kerberos,!u2u' > "$REMMINA_PREF_FILE"
elif grep -Eq '^[[:space:]]*rdp_auth_filter[[:space:]]*=[[:space:]]*$' "$REMMINA_PREF_FILE"; then
  sed -Ei 's|^[[:space:]]*rdp_auth_filter[[:space:]]*=[[:space:]]*$|rdp_auth_filter=!kerberos,!u2u|' "$REMMINA_PREF_FILE"
elif ! grep -Eq '^[[:space:]]*rdp_auth_filter[[:space:]]*=' "$REMMINA_PREF_FILE"; then
  if grep -Eq '^[[:space:]]*\[remmina_pref\][[:space:]]*$' "$REMMINA_PREF_FILE"; then
    sed -Ei '/^[[:space:]]*\[remmina_pref\][[:space:]]*$/a rdp_auth_filter=!kerberos,!u2u' "$REMMINA_PREF_FILE"
  else
    printf '\n%s\n%s\n' '[remmina_pref]' 'rdp_auth_filter=!kerberos,!u2u' >> "$REMMINA_PREF_FILE"
  fi
fi
unset REMMINA_CONFIG_HOME REMMINA_PREF_FILE

# 固定使用 AppImage 内与 libcrypto.so.3 配套的 OpenSSL provider，保证 FreeRDP 能加载 legacy MD4/RC4。
export OPENSSL_MODULES="$LIBDIR/ossl-modules"

# 为 fcitx5/IBus 生成包含当前 AppImage 挂载路径的 GTK3 模块缓存。
GTK_IMMODULE_DIR=""
for candidate in "$APPDIR/usr/lib/gtk-3.0/3.0.0/immodules" "$APPDIR/usr/lib/"*/gtk-3.0/3.0.0/immodules; do
  if [[ -d "$candidate" ]]; then
    GTK_IMMODULE_DIR="$candidate"
    break
  fi
done

IM_HINT="${GTK_IM_MODULE:-} ${QT_IM_MODULE:-} ${SDL_IM_MODULE:-} ${XMODIFIERS:-}"
if [[ "${IM_HINT,,}" != *fcitx* ]] && command -v pgrep >/dev/null 2>&1 && pgrep -x fcitx5 >/dev/null 2>&1; then
  IM_HINT="$IM_HINT fcitx"
fi

IM_CACHE_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
IM_CACHE_FILE="$IM_CACHE_DIR/remmina-appimage-immodules-${UID:-0}.cache"

case "${IM_HINT,,}" in
  *fcitx*)
    if [[ -f "$GTK_IMMODULE_DIR/im-fcitx5.so" ]]; then
      cat > "$IM_CACHE_FILE" <<EOF
# GTK+ Input Method Modules file
"$GTK_IMMODULE_DIR/im-fcitx5.so"
"fcitx" "Fcitx 5" "fcitx" "" "ja:ko:zh:*"
EOF
      export GTK_IM_MODULE_FILE="$IM_CACHE_FILE"
      export GTK_IM_MODULE="fcitx"
      export XMODIFIERS="${XMODIFIERS:-@im=fcitx}"
    fi
    ;;
  *ibus*)
    if [[ -f "$GTK_IMMODULE_DIR/im-ibus.so" ]]; then
      cat > "$IM_CACHE_FILE" <<EOF
# GTK+ Input Method Modules file
"$GTK_IMMODULE_DIR/im-ibus.so"
"ibus" "IBus" "ibus" "" "ja:ko:zh:*"
EOF
      export GTK_IM_MODULE_FILE="$IM_CACHE_FILE"
      export GTK_IM_MODULE="ibus"
    fi
    ;;
esac
unset candidate IM_HINT IM_CACHE_DIR IM_CACHE_FILE

# WebKitGTK 的编译路径已改为包内 webkit 目录，子进程使用同一目录。
export WEBKIT_EXEC_PATH="$APPDIR/webkit"

# Remmina 的 RDP 插件从包内 FreeRDP 模块目录加载组件。
FREERDP_DIR="$(find "$APPDIR/usr/lib" -type d -name 'freerdp[0-9]*' -print -quit)"
if [[ -n "$FREERDP_DIR" ]]; then
  export FREERDP_PLUGIN_PATH="$FREERDP_DIR"
fi

# 保留 Remmina 已采用的 WebKitGTK 和 GDK 图形兼容设置。
export WEBKIT_DISABLE_DMABUF_RENDERER=1
export GDK_GL=disable

# 清除显式驱动目录设置，交由宿主环境选择图形驱动。
unset LIBGL_DRIVERS_PATH
unset LIBVA_DRIVERS_PATH
unset VDPAU_DRIVER_PATH
unset __EGL_VENDOR_LIBRARY_DIRS
unset __EGL_VENDOR_LIBRARY_FILENAMES
unset VK_DRIVER_FILES
unset VK_ICD_FILENAMES

# Remmina 的插件、翻译和 WebKitGTK 路径依赖 AppDir 工作目录。
cd "$APPDIR"

# 启动包内程序，并保留传入的命令行参数。
exec "$HERE/usr/bin/remmina" "$@"
APPRUN

# 为启动脚本添加执行权限。
chmod +x "$APPDIR/AppRun"

############### 核心打包 ###############

# 指定 GTK 主版本。
export DEPLOY_GTK_VERSION=3

# 部署 Remmina 已使用的 GStreamer bad 插件。
export GSTREAMER_INCLUDE_BAD_PLUGINS=1

# 部署 Remmina 及其运行组件时不剥离符号。
export NO_STRIP=1

# 再次运行 linuxdeploy，部署运行资源并生成中间 AppImage。
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin gtk --plugin gstreamer "${LINUXDEPLOY_LIBRARIES[@]}" --output appimage

############### 整理产物 ###############

# Remmina 的编译路径需要在依赖部署后修正，同时移除临时扫描副本和不随包发布的运行库。
"$SCRIPT_DIR/patches/fix_runtime.sh" "$APPDIR"

# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
