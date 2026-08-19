#!/usr/bin/env bash
set -e

rm -rf AppDir dist || true

export ARCH=x86_64

export APPNAME="cc-switch"
export STARTUPWMCLASS="cc-switch"
export ICON="/usr/share/icons/hicolor/128x128/apps/cc-switch.png"
export DESKTOP="/usr/share/applications/CC Switch.desktop"
export OUTPATH=./dist
export OUTNAME="cc-switch.AppImage"

export DEPLOY_GTK=1

# 安装基础打包工具
yay -S --noconfirm \
  gcc base-devel wget curl tar gzip xz binutils patchelf coreutils \
  appstream-glib desktop-file-utils util-linux zsync \
  xorg-server xorg-server-common xorg-server-xvfb

# 安装 CC Switch / GTK / WebKit / 输入法 / 托盘相关依赖
# 依赖选择使用官方仓库版本：gtk3 / webkit2gtk-4.1，不使用 AUR 变体。
yay -S --noconfirm \
  cc-switch-bin \
  gtk3 ibus \
  libayatana-appindicator libdbusmenu-glib libdbusmenu-gtk3 \
  webkit2gtk-4.1 libsoup3 glib-networking gsettings-desktop-schemas \
  libsecret libnotify shared-mime-info xdg-utils \
  glib2 glibc gcc-libs zlib ca-certificates \
  libx11 libxext libxi libxtst libxss libxrandr libxinerama \
  libxcomposite libxdamage libxfixes libxkbcommon libxkbcommon-x11 libxkbfile \
  at-spi2-core cairo pango fribidi fontconfig freetype2 harfbuzz \
  gdk-pixbuf2 librsvg hicolor-icon-theme adwaita-icon-theme

# desktop / icon 由 DESKTOP / ICON 环境变量处理，不放进 quick-sharun 参数里。
# /usr/bin/hostname 先不加；如果实际运行报 hostname 相关错误，再补。
quick-sharun \
  /usr/bin/cc-switch \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so

quick-sharun --make-appimage
