#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

readonly WINE_SUITE='jammy'
readonly WINE_REPO='https://dl.winehq.org/wine-builds/ubuntu'
readonly APPIMAGE_BUILDER_VERSION='1.1.0'
readonly APPIMAGE_BUILDER_SHA256='4b4f99cae9291d78ba12dbdabca7c0a67c72aa61eb2e5d424089171a9485e96f'
readonly APPRUN_VERSION='v2.0.0'
readonly URUNTIME_VERSION='0.7.1'
readonly URUNTIME_SHA256='7faeea4dafc5794b4e090972dc862beeb5312cd0dd61aaa88ac74ddb8adbe549'

download() {
  local url="$1" output="$2"
  curl -fL --retry 4 --retry-all-errors --connect-timeout 20 --max-time 600 \
    "$url" -o "$output"
}

verify_sha256() {
  local expected="$1" file="$2"
  printf '%s  %s\n' "$expected" "$file" | sha256sum -c -
}

package_field() {
  local index="$1" package="$2" version="$3" field="$4"
  awk -v wanted_package="$package" -v wanted_version="$version" -v wanted_field="$field" '
    BEGIN { RS = ""; FS = "\n" }
    {
      package_name = ""; package_version = ""; value = ""
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^Package: /) package_name = substr($i, 10)
        else if ($i ~ /^Version: /) package_version = substr($i, 10)
        else if (index($i, wanted_field ": ") == 1) value = substr($i, length(wanted_field) + 3)
      }
      if (package_name == wanted_package && (wanted_version == "" || package_version == wanted_version)) {
        print value
        exit
      }
    }
  ' "$index"
}

package_versions() {
  local index="$1" package="$2"
  awk -v wanted_package="$package" '
    BEGIN { RS = ""; FS = "\n" }
    {
      package_name = ""; package_version = ""
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^Package: /) package_name = substr($i, 10)
        else if ($i ~ /^Version: /) package_version = substr($i, 10)
      }
      if (package_name == wanted_package) print package_version
    }
  ' "$index"
}

download_wine_package() {
  local index="$1" package="$2" version="$3"
  local filename sha256 output
  filename="$(package_field "$index" "$package" "$version" Filename)"
  sha256="$(package_field "$index" "$package" "$version" SHA256)"
  [[ -n "$filename" && "$sha256" =~ ^[[:xdigit:]]{64}$ ]] || {
    echo "错误：无法从 WineHQ 索引解析 $package=$version。" >&2
    exit 1
  }
  output="source/${filename##*/}"
  download "$WINE_REPO/$filename" "$output"
  verify_sha256 "$sha256" "$output"
  dpkg-deb -x "$output" AppDir
}

download_pinned_apprun_asset() {
  local asset="$1" expected="$2"
  local cache_dir="source/appimage-builder-cache/AppRun/$APPRUN_VERSION"
  mkdir -p "$cache_dir"
  download "https://github.com/AppImageCrafters/AppRun/releases/download/$APPRUN_VERSION/$asset" \
    "$cache_dir/$asset"
  verify_sha256 "$expected" "$cache_dir/$asset"
}

###### 准备 Ubuntu 构建环境 ######

[[ "$(uname -m)" == x86_64 ]] || {
  echo '错误：当前只生成 x86_64 AppImage（内含 amd64 与 i386 Wine）。' >&2
  exit 1
}
. /etc/os-release
[[ "${ID:-}" == ubuntu ]] || {
  echo '错误：Wine AppImage 必须在 Ubuntu runner 中构建。' >&2
  exit 1
}

# 只清理当前应用自己的可再生目录。
rm -rf -- AppDir dist source
mkdir -p AppDir dist source

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  ca-certificates curl file git gzip jq patchelf xz-utils

###### 动态解析并下载 WineHQ 最新 staging ######

download "$WINE_REPO/dists/$WINE_SUITE/main/binary-amd64/Packages.gz" source/Packages-amd64.gz
download "$WINE_REPO/dists/$WINE_SUITE/main/binary-i386/Packages.gz" source/Packages-i386.gz
gzip -dc source/Packages-amd64.gz > source/Packages-amd64
gzip -dc source/Packages-i386.gz > source/Packages-i386

WINE_PACKAGE_VERSION=''
while IFS= read -r candidate; do
  if [[ -z "$WINE_PACKAGE_VERSION" ]] || dpkg --compare-versions "$candidate" gt "$WINE_PACKAGE_VERSION"; then
    WINE_PACKAGE_VERSION="$candidate"
  fi
done < <(package_versions source/Packages-amd64 wine-staging-amd64)
[[ "$WINE_PACKAGE_VERSION" == *"~$WINE_SUITE-"* ]] || {
  echo '错误：无法解析 WineHQ staging 最新版本。' >&2
  exit 1
}
for package_spec in \
  'source/Packages-amd64 wine-staging' \
  'source/Packages-amd64 wine-staging-amd64' \
  'source/Packages-i386 wine-staging-i386'; do
  read -r index package <<< "$package_spec"
  matched_version="$(package_field "$index" "$package" "$WINE_PACKAGE_VERSION" Version)"
  [[ "$matched_version" == "$WINE_PACKAGE_VERSION" ]] || {
    echo "错误：$package 没有与 $WINE_PACKAGE_VERSION 配套的包。" >&2
    exit 1
  }
  download_wine_package "$index" "$package" "$WINE_PACKAGE_VERSION"
done

WINE_VERSION="${WINE_PACKAGE_VERSION#*:}"
WINE_VERSION="${WINE_VERSION%~$WINE_SUITE-*}"
# WineHQ 把上游 12.0-rc1 写成 12.0~rc1~jammy-1；tag/源码 URL 使用 -rc。
export WINE_VERSION="${WINE_VERSION/~rc/-rc}"
printf 'Wine staging: %s (%s)\n' "$WINE_VERSION" "$WINE_PACKAGE_VERSION"

###### 放入与当前 Wine 源码严格匹配的 Mono / Gecko ######

download "https://raw.githubusercontent.com/wine-mirror/wine/wine-$WINE_VERSION/dlls/appwiz.cpl/addons.c" \
  source/addons.c
GECKO_VERSION="$(sed -nE 's/^#define GECKO_VERSION "([^"]+)"/\1/p' source/addons.c)"
MONO_VERSION="$(sed -nE 's/^#define MONO_VERSION "([^"]+)"/\1/p' source/addons.c)"
GECKO_X86_SHA="$(awk '/^#ifdef __i386__/{found=1; next} found && /^#define GECKO_SHA /{split($0, parts, "\""); print parts[2]; exit}' source/addons.c)"
GECKO_X86_64_SHA="$(awk '/^#elif defined\(__x86_64__\)/{found=1; next} found && /^#define GECKO_SHA /{split($0, parts, "\""); print parts[2]; exit}' source/addons.c)"
MONO_X86_SHA="$(awk '/^#define MONO_VERSION /{found=1; next} found && /^#define MONO_SHA /{split($0, parts, "\""); print parts[2]; exit}' source/addons.c)"

for value in "$GECKO_X86_SHA" "$GECKO_X86_64_SHA" "$MONO_X86_SHA"; do
  [[ "$value" =~ ^[[:xdigit:]]{64}$ ]] || {
    echo '错误：无法从 Wine addons.c 解析 Mono/Gecko SHA-256。' >&2
    exit 1
  }
done

MONO_DIR='AppDir/opt/wine-staging/share/wine/mono'
GECKO_DIR='AppDir/opt/wine-staging/share/wine/gecko'
mkdir -p "$MONO_DIR" "$GECKO_DIR" AppDir/usr/bin
download "https://dl.winehq.org/wine/wine-mono/$MONO_VERSION/wine-mono-$MONO_VERSION-x86.msi" \
  "$MONO_DIR/wine-mono-$MONO_VERSION-x86.msi"
download "https://dl.winehq.org/wine/wine-gecko/$GECKO_VERSION/wine-gecko-$GECKO_VERSION-x86.msi" \
  "$GECKO_DIR/wine-gecko-$GECKO_VERSION-x86.msi"
download "https://dl.winehq.org/wine/wine-gecko/$GECKO_VERSION/wine-gecko-$GECKO_VERSION-x86_64.msi" \
  "$GECKO_DIR/wine-gecko-$GECKO_VERSION-x86_64.msi"
verify_sha256 "$MONO_X86_SHA" "$MONO_DIR/wine-mono-$MONO_VERSION-x86.msi"
verify_sha256 "$GECKO_X86_SHA" "$GECKO_DIR/wine-gecko-$GECKO_VERSION-x86.msi"
verify_sha256 "$GECKO_X86_64_SHA" "$GECKO_DIR/wine-gecko-$GECKO_VERSION-x86_64.msi"
printf 'Wine Mono: %s; Wine Gecko: %s\n' "$MONO_VERSION" "$GECKO_VERSION"

###### 下载上游资源和固定版本打包工具 ######

WINETRICKS_COMMIT="$(git ls-remote https://github.com/Winetricks/winetricks.git refs/heads/master | awk '{print $1}')"
[[ "$WINETRICKS_COMMIT" =~ ^[[:xdigit:]]{40}$ ]] || {
  echo '错误：无法解析 winetricks master 提交。' >&2
  exit 1
}
download "https://raw.githubusercontent.com/Winetricks/winetricks/$WINETRICKS_COMMIT/src/winetricks" \
  AppDir/usr/bin/winetricks
chmod +x AppDir/usr/bin/winetricks
sha256sum AppDir/usr/bin/winetricks

download "https://raw.githubusercontent.com/wine-mirror/wine/wine-$WINE_VERSION/programs/winecfg/winecfg.svg" \
  source/wine.svg
download "https://raw.githubusercontent.com/wine-mirror/wine/wine-$WINE_VERSION/loader/wine.desktop" \
  source/org.winehq.wine.desktop
sed -i \
  -e 's/^Name=.*/Name=Wine Staging Windows Program Loader/' \
  -e 's#^Exec=.*#Exec=wine.AppImage start /unix %f#' \
  -e 's/^NoDisplay=true/NoDisplay=false/' \
  source/org.winehq.wine.desktop

download "https://github.com/AppImageCrafters/appimage-builder/releases/download/v$APPIMAGE_BUILDER_VERSION/appimage-builder-$APPIMAGE_BUILDER_VERSION-x86_64.AppImage" \
  source/appimage-builder
verify_sha256 "$APPIMAGE_BUILDER_SHA256" source/appimage-builder
chmod +x source/appimage-builder

# AppRun v2.0.0 的旧 Release API 没有 digest 字段，因此固定并核对已审计 SHA-256。
download_pinned_apprun_asset AppRun-Release-x86_64 \
  c74e7e3a085c624260f0d144c02968d00fa9383f5d7fc46b32f1dc80d371d7ff
download_pinned_apprun_asset libapprun_hooks-Release-x86_64.so \
  1f64dd2161be3242f106c891b2daf27bbdd2103c20b28f57f61a56cdccb1eb6a
download_pinned_apprun_asset libapprun_hooks-Release-i386.so \
  5d346495586aef6c16b0d447cc0bef92a2a36aa212b9c1e3a467340899a2dc12

download "https://github.com/VHSgunzo/uruntime/releases/download/v$URUNTIME_VERSION/uruntime-appimage-dwarfs-x86_64" \
  source/uruntime
verify_sha256 "$URUNTIME_SHA256" source/uruntime
chmod +x source/uruntime

###### AppImageBuilder 收集双架构 Ubuntu 运行库并生成 AppRun ######

export APPIMAGE_EXTRACT_AND_RUN=1
source/appimage-builder \
  --recipe wine-staging.yml \
  --build-dir source/appimage-builder-cache \
  --skip-tests \
  --skip-appimage

# AppImageBuilder 只会为一个 ABI 选择 GStreamer scanner。移除其单 ABI 覆盖，
# 让 32/64 位 libgstreamer 各自通过上面的绝对路径映射找到配套 scanner/插件。
# 同时确保任何自动探测变量都不会屏蔽目标电脑自己的 GPU 驱动。
sed -i -E \
  '/^(GST_PLUGIN_PATH|GST_PLUGIN_SYSTEM_PATH|GST_PLUGIN_SYSTEM_PATH_1_0|GST_PLUGIN_SCANNER|GST_PTP_HELPER|GST_REGISTRY|GST_REGISTRY_UPDATE|LIBGL_DRIVERS_PATH|LIBVA_DRIVERS_PATH|VK_ICD_FILENAMES)=/d' \
  AppDir/AppRun.env

# 使用 Wine 官方 desktop；AppImageBuilder 已依据相同 app_info 生成 AppRun.env。
cp source/org.winehq.wine.desktop AppDir/org.winehq.wine.desktop
cp source/org.winehq.wine.desktop AppDir/usr/share/applications/org.winehq.wine.desktop
cp source/wine.svg AppDir/wine.svg
ln -sfn wine.svg AppDir/.DirIcon

###### 构建期完整性检查 ######

test -x AppDir/AppRun
test -x AppDir/opt/wine-staging/bin/wine
test -x AppDir/opt/wine-staging/bin/wineserver
test -x AppDir/usr/bin/winetricks
grep -Fq '/opt/wine-staging:$APPDIR/opt/wine-staging' AppDir/AppRun.env
test -s AppDir/lib/x86_64/libapprun_hooks.so
test -s AppDir/lib/i386/libapprun_hooks.so
grep -aFq 'libapprun_hooks.so' AppDir/AppRun

mapfile -t WINE_UNIX_BINARIES < <(find AppDir/opt/wine-staging -type f -path '*/wine/*-unix/wine' -print)
printf '%s\n' "${WINE_UNIX_BINARIES[@]}" | grep -q 'x86_64-unix/wine'
printf '%s\n' "${WINE_UNIX_BINARIES[@]}" | grep -q 'i386-unix/wine'

# 明确禁止把跨机器最容易冲突的 GPU 驱动/ICD 塞进包内。
if find AppDir \( -type f -o -type l \) \( \
  -path '*/dri/*' -o \
  -path '*/vdpau/libvdpau_nvidia.so*' -o \
  -path '*/vdpau/libvdpau_nouveau.so*' -o \
  -path '*/vdpau/libvdpau_radeonsi.so*' -o \
  -path '*/vdpau/libvdpau_va_gl.so*' -o \
  -path '*/vulkan/icd.d/*.json' -o \
  -name 'libnvidia*.so*' -o \
  -name 'libvulkan_*.so*' -o \
  -name 'libGLX_mesa.so*' -o \
  -name 'libEGL_mesa.so*' \
\) -print -quit | grep -q .; then
  echo '错误：检测到不应打包的主机 GPU 驱动或 Vulkan ICD。' >&2
  exit 1
fi

# wrapper 不得接管默认 Prefix，也不得操作 Wine 下载缓存。
if grep -Eq 'WINEPREFIX=|\.cache/wine|libunionpreload' wrapper; then
  echo '错误：wrapper 出现禁止的 Prefix、缓存或 libunionpreload 逻辑。' >&2
  exit 1
fi

###### 使用 uruntime DwarFS 封装固定名称产物 ######

source/uruntime --appimage-mkdwarfs \
  -i AppDir \
  -o source/wine.dwarfs \
  --force \
  --compress-level 9
cp source/uruntime dist/wine.AppImage
chmod u+w dist/wine.AppImage
cat source/wine.dwarfs >> dist/wine.AppImage
chmod +x dist/wine.AppImage

file dist/wine.AppImage | grep -q 'ELF 64-bit'
test "$(dist/wine.AppImage --appimage-offset)" -gt 0
printf '%s\n' "$WINE_VERSION" > dist/version.txt
sha256sum dist/wine.AppImage
