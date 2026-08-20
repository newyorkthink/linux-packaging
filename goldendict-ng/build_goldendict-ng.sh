#!/usr/bin/env bash
set -e

rm -rf AppDir || true

ARCH="$(uname -m)"
export ARCH

export DESKTOP=/usr/share/applications/io.github.xiaoyifang.goldendict_ng.desktop

# 动态查找 GoldenDict-ng 的图标，如果找不到就强行下载一个，防止 linuxdeploy 报错
FOUND_ICON=$(find /usr/share/icons/hicolor /usr/share/pixmaps -name "*goldendict*.png" -o -name "*goldendict*.svg" 2>/dev/null | grep -v "tray" | head -n 1)
if [ -z "$FOUND_ICON" ]; then
  wget -q -O /usr/share/pixmaps/io.github.xiaoyifang.goldendict_ng.png https://raw.githubusercontent.com/xiaoyifang/goldendict-ng/staged/icons/programicon.png || true
  export ICON=/usr/share/pixmaps/io.github.xiaoyifang.goldendict_ng.png
else
  export ICON="$FOUND_ICON"
fi
export OUTPATH=./dist
export OUTNAME="goldendict-ng.AppImage"
export DEPLOY_OPENGL=1

# 基本依赖 (包括常见的编译、打包工具以及X11/Wayland基础库)
yay -S --noconfirm gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux glycin libheif zsync xorg-server xorg-server-common xorg-server-xvfb

# 常用包及剪贴板、输入法、UI主题组件
yay -S --noconfirm wl-clipboard xclip fcitx5-qt egl-wayland libxcb xcb-util xcb-util-keysyms libxss extra-cmake-modules \
  xcb-util-renderutil xcb-util-wm xcb-util-image xcb-util-cursor libxkbcommon libxkbcommon-x11 mesa libglvnd \
  adwaita-qt6 qt6-base qt6-svg qt6-tools qt6ct lxqt-qtplugin kvantum nss openssh xdg-utils

# GoldenDict-ng 及用户提供的依赖
yay -S --noconfirm goldendict-ng fmt hunspell libeb libvorbis libxtst libzim lzo opencc qt6-5compat qt6-multimedia qt6-speech qt6-webengine tomlplusplus xapian-core xz zlib cmake git ninja

# 打包程序本体及运行时资源
quick-sharun /usr/bin/goldendict /usr/share/goldendict

# 删除程序目录内可能生成的 portable 配置目录。
# GoldenDict-ng 检测不到 portable 后，会自动使用 ~/.config/goldendict 等标准用户目录。
find AppDir -type d -name portable -prune -exec rm -rf {} + 2>/dev/null || true

# 保持之前稳定版本的 Adwaita 深色界面。
printf '%s\n' 'QT_STYLE_OVERRIDE=Adwaita-Dark' >> AppDir/.env

quick-sharun --make-appimage
