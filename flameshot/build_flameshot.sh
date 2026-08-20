#!/usr/bin/env bash
set -e

rm -rf AppDir || true

ARCH="$(uname -m)"
export ARCH

export ICON=/usr/share/icons/hicolor/scalable/apps/org.flameshot.Flameshot.svg
export DESKTOP=/usr/share/applications/org.flameshot.Flameshot.desktop
export OUTPATH=./dist
export OUTNAME="flameshot.AppImage"

# 基本依赖
yay -S --noconfirm gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux glycin libheif zsync xorg-server xorg-server-common xorg-server-xvfb

# flameshot 及提供的相关依赖与 Qt6/图形基础依赖
yay -S --noconfirm flameshot hicolor-icon-theme kguiaddons qt6-svg gnome-shell-extension-appindicator grim qt6-imageformats xdg-desktop-portal cmake git qt6-tools \
  wl-clipboard xclip fcitx5-qt egl-wayland libxcb xcb-util xcb-util-keysyms libxss \
  xcb-util-renderutil xcb-util-wm xcb-util-image xcb-util-cursor libxkbcommon libxkbcommon-x11 \
  mesa libglvnd adwaita-qt6 qt6-base qt6ct lxqt-qtplugin

quick-sharun /usr/bin/flameshot

# Flameshot 实际从 AppDir/bin/translations 查找翻译；链接到随包部署的完整翻译目录。
ln -s ../share/flameshot/translations AppDir/bin/translations

# 仅启用 Adwaita Qt6 黑色主题，并让 i3/X11 使用可正常截图的旧版 X11 截图方式。
cat > AppDir/bin/00-flameshot-runtime.hook <<'HOOK'
#!/bin/sh

export QT_STYLE_OVERRIDE=Adwaita-Dark

flameshot_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/flameshot"
flameshot_config="$flameshot_config_dir/flameshot.ini"
mkdir -p "$flameshot_config_dir"

if [ ! -f "$flameshot_config" ]; then
    printf '[General]\nuseX11LegacyScreenshot=true\n' > "$flameshot_config"
elif grep -q '^useX11LegacyScreenshot=' "$flameshot_config"; then
    sed -i 's/^useX11LegacyScreenshot=.*/useX11LegacyScreenshot=true/' "$flameshot_config"
elif grep -q '^\[General\]$' "$flameshot_config"; then
    sed -i '/^\[General\]$/a useX11LegacyScreenshot=true' "$flameshot_config"
else
    printf '\n[General]\nuseX11LegacyScreenshot=true\n' >> "$flameshot_config"
fi
HOOK
chmod +x AppDir/bin/00-flameshot-runtime.hook

quick-sharun --make-appimage
