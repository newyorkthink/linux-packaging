#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 每次只清理 MailMaster 自己的构建目录和产物，避免旧文件混入新 AppImage。
rm -rf "$SCRIPT_DIR/AppDir" "$SCRIPT_DIR/dist"
rm -f "$SCRIPT_DIR/mailmaster.desktop" "$SCRIPT_DIR/mailmaster.png"

readonly HOST_ARCH="$(uname -m)"
if [[ "$HOST_ARCH" != "x86_64" ]]; then
  echo "错误：MailMaster AppImage 当前只支持 x86_64。" >&2
  exit 1
fi

command -v yay >/dev/null 2>&1 || {
  echo "错误：未找到 yay。" >&2
  exit 1
}
command -v quick-sharun >/dev/null 2>&1 || {
  echo "错误：未找到 quick-sharun。" >&2
  exit 1
}

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

pacman -Q "$PACKAGE_NAME" >/dev/null 2>&1 || {
  echo "错误：AUR mailmaster 未成功安装。" >&2
  exit 1
}
[[ -x "$SYSTEM_APP_ROOT/mailmaster" ]] || {
  echo "错误：未找到 MailMaster 主程序。" >&2
  exit 1
}
[[ -f "$SYSTEM_APP_ROOT/lib/libnss_wrapper.so" ]] || {
  echo "错误：AUR 配方没有安装 libnss_wrapper.so。" >&2
  exit 1
}
[[ -f "$SYSTEM_APP_ROOT/lib/libgconf-2.so.4" ]] || {
  echo "错误：AUR 配方没有安装 libgconf-2.so.4。" >&2
  exit 1
}
[[ -f "$SYSTEM_DESKTOP" ]] || {
  echo "错误：未找到 MailMaster desktop 文件。" >&2
  exit 1
}

VERSION="$(pacman -Q "$PACKAGE_NAME" | awk '{print $2}')"
[[ -n "$VERSION" ]] || {
  echo "错误：无法读取 MailMaster AUR 版本。" >&2
  exit 1
}
echo "MailMaster AUR 版本：$VERSION"

readonly APP_ROOT="$SCRIPT_DIR/AppDir/bin/mailmaster-data"
mkdir -p "$APP_ROOT" "$SCRIPT_DIR/AppDir/share/licenses" "$SCRIPT_DIR/dist"

# 保留 AUR 已修复的完整 Qt5/CEF 程序目录，并改用 AppImage 内部相对路径启动。
cp -a "$SYSTEM_APP_ROOT"/. "$APP_ROOT"/

# AppImage 不保留有效的 setuid 权限；入口会显式使用 --no-sandbox，因此移除无效的 setuid 位。
chmod 0755 "$APP_ROOT/chrome-sandbox"

# AUR 系统包使用指向 /usr/lib 的绝对 libsasl2 软链接；AppImage 中改成包内相对链接。
SASL_SOURCE="$(readlink -f /usr/lib/libsasl2.so.3)"
[[ -f "$SASL_SOURCE" ]] || {
  echo "错误：未找到 libsasl2.so.3。" >&2
  exit 1
}
rm -f "$APP_ROOT/lib/libsasl2.so.2" "$APP_ROOT/lib/libsasl2.so.3"
cp -aL "$SASL_SOURCE" "$APP_ROOT/lib/libsasl2.so.3"
ln -s libsasl2.so.3 "$APP_ROOT/lib/libsasl2.so.2"

# 保留 AUR 安装的自定义许可证文件。
if [[ -d /usr/share/licenses/mailmaster ]]; then
  cp -a /usr/share/licenses/mailmaster "$SCRIPT_DIR/AppDir/share/licenses/"
fi

# AppImage 无法提供有效的 setuid Chrome sandbox，因此只在便携入口中加入 CEF 支持的 --no-sandbox。
cat > "$SCRIPT_DIR/AppDir/bin/mailmaster" <<'WRAPPER_EOF'
#!/usr/bin/env bash
set -e

HERE="$(cd -- "$(dirname -- "$0")" && pwd)"
APP_ROOT="$HERE/mailmaster-data"

unset QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE QT_QUICK_CONTROLS_STYLE
export QT_QPA_PLATFORM=xcb
export QT_XCB_GL_INTEGRATION=none
export QT_IM_MODULE="${QT_IM_MODULE:-ibus}"
export QT_PLUGIN_PATH="$APP_ROOT/plugins"
export QT_QPA_PLATFORM_PLUGIN_PATH="$APP_ROOT/plugins/platforms"
export LD_LIBRARY_PATH="$APP_ROOT:$APP_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

cd "$APP_ROOT"
exec "$APP_ROOT/mailmaster" --no-sandbox "$@"
WRAPPER_EOF
chmod 0755 "$SCRIPT_DIR/AppDir/bin/mailmaster"

# 复用 AUR 当前 desktop 元数据，只修正 AppImage 内的命令、图标和版本字段。
cp -a "$SYSTEM_DESKTOP" "$SCRIPT_DIR/mailmaster.desktop"
sed -i \
  -e 's#^Exec=.*#Exec=mailmaster %U#' \
  -e 's#^Icon=.*#Icon=mailmaster#' \
  "$SCRIPT_DIR/mailmaster.desktop"

if grep -q '^X-AppImage-Version=' "$SCRIPT_DIR/mailmaster.desktop"; then
  sed -i "s#^X-AppImage-Version=.*#X-AppImage-Version=$VERSION#" "$SCRIPT_DIR/mailmaster.desktop"
else
  printf 'X-AppImage-Version=%s\n' "$VERSION" >> "$SCRIPT_DIR/mailmaster.desktop"
fi
desktop-file-validate "$SCRIPT_DIR/mailmaster.desktop"

ICON_SOURCE="$(find /usr/share/icons/hicolor -type f -path '*/apps/mailmaster.png' -print | sort -V | tail -n 1)"
[[ -s "$ICON_SOURCE" ]] || {
  echo "错误：未找到 AUR 生成的 MailMaster PNG 图标。" >&2
  exit 1
}
cp -a "$ICON_SOURCE" "$SCRIPT_DIR/mailmaster.png"

echo "$VERSION" > ~/version

export ARCH=x86_64
export VERSION
export APPNAME=MailMaster
export STARTUPWMCLASS=mailmaster
export ICON="$SCRIPT_DIR/mailmaster.png"
export DESKTOP="$SCRIPT_DIR/mailmaster.desktop"
export OUTPATH="$SCRIPT_DIR/dist"
export OUTNAME=mailmaster.AppImage
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export DEPLOY_PIPEWIRE=1

# 构建阶段优先解析 MailMaster 自带的 Qt5、CEF 和 AUR 兼容库，再由 quick-sharun 收集系统依赖。
BUILD_LD_LIBRARY_PATH="$APP_ROOT:$APP_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
if LD_LIBRARY_PATH="$BUILD_LD_LIBRARY_PATH" ldd "$APP_ROOT/libmastercore.so" | grep -q 'not found'; then
  echo "错误：MailMaster 核心库仍有未解析依赖。" >&2
  LD_LIBRARY_PATH="$BUILD_LD_LIBRARY_PATH" ldd "$APP_ROOT/libmastercore.so" >&2 || true
  exit 1
fi
if LD_LIBRARY_PATH="$BUILD_LD_LIBRARY_PATH" ldd "$APP_ROOT/plugins/platforms/libqxcb.so" | grep -q 'not found'; then
  echo "错误：MailMaster Qt xcb 插件仍有未解析依赖。" >&2
  LD_LIBRARY_PATH="$BUILD_LD_LIBRARY_PATH" ldd "$APP_ROOT/plugins/platforms/libqxcb.so" >&2 || true
  exit 1
fi

LD_LIBRARY_PATH="$BUILD_LD_LIBRARY_PATH" quick-sharun \
  "$SCRIPT_DIR/AppDir/bin/mailmaster" \
  "$APP_ROOT" \
  /usr/bin/curl \
  /usr/bin/hostname \
  /usr/lib/libnss* \
  /usr/lib/libsoftokn3.so \
  /usr/lib/libfreeblpriv3.so \
  /usr/lib/pkcs11/* \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so

quick-sharun --make-appimage

[[ -s "$SCRIPT_DIR/dist/mailmaster.AppImage" ]] || {
  echo "错误：没有生成有效的 mailmaster.AppImage。" >&2
  exit 1
}
