#!/usr/bin/env bash
#
# KeePass AppImage 构建脚本
#
# 维护说明：
# - 已验证的依赖、命令参数、执行顺序、打包路径、插件、主题、字体、Fontconfig 和 wrapper 保持不变。
# - KPScript 始终通过 AUR 的 kpscript 软件包流程安装，不改为官方 ZIP 直装，也不增加镜像、缓存或手动下载。
# - AUR 或 KeePass 上游偶发下载失败时，按 keepass/README.md 等待约 30 分钟后重新构建。
# - Mono 兼容修复保持相互独立，只修改明确对应的问题；提交前检查 Bash/C# 语法和完整 diff。
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

rm -rf AppDir || true

# 安装基础打包工具和依赖
yay -S --noconfirm gcc base-devel wget curl unzip gnupg binutils patchelf coreutils appstream-glib desktop-file-utils util-linux zsync xorg-server xorg-server-common

# 安装 KeePass、Mono、GTK2 以及相关依赖
# 不安装旧版 keepass2-plugin-tray-icon，也不启动全局 snixembed；改用 wx-projects/Keebuntu 维护的 GTK2 XEmbed 托盘插件。
# GTK2 使用 Materia Light 浅色主题，避免 Raleigh 灰色界面和淡黄色内置配色。
# gnome-themes-extra-gtk2 和 gtk-engine-murrine 提供 Materia Light 引用的 Adwaita、Murrine GTK2 主题引擎。
# gtk-sharp-2 是 Keebuntu GTK2 XEmbed 托盘插件的运行依赖。
# libappindicator / dbusmenu / libnotify 保留为现有托盘指示器相关运行库。
# argon2 和 libgcrypt 分别用于加速 Argon2、AES-KDF 密钥转换；必须显式打包其动态库，因为 KeePass.exe 通过 Mono 运行时加载，quick-sharun 无法从托管程序集自动发现。
yay -S --noconfirm keepass gtk2 gtk-sharp-2 dbus-glib \
  bash hicolor-icon-theme mono argon2 libgcrypt xdotool xsel mono-msbuild gtk3 \
  libappindicator libdbusmenu-glib libdbusmenu-gtk3 libnotify \
  gdk-pixbuf2 librsvg materia-gtk-theme gnome-themes-extra-gtk2 gtk-engine-murrine

# 为 Mono WinForms 加入覆盖中英文的统一字体，避免查找框中文被裁切及备注区域文字基线不一致。
yay -S --noconfirm fontconfig adobe-source-han-sans-cn-fonts

# 通过 AUR 的 kpscript 软件包流程安装；上游偶发下载失败时按 keepass/README.md 等待后重新构建。
yay -S --noconfirm kpscript

test -f /usr/share/keepass/KPScript.exe

# 安装已经编译好的 GTK2 XEmbed 托盘插件。
test -f "$SCRIPT_DIR/GtkStatusIcon.sh"
bash "$SCRIPT_DIR/GtkStatusIcon.sh"

# 固定 GTK2 XEmbed 托盘插件先于 Plugins 目录中的功能插件加载，避免 KeePassOTP 改变托盘菜单后导致托盘插件初始化失败。
test -f /usr/share/keepass/Plugins/keebuntu/GtkStatusIcon.dll
mv -f /usr/share/keepass/Plugins/keebuntu/GtkStatusIcon.dll /usr/share/keepass/GtkStatusIcon.dll
test -f /usr/share/keepass/GtkStatusIcon.dll
test ! -e /usr/share/keepass/Plugins/keebuntu/GtkStatusIcon.dll

# Mono 兼容插件源码单独维护，避免修改构建依赖、字体、主题和 wrapper 时误改插件逻辑。
MONO_MOUSE_WHEEL_FIX_SOURCE="$SCRIPT_DIR/MonoMouseWheelFix.cs"
test -f "$MONO_MOUSE_WHEEL_FIX_SOURCE"

mkdir -p /usr/share/keepass/Plugins

# 下载官方 PLGX，并在构建环境中预编译为 DLL，避免 AppImage 首次运行时依赖宿主系统的 Mono 编译组件。
PLGX_WORK_DIR="/tmp/keepass-plgx-build"
PLGX_DOWNLOAD_DIR="$PLGX_WORK_DIR/downloads"
PLGX_CACHE_HOME="$PLGX_WORK_DIR/home"
PLGX_PRECOMPILER_SOURCE="$SCRIPT_DIR/PrecompilePlgx.cs"
PLGX_PRECOMPILER_EXE="$PLGX_WORK_DIR/PrecompilePlgx.exe"

rm -rf "$PLGX_WORK_DIR"
mkdir -p "$PLGX_DOWNLOAD_DIR" "$PLGX_CACHE_HOME"
test -f "$PLGX_PRECOMPILER_SOURCE"

gh release download \
  --repo Rookiestyle/KeePassOTP \
  --pattern 'KeePassOTP.plgx' \
  --dir "$PLGX_DOWNLOAD_DIR" \
  --clobber

gh release download \
  --repo Rookiestyle/GlobalSearch \
  --pattern 'GlobalSearch.plgx' \
  --dir "$PLGX_DOWNLOAD_DIR" \
  --clobber

test -s "$PLGX_DOWNLOAD_DIR/KeePassOTP.plgx"
test -s "$PLGX_DOWNLOAD_DIR/GlobalSearch.plgx"

mcs \
  -target:exe \
  -out:"$PLGX_PRECOMPILER_EXE" \
  -r:/usr/share/keepass/KeePass.exe \
  "$PLGX_PRECOMPILER_SOURCE"

test -s "$PLGX_PRECOMPILER_EXE"

precompile_plgx() {
  local plgx_path="$1"
  local plugin_name="$2"
  local compiled_path
  local output_dir="/usr/share/keepass/Plugins/$plugin_name"

  compiled_path="$(
    HOME="$PLGX_CACHE_HOME" \
    XDG_CONFIG_HOME="$PLGX_CACHE_HOME/.config" \
    XDG_DATA_HOME="$PLGX_CACHE_HOME/.local/share" \
    XDG_CACHE_HOME="$PLGX_CACHE_HOME/.cache" \
    MONO_PATH=/usr/share/keepass \
    mono "$PLGX_PRECOMPILER_EXE" "$plgx_path"
  )"

  test -s "$compiled_path"
  test "$(basename "$compiled_path")" = "$plugin_name.dll"

  rm -rf "$output_dir"
  mkdir -p "$output_dir"
  cp -a "$(dirname "$compiled_path")/." "$output_dir/"
  test -s "$output_dir/$plugin_name.dll"
}

precompile_plgx "$PLGX_DOWNLOAD_DIR/KeePassOTP.plgx" KeePassOTP
precompile_plgx "$PLGX_DOWNLOAD_DIR/GlobalSearch.plgx" GlobalSearch

test -s /usr/share/keepass/Plugins/KeePassOTP/KeePassOTP.dll
test -s /usr/share/keepass/Plugins/KeePassOTP/protobuf-net.dll
test -s /usr/share/keepass/Plugins/KeePassOTP/zxing.dll
test -s /usr/share/keepass/Plugins/KeePassOTP/zxing.presentation.dll
test -s /usr/share/keepass/Plugins/GlobalSearch/GlobalSearch.dll

rm -rf "$PLGX_WORK_DIR"

mcs \
  -target:library \
  -out:/usr/share/keepass/Plugins/MonoMouseWheelFix.dll \
  -r:/usr/share/keepass/KeePass.exe \
  -r:System.Core \
  -r:System.Drawing \
  -r:System.Windows.Forms \
  "$MONO_MOUSE_WHEEL_FIX_SOURCE"

test -f /usr/share/keepass/Plugins/MonoMouseWheelFix.dll

# 窗口布局插件单独编译，避免平铺窗口和 i3 焦点修复影响已经验证的 MonoMouseWheelFix.dll。
KEEPASS_WINDOW_LAYOUT_FIX_SOURCE="$SCRIPT_DIR/KeePassWindowLayoutFix.cs"
KEEPASS_WINDOW_LAYOUT_FIX_BUILD_SOURCE="/tmp/KeePassWindowLayoutFix.cs"
test -f "$KEEPASS_WINDOW_LAYOUT_FIX_SOURCE"

# KeePass 插件管理器只使用单选；构建临时源码时关闭 MultiSelect，绕过 Mono ListView.UpdateMultiSelection 的越界路径。
awk '
  /private void Patch\(Form form\)/ { in_patch = 1 }
  in_patch && /string name = form.GetType\(\).FullName;/ {
    print
    print ""
    print "            if(string.Equals(name, PluginsType, StringComparison.Ordinal))"
    print "            {"
    print "                ListView plugins = Find(form, \"m_lvPlugins\") as ListView;"
    print "                if(plugins != null) plugins.MultiSelect = false;"
    print "            }"
    replaced++
    next
  }
  /private void OnFormResize\(object sender, EventArgs e\)/ { in_patch = 0 }
  { print }
  END { if(replaced != 1) exit 1 }
' "$KEEPASS_WINDOW_LAYOUT_FIX_SOURCE" > "$KEEPASS_WINDOW_LAYOUT_FIX_BUILD_SOURCE"

test "$(grep -c 'plugins.MultiSelect = false' "$KEEPASS_WINDOW_LAYOUT_FIX_BUILD_SOURCE")" -eq 1

mcs \
  -target:library \
  -out:/usr/share/keepass/Plugins/KeePassWindowLayoutFix.dll \
  -r:/usr/share/keepass/KeePass.exe \
  -r:System.Core \
  -r:System.Drawing \
  -r:System.Windows.Forms \
  "$KEEPASS_WINDOW_LAYOUT_FIX_BUILD_SOURCE"

rm -f "$KEEPASS_WINDOW_LAYOUT_FIX_BUILD_SOURCE"
test -f /usr/share/keepass/Plugins/KeePassWindowLayoutFix.dll

ARCH="$(uname -m)"
export ARCH

export STARTUPWMCLASS=keepass
export ICON=/usr/share/icons/hicolor/1024x1024/apps/keepass.png
export DESKTOP=/usr/share/applications/keepass.desktop
export OUTPATH=./dist
export OUTNAME="keepass.AppImage"

# 检查 KeePass 目录中的简体中文语言文件
test -f "$SCRIPT_DIR/Chinese_Simplified.lngx" || {
  echo "Error: $SCRIPT_DIR/Chinese_Simplified.lngx not found."
  exit 1
}

# 使用 quick-sharun 构建 AppDir
quick-sharun \
  /usr/bin/keepass \
  /usr/bin/mono* \
  /etc/mono \
  /usr/lib/mono \
  /usr/lib/libMono*.so \
  /usr/lib/libmono*.so \
  /usr/lib/lib*sharpglue-2.so* \
  /usr/lib/libdbus-glib-1.so* \
  /usr/lib/libgtk-x11-2.0.so* \
  /usr/lib/libgdk-x11-2.0.so* \
  /usr/lib/gtk-2.0 \
  /usr/lib/libgtk-3.so* \
  /usr/lib/libgdk-3.so* \
  /usr/lib/gtk-3.0 \
  /usr/lib/libappindicator*.so* \
  /usr/lib/libdbusmenu*.so* \
  /usr/lib/libnotify.so* \
  /usr/lib/libgdk_pixbuf-2.0.so* \
  /usr/lib/librsvg-2.so* \
  /usr/lib/libargon2.so* \
  /usr/lib/libgcrypt.so* \
  /usr/lib/libgpg-error.so* \
  /usr/share/keepass \
  /usr/share/themes/Materia-light \
  /usr/share/icons/hicolor

# 加入简体中文语言文件
mkdir -p AppDir/share/keepass/Languages
cp -f "$SCRIPT_DIR/Chinese_Simplified.lngx" AppDir/share/keepass/Languages/Chinese_Simplified.lngx

# 加入思源黑体简体中文常规和粗体，并保留字体许可证。
mkdir -p AppDir/share/fonts/truetype/source-han-sans-cn
cp -f /usr/share/fonts/adobe-source-han-sans/SourceHanSansCN-Regular.otf AppDir/share/fonts/truetype/source-han-sans-cn/SourceHanSansCN-Regular.otf
cp -f /usr/share/fonts/adobe-source-han-sans/SourceHanSansCN-Bold.otf AppDir/share/fonts/truetype/source-han-sans-cn/SourceHanSansCN-Bold.otf
mkdir -p AppDir/share/licenses/adobe-source-han-sans-cn-fonts
cp -f /usr/share/licenses/adobe-source-han-sans-cn-fonts/LICENSE.txt AppDir/share/licenses/adobe-source-han-sans-cn-fonts/LICENSE.txt

# Mono WinForms 默认使用 Microsoft Sans Serif；将其映射到同时包含中英文字符的思源黑体，统一控件高度和文字基线。
mkdir -p AppDir/etc/fonts
cat > AppDir/etc/fonts/fonts.conf <<'EOF_FONTCONFIG'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
  <dir prefix="relative">../../share/fonts</dir>
  <cachedir prefix="xdg">fontconfig</cachedir>

  <match target="pattern">
    <test name="family" qual="any" compare="eq">
      <string>Microsoft Sans Serif</string>
    </test>
    <edit name="family" mode="assign" binding="strong">
      <string>Source Han Sans CN</string>
    </edit>
  </match>

  <match target="pattern">
    <test name="family" qual="any" compare="eq">
      <string>Tahoma</string>
    </test>
    <edit name="family" mode="assign" binding="strong">
      <string>Source Han Sans CN</string>
    </edit>
  </match>
</fontconfig>
EOF_FONTCONFIG

# 确认 KPScript、预编译 KeePassOTP、预编译 GlobalSearch、Keebuntu GTK2 XEmbed 插件、Mono 兼容修复插件、窗口布局插件、GTK2 运行库、主题引擎、原生加速库、Materia Light 主题和中文字体已实际进入 AppDir。
test -f AppDir/share/keepass/KPScript.exe
test -f AppDir/share/keepass/GtkStatusIcon.dll
test ! -e AppDir/share/keepass/Plugins/keebuntu/GtkStatusIcon.dll
test -s AppDir/share/keepass/Plugins/KeePassOTP/KeePassOTP.dll
test -s AppDir/share/keepass/Plugins/KeePassOTP/protobuf-net.dll
test -s AppDir/share/keepass/Plugins/KeePassOTP/zxing.dll
test -s AppDir/share/keepass/Plugins/KeePassOTP/zxing.presentation.dll
test -s AppDir/share/keepass/Plugins/GlobalSearch/GlobalSearch.dll
test ! -e AppDir/share/keepass/Plugins/KeePassOTP.plgx
test ! -e AppDir/share/keepass/Plugins/GlobalSearch.plgx
test -f AppDir/share/keepass/Plugins/MonoMouseWheelFix.dll
test -f AppDir/share/keepass/Plugins/KeePassWindowLayoutFix.dll
find AppDir -name 'libgtksharpglue-2.so' -print -quit | grep -q .
find AppDir -name 'libgtk-x11-2.0.so.0' -print -quit | grep -q .
find AppDir -name 'libadwaita.so' -print -quit | grep -q .
find AppDir -name 'libmurrine.so' -print -quit | grep -q .
find AppDir -name 'libargon2.so.1' -print -quit | grep -q .
find AppDir -name 'libgcrypt.so.20' -print -quit | grep -q .
find AppDir -name 'libgpg-error.so.0' -print -quit | grep -q .
test -f AppDir/share/icons/hicolor/16x16/apps/keepass2-locked.png
test -f AppDir/share/themes/Materia-light/gtk-2.0/gtkrc
test -f AppDir/share/fonts/truetype/source-han-sans-cn/SourceHanSansCN-Regular.otf
test -f AppDir/share/fonts/truetype/source-han-sans-cn/SourceHanSansCN-Bold.otf
test -f AppDir/share/licenses/adobe-source-han-sans-cn-fonts/LICENSE.txt
test -d AppDir/etc/fonts
test -f AppDir/etc/fonts/fonts.conf
FONTCONFIG_FILE="$PWD/AppDir/etc/fonts/fonts.conf" fc-match -f '%{family}\n' 'Microsoft Sans Serif' | grep -q '^Source Han Sans CN'
FONTCONFIG_FILE="$PWD/AppDir/etc/fonts/fonts.conf" fc-match -f '%{family}\n' 'Tahoma' | grep -q '^Source Han Sans CN'

# KeePass wrapper：调用 AppImage 内部 mono，并使用可写配置目录
cat > AppDir/bin/keepass <<'EOF_KEEPASS'
#!/bin/sh
APPDIR="${APPDIR:-$(cd "$(dirname "$0")/.." && pwd)}"

# 先用宿主系统环境创建配置目录；若先设置 AppImage 的 LD_LIBRARY_PATH，宿主 mkdir 会误加载 AppImage 内的 glibc 并触发 GLIBC_PRIVATE 符号错误。
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/keepass"
CFG_FILE="$CFG_DIR/KeePass.config.xml"
mkdir -p "$CFG_DIR"

export MONO_CONFIG="$APPDIR/etc/mono/config"
export MONO_CFG_DIR="$APPDIR/etc"
export MONO_MWF_SCALING=disable
export FONTCONFIG_FILE="$APPDIR/etc/fonts/fonts.conf"
export LD_LIBRARY_PATH="$APPDIR/lib:$APPDIR/usr/lib:$APPDIR/lib64:${LD_LIBRARY_PATH:-}"
export GTK_PATH="$APPDIR/lib/gtk-2.0:$APPDIR/usr/lib/gtk-2.0"
export GTK2_RC_FILES="$APPDIR/share/themes/Materia-light/gtk-2.0/gtkrc"

exec "$APPDIR/bin/mono" --verify-all "$APPDIR/share/keepass/KeePass.exe" -cfg-local:"$CFG_FILE" "$@"
EOF_KEEPASS
chmod +x AppDir/bin/keepass

# KPScript wrapper：调用 AppImage 内部 mono，并使用可写配置目录
cat > AppDir/bin/kpscript <<'EOF_KPSCRIPT'
#!/usr/bin/env bash
APPDIR="${APPDIR:-$(cd "$(dirname "$0")/.." && pwd)}"

# 先用宿主系统环境创建配置目录，避免宿主 mkdir 加载 AppImage 内的 glibc。
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/keepass"
CFG_FILE="$CFG_DIR/KeePass.config.xml"
mkdir -p "$CFG_DIR"

export MONO_CONFIG="$APPDIR/etc/mono/config"
export MONO_CFG_DIR="$APPDIR/etc"
export MONO_MWF_SCALING=disable
export LD_LIBRARY_PATH="$APPDIR/lib:$APPDIR/usr/lib:$APPDIR/lib64:${LD_LIBRARY_PATH:-}"
export GTK_PATH="$APPDIR/lib/gtk-2.0:$APPDIR/usr/lib/gtk-2.0"
export GTK2_RC_FILES="$APPDIR/share/themes/Materia-light/gtk-2.0/gtkrc"

arguments=("$@")

for ((i = 0; i < ${#arguments[@]}; ++i)); do
  if [ -f "${arguments[$i]}" ] && [[ "${arguments[$i]}" == /* ]]; then
    arguments[$i]="file://${arguments[$i]}"
  fi
done

exec "$APPDIR/bin/mono" --verify-all "$APPDIR/share/keepass/KPScript.exe" -cfg-local:"$CFG_FILE" "${arguments[@]}"
EOF_KPSCRIPT
chmod +x AppDir/bin/kpscript

# 构建 AppImage
quick-sharun --make-appimage
