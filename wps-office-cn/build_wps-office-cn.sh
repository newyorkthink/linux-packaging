#!/usr/bin/env bash
# 个人本地打包：由 AUR wps-office-cn 从金山国内官网取得当前 DEB 和简体中文 MUI。
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname -- "$SCRIPT_DIR")"
cd "$SCRIPT_DIR"

APPDIR="$SCRIPT_DIR/AppDir"
DIST="$SCRIPT_DIR/dist"
SOURCE="$SCRIPT_DIR/source"
OFFICE_SRC=/usr/lib/office6
# 与官方 DEB、ivan-hc 相同：office6 留在 opt/kingsoft/wps-office 下面，不放进 bin。
OFFICE="$APPDIR/opt/kingsoft/wps-office/office6"

###### 准备个人构建环境 ######

# 只清理本项目的构建目录。AppDir 留给后面的复制和 quick-sharun 创建。
"$ROOT/common/build/prepare_x86_64_workspace.sh" \
  "$SCRIPT_DIR" --skip-create AppDir dist source

# 安装 quick-sharun 基础工具和 WPS 的常规图形、声音、打印依赖。
"$ROOT/common/arch/install_packages.sh" --base
"$ROOT/common/arch/install_packages.sh" fontconfig freetype2 libxrender libxext libx11 libxcb libxkbcommon libxkbcommon-x11 glu sdl2 libpulse libxss libxslt libjpeg-turbo desktop-file-utils shared-mime-info xdg-utils cups gtk3 nss xorg-server-xvfb xorg-xauth

# AUR 配方动态解析金山国内官网当前正式包并安装原版简体中文界面。
"$ROOT/common/arch/install_packages.sh" wps-office-cn wps-office-mui-zh-cn

###### 保留国产 WPS 和官方入口 ######

# AUR 的 office6 已按当前 Arch 运行库调整。先不放进 AppDir/bin，避免 quick-sharun 把主程序挪走。
[[ -x "$OFFICE_SRC/wps" ]] || { echo '未安装 wps-office-cn 主程序。' >&2; exit 1; }
[[ -d "$OFFICE_SRC/mui/zh_CN" ]] || { echo '未安装简体中文 MUI。' >&2; exit 1; }

# WPS 自己编译 Qt，库名带 Kso。只用包内已经对着这套 Qt 编译的输入模块。
FCITX_PLUGIN="$OFFICE_SRC/qt/plugins/platforminputcontexts/libfcitxplatforminputcontextplugin.so"
[[ -s "$FCITX_PLUGIN" ]] || { echo 'WPS 自带的 fcitx 输入模块不存在。' >&2; exit 1; }

# 选用已安装的官方桌面文件和图标，保持版本与当前 AUR 包一致。
install -Dm0644 /usr/share/applications/wps-office-wps.desktop "$SOURCE/wps-office-cn.desktop"
mapfile -t ICONS < <(find /usr/share/icons/hicolor -type f -path '*/apps/*wpsmain.png' | sort -V)
(( ${#ICONS[@]} > 0 )) || { echo 'WPS 官方图标不存在。' >&2; exit 1; }
install -Dm0644 "${ICONS[-1]}" "$SOURCE/wps-office-cn.png"
sed -i \
  -e 's|^Exec=.*|Exec=wps %F|' \
  -e 's|^Icon=.*|Icon=wps-office-cn|' \
  -e '/^TryExec=/d' \
  -e '/^DBusActivatable=/d' \
  "$SOURCE/wps-office-cn.desktop"

###### 生成个人使用的 AppImage ######

# 从已安装的 AUR 包读取软件版本，不把 AUR 修订号硬编码在脚本里。
PACKAGE_VERSION="$(pacman -Q wps-office-cn | awk '{print $2}')"
VERSION="${PACKAGE_VERSION%-*}"
[[ -n "$VERSION" ]] || { echo '无法读取 WPS 包版本。' >&2; exit 1; }
export ARCH=x86_64 VERSION APPNAME='WPS Office CN' MAIN_BIN=wps
export ICON="$SOURCE/wps-office-cn.png" DESKTOP="$SOURCE/wps-office-cn.desktop"
export OUTPATH="$DIST" OUTNAME=wps.AppImage NO_STRIP=1
# AUR 把脚本里的 /opt/kingsoft/wps-office 改成了 /usr/lib。这里改回包内相对路径。
# 启动脚本在 bin，比 ivan-hc 的 usr/bin 少一层，所以是 ../opt/kingsoft/wps-office。
export PATH_MAPPING='
/usr/lib/office6:${SHARUN_DIR}/opt/kingsoft/wps-office/office6
/opt/kingsoft/wps-office/office6:${SHARUN_DIR}/opt/kingsoft/wps-office/office6
'
LD_LIBRARY_PATH="$OFFICE_SRC${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" quick-sharun \
  "$OFFICE_SRC/wps" "$OFFICE_SRC/et" "$OFFICE_SRC/wpp" "$OFFICE_SRC/wpspdf" \
  "$OFFICE_SRC/qt/plugins/platforms/libqxcb.so" \
  "$FCITX_PLUGIN"

# quick-sharun 会把 AppDir/bin 里的程序换成自己的入口。office6 放在 bin 外面，并在这之后整目录复制。
rm -rf -- "$OFFICE"
mkdir -p -- "$(dirname -- "$OFFICE")"
cp -a -- "$OFFICE_SRC" "$OFFICE"
cmp -s "$OFFICE_SRC/wps" "$OFFICE/wps" || { echo 'office6/wps 没有原样进入成品。' >&2; exit 1; }
[[ -d "$OFFICE/mui/zh_CN" ]] || { echo '成品缺少简体中文界面。' >&2; exit 1; }

# 官方脚本把安装目录写死，并把程序输出丢掉。改到包内 office6，失败信息留在终端。
for launcher in wps et wpp wpspdf; do
  install -Dm0755 "/usr/bin/$launcher" "$APPDIR/bin/$launcher"
  head -n 1 "$APPDIR/bin/$launcher" | grep -q 'sh' || { echo "官方入口不是脚本：$launcher" >&2; exit 1; }
  if grep -Fq '${gInstallPath}/office6/' "$APPDIR/bin/$launcher"; then
    office_rel='../opt/kingsoft/wps-office'
  else
    office_rel='../opt/kingsoft/wps-office/office6'
  fi
  sed -i \
    -e 's| *> */dev/null 2>&1||g' \
    -e "s|^[[:space:]]*gInstallPath=.*|gInstallPath=\"\$(CDPATH= cd -- \"\$(dirname -- \"\$0\")/$office_rel\" \\&\\& pwd)\"|" \
    "$APPDIR/bin/$launcher"
  grep -Fq "$office_rel" "$APPDIR/bin/$launcher" || { echo "未能改写安装目录：$launcher" >&2; exit 1; }
  # WPS 12 在英文系统上认 LANGUAGE，不认 LANG。
  # Rofi 会带上 GIO_LAUNCHED_DESKTOP_FILE，WPS 见到就马上退出。
  sed -i '1a export LANGUAGE=zh_CN\
unset GIO_LAUNCHED_DESKTOP_FILE' "$APPDIR/bin/$launcher"
  grep -Fq 'export LANGUAGE=zh_CN' "$APPDIR/bin/$launcher" || { echo "未能写入界面语言：$launcher" >&2; exit 1; }
  grep -Fq 'unset GIO_LAUNCHED_DESKTOP_FILE' "$APPDIR/bin/$launcher" || { echo "未能去掉桌面启动标记：$launcher" >&2; exit 1; }
  # mawk 会把 awk -F= 里的 -F= 当成文件名。改成 gawk 和 mawk 都能认的写法。
  sed -i 's/awk -F=/awk -F "="/g' "$APPDIR/bin/$launcher"
done

###### 补上 WPS 一直提示缺失的符号字体 ######

# 放在 quick-sharun 之后，避免部署阶段清掉 AppDir。只取符号字体，不下载整套 Windows 字体，也不提交进 Git。
"$ROOT/common/github/download_default_branch_source.sh" \
  iykrichie/wps-office-19-missing-fonts-on-Linux "$SOURCE/wps-fonts.tar.gz" >/dev/null
"$ROOT/common/archive/extract_archive.sh" "$SOURCE/wps-fonts.tar.gz" "$SOURCE/wps-fonts"
mkdir -p "$APPDIR/share/fonts/wps"
for font in symbol.ttf wingding.ttf WINGDNG2.ttf WINGDNG3.ttf WEBDINGS.TTF mtextra.ttf; do
  found="$(find "$SOURCE/wps-fonts" -type f -name "$font" -print -quit)"
  [[ -n "$found" && -s "$found" ]] || { echo "缺少 WPS 符号字体：$font" >&2; exit 1; }
  install -Dm0644 "$found" "$APPDIR/share/fonts/wps/$font"
done
for font in symbol.ttf wingding.ttf WINGDNG2.ttf WINGDNG3.ttf WEBDINGS.TTF mtextra.ttf; do
  [[ -s "$APPDIR/share/fonts/wps/$font" ]] || { echo "符号字体没有进入 AppDir：$font" >&2; exit 1; }
done

# 保留 quick-sharun 已写入的环境。界面语言用 LANGUAGE，不改宿主 LANG，也不设 LOCPATH。
cat >> "$APPDIR/.env" <<'ENV'
SHARUN_EXTRA_LIBRARY_PATH=${SHARUN_DIR}/opt/kingsoft/wps-office/office6:${SHARUN_EXTRA_LIBRARY_PATH}
SHARUN_WORKING_DIR=${SHARUN_DIR}/opt/kingsoft/wps-office/office6
SHARUN_ALLOW_QT_PLUGIN_PATH=1
QT_PLUGIN_PATH=${SHARUN_DIR}/opt/kingsoft/wps-office/office6/qt/plugins
QT_QPA_PLATFORM_PLUGIN_PATH=${SHARUN_DIR}/opt/kingsoft/wps-office/office6/qt/plugins/platforms
LANGUAGE=zh_CN
ENV

# 启动时把包内符号字体加进字体搜索，同时继续使用宿主字体配置。
# hook 被 AppRun source。失败只跳过字体配置，不能 exit，否则会直接结束 WPS。
cat > "$APPDIR/bin/20-wps-fonts.hook" <<'HOOK'
_conf="${XDG_CACHE_HOME:-$HOME/.cache}/wps-office-cn-fonts.conf"
if mkdir -p "${_conf%/*}" 2>/dev/null && cat > "$_conf" <<EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
  <dir>${SHARUN_DIR}/share/fonts/wps</dir>
</fontconfig>
EOF
then
  export FONTCONFIG_FILE="$_conf"
fi
HOOK

# 已经打开过的配置可能记住英文。只改语言项，不覆盖最近文件和其他设置。
# i3 这类上级 AppImage 会把 Qt 插件和库路径传下来。WPS 自己的 xcb 插件能被找到但加载失败，然后段错误。
cat > "$APPDIR/bin/10-wps-runtime.hook" <<'HOOK'
if [ -n "$SHARUN_DIR" ]; then
  _clean=""
  _oldifs=$IFS
  IFS=:
  for _dir in $LD_LIBRARY_PATH; do
    case "$_dir" in
      "$SHARUN_DIR"|"$SHARUN_DIR"/*) _clean="${_clean:+$_clean:}$_dir" ;;
      *".mount_"*) ;;
      "") ;;
      *) _clean="${_clean:+$_clean:}$_dir" ;;
    esac
  done
  IFS=$_oldifs
  export LD_LIBRARY_PATH="${SHARUN_DIR}/opt/kingsoft/wps-office/office6:${SHARUN_DIR}/lib${_clean:+:$_clean}"
  export QT_PLUGIN_PATH="${SHARUN_DIR}/opt/kingsoft/wps-office/office6/qt/plugins"
  export QT_QPA_PLATFORM_PLUGIN_PATH="${SHARUN_DIR}/opt/kingsoft/wps-office/office6/qt/plugins/platforms"
  unset _clean _oldifs _dir
fi
HOOK
cat > "$APPDIR/bin/15-wps-language.hook" <<'HOOK'
export LANGUAGE=zh_CN
unset GIO_LAUNCHED_DESKTOP_FILE
_conf="${XDG_CONFIG_HOME:-$HOME/.config}/Kingsoft/Office.conf"
mkdir -p "${_conf%/*}" 2>/dev/null || true
if [ ! -f "$_conf" ]; then
  cat > "$_conf" <<'EOF'
[General]
languages=zh_CN

[6.0]
common\DefaultLanguage=2052
common\Local\UILanguage=2052
EOF
else
  grep -q '^languages=' "$_conf" \
    && sed -i 's/^languages=.*/languages=zh_CN/' "$_conf" \
    || printf '\n[General]\nlanguages=zh_CN\n' >> "$_conf"
  grep -q '\\UILanguage=' "$_conf" \
    && sed -i 's/\\UILanguage=.*/\\UILanguage=2052/' "$_conf" \
    || printf '[6.0]\ncommon\\DefaultLanguage=2052\ncommon\\Local\\UILanguage=2052\n' >> "$_conf"
fi
HOOK

quick-sharun --make-appimage

# 公共图形检查：进程要撑过 20 秒。提前退出就是这次这种打一行就回到提示符。
chmod 0755 "$DIST/wps.AppImage"
"$ROOT/common/gui/check_appimage_gui.sh" \
  "$DIST/wps.AppImage" 20 "$SOURCE/gui-smoke" timeout-dbus-xvfb timeout-only \
  'error while loading shared libraries|cannot open shared object file|symbol lookup error|Could not load the Qt platform plugin|Segmentation fault|core dumped|does not exist' \
  ''

"$ROOT/common/build/save_appimage_version.sh" \
  "$DIST/wps.AppImage" "$VERSION" "$DIST/version.txt"
