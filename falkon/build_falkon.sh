#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装官方软件包及运行依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" "falkon" fcitx5-qt qt6ct kvantum lxqt-qtplugin breeze-icons

# 清掉上次的打包目录。
"$SCRIPT_DIR/../common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir dist


# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 使用系统里装好的图标。
export ICON="/usr/share/icons/hicolor/256x256/apps/falkon.png"
# 使用系统里装好的桌面入口文件。
export DESKTOP="/usr/share/applications/org.kde.falkon.desktop"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME="falkon.AppImage"
# 官方包依赖 qt6-base，打包时打入 Qt。
export DEPLOY_QT=1

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" pacman "falkon")"

# 收集程序及其运行依赖。
quick-sharun /usr/bin/falkon

# 本仓库兼容处理：补入 breeze-dark 图标主题，供深色外观和已配置该图标主题的环境使用。
mkdir -p AppDir/share/icons
cp -a -- /usr/share/icons/breeze-dark AppDir/share/icons/

# 本仓库兼容处理：基于官方 linux 主题内置深灰和纯黑主题，供未配置 qt6ct 的环境在外观设置里切换。
for theme_name in dark-slate oled-black; do
  theme_src="$SCRIPT_DIR/resources/themes/$theme_name"
  theme_dst="AppDir/share/falkon/themes/$theme_name"
  rm -rf -- "$theme_dst"
  mkdir -p "$theme_dst"
  cp -a -- /usr/share/falkon/themes/linux/. "$theme_dst/"
  cp -f -- "$theme_src/metadata.desktop" "$theme_dst/metadata.desktop"
  cat "$theme_src/dark.css" >> "$theme_dst/main.css"
done

# 本仓库兼容处理：写入启动 hook，默认启用 qt6ct，并按运行身份和渲染节点条件兜底无 GPU 或 root 场景。
mkdir -p AppDir/bin
cat > AppDir/bin/90-falkon-runtime.hook <<'HOOK'
#!/bin/sh

# 未显式指定平台主题时默认启用包内 qt6ct，加载用户已配置的深色调色板。
if [ -z "${QT_QPA_PLATFORMTHEME:-}" ]; then
  export QT_QPA_PLATFORMTHEME=qt6ct
fi

# 仅在以 root 身份运行且外部未指定时关闭 QtWebEngine 沙箱。
_falkon_uid="$(id -u 2>/dev/null || printf '1')"
if [ "$_falkon_uid" = "0" ] && [ -z "${QTWEBENGINE_DISABLE_SANDBOX+x}" ]; then
  export QTWEBENGINE_DISABLE_SANDBOX=1
fi

# 仅在无可用显卡渲染节点且外部未指定时回退软件渲染。
_falkon_has_dri=0
for _falkon_dri in /dev/dri/renderD*; do
  if [ -c "$_falkon_dri" ] && [ -r "$_falkon_dri" ] && [ -w "$_falkon_dri" ]; then
    _falkon_has_dri=1
    break
  fi
done
if [ "$_falkon_has_dri" = "0" ] && [ -z "${QTWEBENGINE_CHROMIUM_FLAGS+x}" ]; then
  export QTWEBENGINE_CHROMIUM_FLAGS='--disable-gpu --use-gl=disabled'
fi

unset _falkon_uid _falkon_has_dri _falkon_dri
HOOK
chmod +x AppDir/bin/90-falkon-runtime.hook

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" "dist/falkon.AppImage" "$VERSION" dist/version.txt
