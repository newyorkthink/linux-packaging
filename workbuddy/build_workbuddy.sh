#!/usr/bin/env bash
set -Eeuo pipefail

die() {
  echo "Error: $*" >&2
  exit 1
}

rm -rf AppDir dist workbuddy.desktop workbuddy.png
[[ "$(uname -m)" == "x86_64" ]] || die "this script only supports x86_64 / linux-x64."

# AppImage 构建依赖；WorkBuddy 的 Linux 应用适配由当前 AUR workbuddy 配方负责。
yay -S --noconfirm --needed \
  gcc base-devel git curl wget tar gzip binutils patchelf coreutils file p7zip \
  appstream-glib desktop-file-utils util-linux zsync \
  xorg-server xorg-server-common xorg-server-xvfb \
  nss alsa-lib gtk3 at-spi2-core libsecret libxkbfile \
  libappindicator-gtk3 libnotify libxss libxtst shared-mime-info xdg-utils \
  gcc-libs glibc lsof inetutils \
  libx11 libxext libxi libxrandr libxkbcommon \
  libxcomposite libxdamage libxfixes mesa libglvnd libva libvdpau \
  pulseaudio pulseaudio-alsa pipewire-audio ibus imagemagick

yay -S --noconfirm --needed workbuddy

VERSION="$(pacman -Q workbuddy | awk '{print $2}')"
PACKAGE_FILES="$(pacman -Qlq workbuddy)"
APP_PACKAGE_JSON="$(awk '/\/app\.asar\.unpacked\/package\.json$/ && !found {print; found=1}' <<< "$PACKAGE_FILES")"
[[ -f "$APP_PACKAGE_JSON" ]] || die "WorkBuddy app.asar.unpacked/package.json was not found."

APP_PAYLOAD_DIR="$(dirname "$APP_PACKAGE_JSON")"
AUR_RESOURCE_ROOT="$(dirname "$APP_PAYLOAD_DIR")"

# AUR 使用系统 Electron；把对应主版本的完整 runtime 收进 AppImage。
ELECTRON_VERSION="$(electron --no-sandbox --version)"
ELECTRON_MAJOR="${ELECTRON_VERSION#v}"
ELECTRON_MAJOR="${ELECTRON_MAJOR%%.*}"
ELECTRON_ROOT="/usr/lib/electron${ELECTRON_MAJOR}"
[[ -x "$ELECTRON_ROOT/electron" && -d "$ELECTRON_ROOT/resources" ]] || \
  die "Electron runtime is incomplete: $ELECTRON_ROOT"

echo "WorkBuddy AUR version: $VERSION"
echo "WorkBuddy payload: $APP_PAYLOAD_DIR"
echo "Electron runtime: $ELECTRON_ROOT"

mkdir -p AppDir/bin dist
cp -a "$ELECTRON_ROOT"/. AppDir/bin/

# Arch Electron 的可选 Qt6 主题 shim 不作为 AppImage 必需依赖。
rm -f AppDir/bin/libqt6_shim.so

rm -rf AppDir/bin/resources/app.asar.unpacked
cp -a "$APP_PAYLOAD_DIR" AppDir/bin/resources/app.asar.unpacked
APPDIR_PAYLOAD="AppDir/bin/resources/app.asar.unpacked"

# AUR 为系统安装把 process.resourcesPath 改成 /opt 下资源目录；
# AppImage 内恢复 process.resourcesPath，避免挂载路径变化后资源失效。
AUR_RESOURCE_LITERAL="'$AUR_RESOURCE_ROOT'"
while IFS= read -r -d '' patched_file; do
  sed -i "s#$AUR_RESOURCE_LITERAL#process.resourcesPath#g" "$patched_file"
done < <(grep -RIlZ --fixed-strings "$AUR_RESOURCE_LITERAL" "$APPDIR_PAYLOAD" 2>/dev/null || true)

if grep -RIq --fixed-strings "$AUR_RESOURCE_LITERAL" "$APPDIR_PAYLOAD" 2>/dev/null; then
  die "hard-coded AUR resource root remains: $AUR_RESOURCE_LITERAL"
fi

cat > AppDir/bin/workbuddy <<'EOF_WRAPPER'
#!/usr/bin/env bash
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
export ELECTRON_FORCE_IS_PACKAGED=1

if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  exec "$HERE/electron" --disable-dev-shm-usage "$HERE/resources/app.asar.unpacked" "$@"
fi

exec "$HERE/electron" "$HERE/resources/app.asar.unpacked" "$@"
EOF_WRAPPER
chmod +x AppDir/bin/workbuddy

# 直接复用 AUR desktop；只替换 launcher 前缀，保留 Desktop Actions 的 URI 参数和图标。
INSTALLED_DESKTOP="$(awk '/\/applications\/[^/]*workbuddy[^/]*\.desktop$/ && !found {print; found=1}' <<< "$PACKAGE_FILES")"
[[ -f "$INSTALLED_DESKTOP" ]] || die "WorkBuddy desktop entry was not found."
cp -a "$INSTALLED_DESKTOP" ./workbuddy.desktop
sed -i 's#^Exec=/usr/bin/workbuddy#Exec=workbuddy#' ./workbuddy.desktop

ICON_SOURCE="$(grep -Ei '/icons/.*/workbuddy\.png$' <<< "$PACKAGE_FILES" | sort -V | tail -n 1)"
[[ -f "$ICON_SOURCE" ]] || die "WorkBuddy PNG icon was not found."
cp -a "$ICON_SOURCE" ./workbuddy.png

# WorkBuddy Linux AppIndicator 固定从 resources 同级 .workbuddy-linux 目录读取托盘图标。
mkdir -p AppDir/bin/.workbuddy-linux
cp -a "$ICON_SOURCE" AppDir/bin/.workbuddy-linux/workbuddy.png

echo "$VERSION" > ~/version

export APPNAME=WorkBuddy
export STARTUPWMCLASS="$(sed -n 's/^StartupWMClass=//p' ./workbuddy.desktop | head -n 1)"
export STARTUPWMCLASS="${STARTUPWMCLASS:-WorkBuddy}"
export ICON=./workbuddy.png
export DESKTOP=./workbuddy.desktop
export OUTPATH=./dist
export OUTNAME=workbuddy.AppImage
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export DEPLOY_PIPEWIRE=1

# 保留已验证需要随 AppImage 部署的 ln、grep 和输入法/NSS 运行项。
quick-sharun \
  ./AppDir/bin/* \
  /usr/bin/hostname \
  /usr/bin/ln \
  /usr/bin/grep \
  /usr/lib/libnss* \
  /usr/lib/libsoftokn3.so \
  /usr/lib/libfreeblpriv3.so \
  /usr/lib/pkcs11/* \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so

quick-sharun --make-appimage
test -s ./dist/workbuddy.AppImage
