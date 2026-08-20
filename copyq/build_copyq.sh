#!/usr/bin/env bash
set -e

rm -rf AppDir || true

ARCH="$(uname -m)"
export ARCH

export STARTUPWMCLASS=copyq
export ICON=/usr/share/icons/hicolor/scalable/apps/copyq.svg
export DESKTOP=/usr/share/applications/com.github.hluk.copyq.desktop
export OUTPATH=./dist
export OUTNAME="copyq.AppImage"
export DEPLOY_OPENGL=1

yay -S --noconfirm gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux glycin libheif zsync xorg-server xorg-server-common xorg-server-xvfb
yay -S --noconfirm copyq wl-clipboard xclip fcitx5-qt egl-wayland libxcb xcb-util xcb-util-keysyms libxss extra-cmake-modules qtkeychain-qt6 kstatusnotifieritem knotifications kguiaddons hicolor-icon-theme \
  xcb-util-renderutil xcb-util-wm xcb-util-image xcb-util-cursor libxkbcommon libxkbcommon-x11 mesa libglvnd adwaita-qt6 qt6-base qt6-svg qt6-tools qt6ct lxqt-qtplugin kvantum qca-qt6 libxtst miniaudio \
  qtkeychain-qt6 libx11 libxext libxfixes libxi libxinerama libxcb xcb-util


quick-sharun /usr/bin/copyq

# CopyQ 16 直接在 lib/copyq 目录查找功能插件；
# quick-sharun 将插件放在 lib/copyq/plugins，导致图片插件存在但无法加载。
for plugin_dir in AppDir/shared/lib/copyq AppDir/lib/copyq; do
  if [[ -d "$plugin_dir/plugins" ]]; then
    while IFS= read -r -d '' plugin; do
      ln -sfn "plugins/$(basename "$plugin")" "$plugin_dir/$(basename "$plugin")"
    done < <(find "$plugin_dir/plugins" -maxdepth 1 -name 'libitem*.so' -print0)
  fi
done

# CopyQ 的翻译文件已经位于 AppDir/share/copyq/translations；
# 明确指定该目录，使语言列表能够显示简体中文、正体中文及其他翻译。
cat >> AppDir/.env <<'EOF_ENV'
COPYQ_TRANSLATION_PREFIX=$APPDIR/share/copyq/translations
EOF_ENV

quick-sharun --make-appimage
