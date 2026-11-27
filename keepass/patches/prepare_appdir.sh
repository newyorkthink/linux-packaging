#!/usr/bin/env bash

# 本程序专属处理：封装前准备 KeePass 的 AppDir 运行环境。
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
