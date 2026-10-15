#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 安装统一的 Arch AppImage 基础包
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base

die() {
  echo "Error: $*" >&2
  exit 1
}

rm -rf AppDir dist workbuddy.desktop workbuddy.png
[[ "$(uname -m)" == "x86_64" ]] || die "this script only supports x86_64 / linux-x64."

# AppImage 构建依赖；WorkBuddy 的 Linux 应用适配继续复用当前 AUR workbuddy 配方。
# asar 用来读取 app.asar 内的 payload 版本。makepkg 可能清掉仅作为 makedepends 安装的 asar。
yay -S --noconfirm --needed \
  gcc base-devel git curl jq wget tar gzip binutils patchelf coreutils file p7zip \
  appstream-glib desktop-file-utils util-linux zsync \
  xorg-server xorg-server-common xorg-server-xvfb \
  nss alsa-lib gtk3 at-spi2-core libsecret libxkbfile \
  libappindicator-gtk3 libnotify libxss libxtst shared-mime-info xdg-utils \
  gcc-libs glibc lsof inetutils \
  libx11 libxext libxi libxrandr libxkbcommon \
  libxcomposite libxdamage libxfixes mesa libglvnd libva libvdpau \
  pulseaudio pulseaudio-alsa pipewire-audio ibus imagemagick \
  asar

# AUR 的 .SRCINFO 与 PKGBUILD 曾出现版本不同步；先按 AUR 对外声明版本修正本次临时 PKGBUILD。
AUR_BUILD_PARENT="$(mktemp -d)"
AUR_BUILD_DIR="$AUR_BUILD_PARENT/workbuddy"
trap 'rm -rf "$AUR_BUILD_PARENT"' EXIT

for attempt in 1 2 3; do
  rm -rf "$AUR_BUILD_DIR"
  if git -c http.version=HTTP/1.1 clone --depth=1 \
    https://aur.archlinux.org/workbuddy.git "$AUR_BUILD_DIR"; then
    break
  fi
  if [[ "$attempt" -eq 3 ]]; then
    die "failed to clone the AUR workbuddy PKGBUILD."
  fi
  sleep 5
done

[[ -f "$AUR_BUILD_DIR/PKGBUILD" ]] || die "AUR workbuddy PKGBUILD was not found."
[[ -f "$AUR_BUILD_DIR/.SRCINFO" ]] || die "AUR workbuddy .SRCINFO was not found."

AUR_PKGVER="$(sed -n 's/^pkgver=//p' "$AUR_BUILD_DIR/PKGBUILD" | head -n 1)"
EXPECTED_PKGVER="$(awk -F ' = ' '/^[[:space:]]*pkgver = / {print $2; exit}' "$AUR_BUILD_DIR/.SRCINFO")"
[[ -n "$AUR_PKGVER" && -n "$EXPECTED_PKGVER" ]] || die "AUR workbuddy version metadata was not found."
[[ "$EXPECTED_PKGVER" =~ ^[0-9A-Za-z._+:-]+$ ]] || die "unexpected AUR workbuddy pkgver: $EXPECTED_PKGVER"

EXPECTED_DEB="WorkBuddy-linux-x64-deb-${EXPECTED_PKGVER//_/-}.deb"
grep -Fq "$EXPECTED_DEB" "$AUR_BUILD_DIR/.SRCINFO" || \
  die "AUR .SRCINFO version and Linux x64 DEB source do not match."

sed -i "0,/^pkgver=.*/s//pkgver=$EXPECTED_PKGVER/" "$AUR_BUILD_DIR/PKGBUILD"
cat >> "$AUR_BUILD_DIR/PKGBUILD" <<EOF_PKGVER

# Keep source resolution and package metadata on the same AUR-advertised version.
pkgver() {
  printf '%s\n' '$EXPECTED_PKGVER'
}
EOF_PKGVER

echo "AUR WorkBuddy version: $EXPECTED_PKGVER"
if [[ "$AUR_PKGVER" != "$EXPECTED_PKGVER" ]]; then
  echo "Correcting stale AUR PKGBUILD pkgver: $AUR_PKGVER -> $EXPECTED_PKGVER"
fi

if [[ "$EUID" -eq 0 ]]; then
  id builduser >/dev/null 2>&1 || die "builduser is required when running as root."
  chown -R builduser: "$AUR_BUILD_PARENT"
  sudo -HE -u builduser bash -lc "cd '$AUR_BUILD_DIR' && makepkg -si --noconfirm"
else
  (
    cd "$AUR_BUILD_DIR"
    makepkg -si --noconfirm
  )
fi

VERSION="$(pacman -Q workbuddy | awk '{print $2}')"
INSTALLED_PKGVER="${VERSION%-*}"
[[ "$INSTALLED_PKGVER" == "$EXPECTED_PKGVER" ]] || \
  die "installed WorkBuddy package version mismatch: $INSTALLED_PKGVER != $EXPECTED_PKGVER"

PACKAGE_FILES="$(pacman -Qlq workbuddy)"
APP_ASAR="$(awk '/\/resources\/app\.asar$/ && !found {print; found=1}' <<< "$PACKAGE_FILES")"
[[ -f "$APP_ASAR" ]] || die "WorkBuddy resources/app.asar was not found."
command -v asar >/dev/null 2>&1 || die "asar is required to read the WorkBuddy payload version."

APP_PAYLOAD_VERSION="$(asar extract-file "$APP_ASAR" package.json | jq -r '.version // empty')"
APP_PAYLOAD_VERSION="${APP_PAYLOAD_VERSION#v}"
EXPECTED_VERSION_BASE="${EXPECTED_PKGVER%%_*}"
IFS='.' read -r EXPECTED_MAJOR EXPECTED_MINOR EXPECTED_PATCH _ <<< "$EXPECTED_VERSION_BASE"
EXPECTED_APP_VERSION="$EXPECTED_MAJOR.$EXPECTED_MINOR.$EXPECTED_PATCH"
[[ "$APP_PAYLOAD_VERSION" == "$EXPECTED_APP_VERSION" || "$APP_PAYLOAD_VERSION" == "$EXPECTED_APP_VERSION".* ]] || \
  die "WorkBuddy payload version mismatch: $APP_PAYLOAD_VERSION != $EXPECTED_APP_VERSION"

RESOURCE_DIR="$(dirname "$APP_ASAR")"
UPSTREAM_ROOT="$(dirname "$RESOURCE_DIR")"
[[ "$(basename "$RESOURCE_DIR")" == "resources" ]] || \
  die "WorkBuddy app.asar is not inside a resources directory: $APP_ASAR"
[[ -x "$UPSTREAM_ROOT/workbuddy" ]] || \
  die "WorkBuddy upstream executable was not found: $UPSTREAM_ROOT/workbuddy"
[[ -d "$UPSTREAM_ROOT/locales" ]] || \
  die "WorkBuddy locales were not found: $UPSTREAM_ROOT/locales"
[[ -d "$RESOURCE_DIR/app.asar.unpacked" ]] || \
  die "WorkBuddy app.asar.unpacked was not found: $RESOURCE_DIR/app.asar.unpacked"

echo "WorkBuddy package version: $VERSION"
echo "WorkBuddy payload version: $APP_PAYLOAD_VERSION"
echo "WorkBuddy payload: $APP_ASAR"
echo "WorkBuddy runtime: $UPSTREAM_ROOT"

mkdir -p AppDir/bin dist
cp -a "$UPSTREAM_ROOT"/. AppDir/bin/

# Arch Electron 的可选 Qt6 主题 shim 不作为 AppImage 必需依赖。官方运行时通常没有该文件。
rm -f AppDir/bin/libqt6_shim.so

# 官方二进制本身就是 Electron，resources/app.asar 在它旁边。
# 改名后由同目录的壳补上 CI 参数，避免覆盖官方文件名。
mv AppDir/bin/workbuddy AppDir/bin/workbuddy.bin
cat > AppDir/bin/workbuddy <<'EOF_WRAPPER'
#!/usr/bin/env bash
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
export ELECTRON_FORCE_IS_PACKAGED=1

if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  exec "$HERE/workbuddy.bin" --disable-dev-shm-usage "$@"
fi

exec "$HERE/workbuddy.bin" "$@"
EOF_WRAPPER
chmod +x AppDir/bin/workbuddy

# 旧 AUR 会把 process.resourcesPath 写成单引号资源根。当前官方包不再这样做。
# 若解包目录又出现该字面量，停止构建，避免 AppImage 挂载路径变化后资源失效。
QUOTED_RESOURCE_ROOT="'${UPSTREAM_ROOT}/resources'"
if grep -RIq --fixed-strings "$QUOTED_RESOURCE_ROOT" AppDir/bin/resources/app.asar.unpacked 2>/dev/null; then
  die "WorkBuddy payload still hard-codes the AUR resource root: $QUOTED_RESOURCE_ROOT"
fi

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

# 记录当前上游版本，供构建成功后自动增量更新软件版本清单。
printf '%s\n' "$EXPECTED_PKGVER" > ./dist/version.txt
