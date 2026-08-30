#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 每次只清理 MailMaster 自己的构建目录和产物，避免旧文件混入新 AppImage。
rm -rf "$SCRIPT_DIR/AppDir" "$SCRIPT_DIR/dist"

# 安装 AppImage 构建工具，以及 MailMaster 的 Qt5、CEF、X11、声音和输入法运行依赖。
yay -S --noconfirm --needed \
  base-devel gcc git curl wget tar gzip xz binutils patchelf coreutils file inetutils \
  appstream-glib desktop-file-utils util-linux zsync \
  xorg-server xorg-server-common xorg-server-xvfb \
  nss nspr alsa-lib cups at-spi2-core dbus glib2 gtk3 ibus \
  libnotify libsecret shared-mime-info xdg-utils hicolor-icon-theme adwaita-icon-theme \
  libx11 libxext libxi libxrender libxrandr libxinerama libxcomposite \
  libxdamage libxfixes libxss libxtst libxcb xcb-util xcb-util-image \
  xcb-util-keysyms xcb-util-renderutil xcb-util-wm libxkbcommon libxkbcommon-x11 \
  mesa libglvnd libva libvdpau pulseaudio pulseaudio-alsa pipewire-audio

# 使用当前 AUR mailmaster 配方；该配方已经补齐 nss_wrapper、GConf stub 和 Qt 插件修复。
yay -S --noconfirm --needed mailmaster

readonly PACKAGE_NAME=mailmaster
readonly SYSTEM_APP_ROOT=/opt/mailmaster
readonly SYSTEM_DESKTOP=/usr/share/applications/mailmaster.desktop
readonly SYSTEM_ICON=/usr/share/icons/hicolor/256x256/apps/mailmaster.png

VERSION="$(pacman -Q "$PACKAGE_NAME" | awk '{print $2}')"
echo "MailMaster AUR 版本：$VERSION"

readonly APP_ROOT="$SCRIPT_DIR/AppDir/bin"
mkdir -p "$APP_ROOT" "$SCRIPT_DIR/AppDir/share/licenses" "$SCRIPT_DIR/dist"

# MailMaster 固定从主程序同层加载 libmastercore.so、CEF 和 Qt 资源，必须保持原始扁平目录。
cp -a "$SYSTEM_APP_ROOT"/. "$APP_ROOT"/

# AppImage 不保留有效的 setuid 权限；入口会显式使用 --no-sandbox，因此移除无效的 setuid 位。
chmod 0755 "$APP_ROOT/chrome-sandbox"

# AUR 系统包使用指向 /usr/lib 的绝对 libsasl2 软链接；AppImage 中改成包内相对链接。
SASL_SOURCE="$(readlink -f /usr/lib/libsasl2.so.3)"
rm -f "$APP_ROOT/lib/libsasl2.so.2" "$APP_ROOT/lib/libsasl2.so.3"
cp -aL "$SASL_SOURCE" "$APP_ROOT/lib/libsasl2.so.3"
ln -s libsasl2.so.3 "$APP_ROOT/lib/libsasl2.so.2"

# 保留 AUR 安装的自定义许可证文件。
cp -a /usr/share/licenses/mailmaster "$SCRIPT_DIR/AppDir/share/licenses/"

# 使用 AppImage 内的相对 Qt/CEF 路径，并在便携入口加入 CEF 支持的 --no-sandbox。
cat > "$SCRIPT_DIR/AppDir/AppRun.sh" <<'APPRUN_EOF'
#!/bin/sh
set -e

unset QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE QT_QUICK_CONTROLS_STYLE
export QT_QPA_PLATFORM=xcb
export QT_XCB_GL_INTEGRATION=none
export QT_IM_MODULE="${QT_IM_MODULE:-ibus}"
export SHARUN_ALLOW_QT_PLUGIN_PATH=1
export QT_PLUGIN_PATH="$APPDIR/bin/plugins"
export QT_QPA_PLATFORM_PLUGIN_PATH="$APPDIR/bin/plugins/platforms"
export SHARUN_EXTRA_LIBRARY_PATH="$APPDIR/bin:$APPDIR/bin/lib${SHARUN_EXTRA_LIBRARY_PATH:+:$SHARUN_EXTRA_LIBRARY_PATH}"
export SHARUN_WORKING_DIR="$APPDIR/bin"

exec "$APPDIR/bin/mailmaster" --no-sandbox "$@"
APPRUN_EOF
chmod 0755 "$SCRIPT_DIR/AppDir/AppRun.sh"

echo "$VERSION" > ~/version

export ARCH=x86_64
export VERSION
export APPNAME=MailMaster
export MAIN_BIN=mailmaster
export STARTUPWMCLASS=mailmaster
export ICON="$SYSTEM_ICON"
export DESKTOP="$SYSTEM_DESKTOP"
export OUTPATH="$SCRIPT_DIR/dist"
export OUTNAME=mailmaster.AppImage
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export DEPLOY_PIPEWIRE=1

# 构建阶段优先解析 MailMaster 自带的 Qt5、CEF 和 AUR 兼容库，再由 quick-sharun 收集系统依赖。
BUILD_LD_LIBRARY_PATH="$APP_ROOT:$APP_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
LD_LIBRARY_PATH="$BUILD_LD_LIBRARY_PATH" quick-sharun \
  "$APP_ROOT" \
  /usr/bin/curl \
  /usr/bin/hostname \
  /usr/lib/libnss* \
  /usr/lib/libsoftokn3.so \
  /usr/lib/libfreeblpriv3.so \
  /usr/lib/pkcs11/* \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so

quick-sharun --make-appimage
