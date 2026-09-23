#!/usr/bin/env bash
# 个人本地打包：由 AUR wps-office-cn 从金山国内官网取得当前 DEB 和简体中文 MUI。
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
[[ "$(uname -m)" == x86_64 ]] || { echo '仅支持 x86_64。' >&2; exit 1; }

APPDIR="$SCRIPT_DIR/AppDir"
DIST="$SCRIPT_DIR/dist"
SOURCE="$SCRIPT_DIR/source"
OFFICE="$APPDIR/bin/office6"

###### 准备个人构建环境 ######
# 安装 quick-sharun 基础工具和 WPS 的常规图形、声音、打印依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
"$SCRIPT_DIR/../common/arch/install_packages.sh" fontconfig freetype2 libxrender libxext libx11 libxcb libxkbcommon libxkbcommon-x11 glu sdl2 libpulse libxss libxslt libjpeg-turbo desktop-file-utils shared-mime-info xdg-utils cups gtk3 nss ibus

# AUR 配方动态解析金山国内官网当前正式包并安装原版简体中文界面。
"$SCRIPT_DIR/../common/arch/install_packages.sh" wps-office-cn wps-office-mui-zh-cn

# 只删除本应用上次的本地打包目录，不删除系统里安装的 AUR 软件。
rm -rf -- "$APPDIR" "$DIST" "$SOURCE"
mkdir -p "$APPDIR/bin" "$DIST" "$SOURCE"

###### 保留国产 WPS 和官方入口 ######
# AUR 的 office6 已按当前 Arch 运行库调整，完整保留中文资源和子程序目录。
[[ -x /usr/lib/office6/wps ]] || { echo '未安装 wps-office-cn 主程序。' >&2; exit 1; }
[[ -d /usr/lib/office6/mui/zh_CN ]] || { echo '未安装简体中文 MUI。' >&2; exit 1; }
cp -a -- /usr/lib/office6 "$OFFICE"

# 官方启动脚本会优先寻找自身旁边的 office6；按原路径关系保留所有入口。
for launcher in wps et wpp wpspdf; do
  install -Dm0755 "/usr/bin/$launcher" "$APPDIR/bin/$launcher"
done

# 选用已安装的官方桌面文件和图标，保持版本与当前 AUR 包一致。
install -Dm0644 /usr/share/applications/wps-office-wps.desktop "$SOURCE/wps-office-cn.desktop"
mapfile -t ICONS < <(find /usr/share/icons/hicolor -type f -path '*/apps/*wpsmain.png' | sort -V)
(( ${#ICONS[@]} > 0 )) || { echo 'WPS 官方图标不存在。' >&2; exit 1; }
install -Dm0644 "${ICONS[-1]}" "$SOURCE/wps-office-cn.png"
sed -i -e 's|^Exec=.*|Exec=wps %F|' -e 's|^Icon=.*|Icon=wps-office-cn|' "$SOURCE/wps-office-cn.desktop"

# 保留 WPS 原生启动脚本，以便它自行选择文字处理或多组件入口。
cat > "$APPDIR/AppRun.sh" <<'APPRUN'
#!/bin/sh
set -e
export SHARUN_EXTRA_LIBRARY_PATH="$APPDIR/bin/office6${SHARUN_EXTRA_LIBRARY_PATH:+:$SHARUN_EXTRA_LIBRARY_PATH}"
export SHARUN_WORKING_DIR="$APPDIR/bin/office6"
export SHARUN_ALLOW_QT_PLUGIN_PATH=1
export QT_PLUGIN_PATH="$APPDIR/bin/office6/qt/plugins"
export QT_QPA_PLATFORM_PLUGIN_PATH="$APPDIR/bin/office6/qt/plugins/platforms"
export XDG_DATA_DIRS="$APPDIR/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
exec "$APPDIR/bin/wps" "$@"
APPRUN
chmod 0755 "$APPDIR/AppRun.sh"

###### 生成个人使用的 AppImage ######
# 从已安装的 AUR 包读取软件版本，不把 AUR 修订号硬编码在脚本里。
PACKAGE_VERSION="$(pacman -Q wps-office-cn | awk '{print $2}')"
VERSION="${PACKAGE_VERSION%-*}"
[[ -n "$VERSION" ]] || { echo '无法读取 WPS 包版本。' >&2; exit 1; }
export ARCH=x86_64 VERSION APPNAME='WPS Office CN' MAIN_BIN=wps
export ICON="$SOURCE/wps-office-cn.png" DESKTOP="$SOURCE/wps-office-cn.desktop"
export OUTPATH="$DIST" OUTNAME=wps-office-cn.AppImage NO_STRIP=1
LD_LIBRARY_PATH="$OFFICE${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" quick-sharun "$OFFICE/wps" "$OFFICE/et" "$OFFICE/wpp" "$OFFICE/wpspdf" "$OFFICE/qt/plugins/platforms/libqxcb.so"
quick-sharun --make-appimage

# 只在本机成品生成成功后保存实际版本，不把商业软件二进制加入 Git。
[[ -s "$DIST/wps-office-cn.AppImage" ]] || { echo 'WPS AppImage 未生成。' >&2; exit 1; }
printf '%s\n' "$VERSION" > "$DIST/version.txt"
