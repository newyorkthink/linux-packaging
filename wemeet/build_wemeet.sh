#!/usr/bin/env bash
# 从腾讯会议官方 x86_64 DEB 重封装 AppImage。
# AUR wemeet-bin 只提供当前版本、CDN 路径和 libwemeetwrap 源码，不作为二进制来源。
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
cd "$SCRIPT_DIR"

log() {
  printf '[WeMeet] %s\n' "$*"
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

HOST_ARCH="$(uname -m)"
readonly HOST_ARCH
[[ "$HOST_ARCH" == x86_64 ]] || die "当前仅支持 x86_64。"

readonly AUR_PKGBUILD_URL='https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=wemeet-bin'
readonly AUR_WRAP_URL='https://aur.archlinux.org/cgit/aur.git/plain/wrap.c?h=wemeet-bin'
readonly SOURCE_DIR="$SCRIPT_DIR/source"
readonly PACKAGE_ROOT="$SOURCE_DIR/package"
readonly AUR_DIR="$SOURCE_DIR/aur"
readonly APPDIR="$SCRIPT_DIR/AppDir"
readonly APP_BIN="$APPDIR/opt/wemeet/bin"
readonly VENDOR_LIB="$APPDIR/usr/lib/wemeet"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly OUTFILE="$DIST_DIR/wemeet.AppImage"
readonly BUILD_DESKTOP="$SCRIPT_DIR/wemeet.desktop"
readonly BUILD_ICON="$SCRIPT_DIR/wemeet.png"

rm -rf "$SOURCE_DIR" "$APPDIR" "$DIST_DIR"
rm -f "$BUILD_DESKTOP" "$BUILD_ICON"
mkdir -p "$SOURCE_DIR" "$PACKAGE_ROOT" "$AUR_DIR" "$APP_BIN" "$VENDOR_LIB" "$DIST_DIR"

yay -S --noconfirm --needed \
  base-devel binutils coreutils curl file findutils gawk grep patchelf pkgconf sed tar xz \
  appstream-glib desktop-file-utils util-linux zsync \
  gcc openssl libpulse libx11 libxinerama libxrandr libxext libxfixes libxcomposite \
  libxdamage libglvnd mesa alsa-lib zlib systemd-libs libyuv hicolor-icon-theme \
  qt5-base qt5-declarative qt5-svg qt5-x11extras qt5-wayland fcitx5-qt \
  xcb-util xcb-util-keysyms xcb-util-image xcb-util-wm xcb-util-renderutil xcb-util-cursor \
  libxkbcommon libxkbcommon-x11 libxss egl-wayland

for command_name in \
  ar awk cc curl desktop-file-validate file find grep install ldd patchelf \
  pkgconf quick-sharun readelf readlink sed sha256sum tar; do
  command -v "$command_name" >/dev/null 2>&1 || die "构建环境缺少命令：$command_name"
done

log "读取 AUR wemeet-bin 当前官方 DEB 元数据"
PKGBUILD="$(curl -fsSL --retry 5 --retry-all-errors --retry-delay 2 "$AUR_PKGBUILD_URL")"
[[ -n "$PKGBUILD" ]] || die "无法获取 AUR wemeet-bin PKGBUILD。"

pkgbuild_var() {
  local key="$1"
  awk -F= -v key="$key" '
    $1 == key {
      val=$2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      gsub(/^"/, "", val)
      gsub(/"$/, "", val)
      print val
      exit
    }
  ' <<< "$PKGBUILD"
}

VERSION="$(pkgbuild_var pkgver)"
X86_MD5="$(pkgbuild_var _x86_md5)"
[[ "$VERSION" =~ ^[0-9][0-9A-Za-z.+:~_-]*$ ]] || die "无法解析 AUR 版本：$VERSION"
[[ "$X86_MD5" =~ ^[0-9a-f]{32}$ ]] || die "无法解析 AUR x86_64 MD5：$X86_MD5"

DEB_URL="https://updatecdn.meeting.qq.com/cos/${X86_MD5}/TencentMeeting_0300000000_${VERSION}_x86_64_default.publish.deb"
DEB_FILE="$SOURCE_DIR/TencentMeeting_${VERSION}_x86_64.deb"

log "下载腾讯会议官方 x86_64 DEB ${VERSION}"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  --max-time 1800 \
  "$DEB_URL" \
  -o "$DEB_FILE"
[[ -s "$DEB_FILE" ]] || die "官方下载文件为空。"
file "$DEB_FILE" | grep -q 'Debian binary package' || die "官方下载文件不是 Debian 软件包。"

log "提取官方 DEB"
(
  cd "$SOURCE_DIR"
  ar x "$DEB_FILE"
)
shopt -s nullglob
control_archives=("$SOURCE_DIR"/control.tar.*)
data_archives=("$SOURCE_DIR"/data.tar.*)
shopt -u nullglob
[[ ${#control_archives[@]} -eq 1 ]] || die "官方 DEB 中应且只能有一个 control.tar.*。"
[[ ${#data_archives[@]} -eq 1 ]] || die "官方 DEB 中应且只能有一个 data.tar.*。"

CONTROL_VERSION="$(
  tar -xOf "${control_archives[0]}" ./control \
    | awk '$1 == "Version:" {print $2; exit}'
)"
if [[ "$CONTROL_VERSION" =~ ^[0-9][0-9A-Za-z.+:~_-]*$ ]]; then
  VERSION="$CONTROL_VERSION"
fi

tar -xf "${data_archives[0]}" -C "$PACKAGE_ROOT"
readonly SOURCE_APP_ROOT="$PACKAGE_ROOT/opt/wemeet"
[[ -d "$SOURCE_APP_ROOT/bin" ]] || die "官方 DEB 缺少 opt/wemeet/bin。"
[[ -x "$SOURCE_APP_ROOT/bin/wemeetapp" ]] || die "官方 DEB 缺少可执行主程序 wemeetapp。"
file "$SOURCE_APP_ROOT/bin/wemeetapp" | grep -q 'ELF 64-bit' || \
  die "wemeetapp 不是 64 位 ELF。"

log "获取 AUR wrap.c 并编译 libwemeetwrap.so"
curl -fsSL --retry 5 --retry-all-errors --retry-delay 2 "$AUR_WRAP_URL" -o "$AUR_DIR/wrap.c"
[[ -s "$AUR_DIR/wrap.c" ]] || die "无法获取 AUR wrap.c。"
read -ra openssl_args < <(pkgconf --cflags --libs openssl)
read -ra libpulse_args < <(pkgconf --cflags --libs libpulse)
read -ra x11_args < <(pkgconf --cflags --libs x11)
cc -Wall -Wextra -fPIC -shared \
  "${openssl_args[@]}" "${libpulse_args[@]}" "${x11_args[@]}" \
  -o "$AUR_DIR/libwemeetwrap.so" "$AUR_DIR/wrap.c" \
  -D WRAP_FORCE_SINK_HARDWARE
[[ -f "$AUR_DIR/libwemeetwrap.so" ]] || die "libwemeetwrap.so 编译失败。"

log "保留官方运行目录并按 AUR 布局放置厂商 Qt / 私有库"
cp -a "$SOURCE_APP_ROOT/bin/." "$APP_BIN/"
if [[ -f "$APP_BIN/qt.conf" ]]; then
  sed -i 's|^Prefix.*|Prefix = ../../usr/lib/wemeet|' "$APP_BIN/qt.conf"
fi
if [[ ! -e "$APP_BIN/xcast.conf" && -e "$APP_BIN/raw/xcast.conf" ]]; then
  ln -s raw/xcast.conf "$APP_BIN/xcast.conf"
fi

copy_vendor_glob() {
  local pattern="$1"
  shopt -s nullglob
  local files=($pattern)
  shopt -u nullglob
  [[ ${#files[@]} -gt 0 ]] || return 0
  cp -a "${files[@]}" "$VENDOR_LIB/"
}

copy_vendor_glob "$SOURCE_APP_ROOT/lib/libdesktop_common.so"
copy_vendor_glob "$SOURCE_APP_ROOT/lib/libcrash_guard.so"
copy_vendor_glob "$SOURCE_APP_ROOT/lib/libImSDK.so"
copy_vendor_glob "$SOURCE_APP_ROOT/lib/libnxui"*
copy_vendor_glob "$SOURCE_APP_ROOT/lib/libqt_"*
copy_vendor_glob "$SOURCE_APP_ROOT/lib/libui"*
copy_vendor_glob "$SOURCE_APP_ROOT/lib/libwemeet"*
copy_vendor_glob "$SOURCE_APP_ROOT/lib/libxcast"*
copy_vendor_glob "$SOURCE_APP_ROOT/lib/libxnn"*
copy_vendor_glob "$SOURCE_APP_ROOT/lib/libcrbase.so"
copy_vendor_glob "$SOURCE_APP_ROOT/lib/libQt"*
copy_vendor_glob "$SOURCE_APP_ROOT/lib/libicu"*
[[ -d "$SOURCE_APP_ROOT/plugins" ]] && cp -a "$SOURCE_APP_ROOT/plugins" "$VENDOR_LIB/"
[[ -d "$SOURCE_APP_ROOT/resources" ]] && cp -a "$SOURCE_APP_ROOT/resources" "$VENDOR_LIB/"
[[ -d "$SOURCE_APP_ROOT/translations" ]] && cp -a "$SOURCE_APP_ROOT/translations" "$VENDOR_LIB/"
install -Dm0755 "$AUR_DIR/libwemeetwrap.so" "$VENDOR_LIB/libwemeetwrap.so"

set_rpath() {
  local target="$1"
  local rpath="$2"
  readelf -h "$target" >/dev/null 2>&1 || return 0
  patchelf --set-rpath "$rpath" "$target" || true
}
while IFS= read -r -d '' target; do
  set_rpath "$target" '$ORIGIN'
done < <(find "$VENDOR_LIB" -type f \( -name '*.so' -o -name '*.so.*' \) -print0)
while IFS= read -r -d '' target; do
  set_rpath "$target" '$ORIGIN:$ORIGIN/../../usr/lib/wemeet'
done < <(find "$APP_BIN" -type f \( -name '*.so' -o -name '*.so.*' -o -name 'wemeetapp' \) -print0)

mapfile -d '' desktop_candidates < <(
  find "$PACKAGE_ROOT/usr/share/applications" \
    -maxdepth 1 -type f \( -iname '*wemeet*.desktop' \) -print0
)
[[ ${#desktop_candidates[@]} -ge 1 ]] || die "官方 DEB 中未找到 desktop 文件。"
SOURCE_DESKTOP="${desktop_candidates[0]}"

SOURCE_ICON=""
if [[ -f "$SOURCE_APP_ROOT/wemeet.svg" ]]; then
  SOURCE_ICON="$SOURCE_APP_ROOT/wemeet.svg"
else
  mapfile -d '' icon_candidates < <(
    find "$PACKAGE_ROOT" -type f \( -iname 'wemeetapp.png' -o -iname 'wemeet.png' -o -iname 'wemeet.svg' \) -print0
  )
  [[ ${#icon_candidates[@]} -gt 0 ]] || die "官方 DEB 中未找到图标。"
  SOURCE_ICON="${icon_candidates[0]}"
  source_icon_size="$(stat -c '%s' "$SOURCE_ICON")"
  for icon_candidate in "${icon_candidates[@]:1}"; do
    icon_size="$(stat -c '%s' "$icon_candidate")"
    if (( icon_size > source_icon_size )); then
      SOURCE_ICON="$icon_candidate"
      source_icon_size="$icon_size"
    fi
  done
fi

install -Dm0644 "$SOURCE_DESKTOP" "$BUILD_DESKTOP"
install -Dm0644 "$SOURCE_ICON" "$BUILD_ICON"
sed -i \
  -e 's|^Exec=.*|Exec=wemeet %u|' \
  -e 's|^Icon=.*|Icon=wemeet|' \
  "$BUILD_DESKTOP"
if ! grep -q '^StartupWMClass=' "$BUILD_DESKTOP"; then
  printf 'StartupWMClass=wemeetapp\n' >> "$BUILD_DESKTOP"
fi
if ! grep -q '^Keywords=' "$BUILD_DESKTOP"; then
  printf 'Keywords=wemeet;tencent;meeting;\n' >> "$BUILD_DESKTOP"
fi
if ! grep -q '^X-AppImage-Version=' "$BUILD_DESKTOP"; then
  printf 'X-AppImage-Version=%s\n' "$VERSION" >> "$BUILD_DESKTOP"
fi
desktop-file-validate "$BUILD_DESKTOP" || true

cat > "$APPDIR/AppRun.sh" <<'APPRUN_EOF'
#!/bin/sh
set -e

export QT_AUTO_SCREEN_SCALE_FACTOR="${QT_AUTO_SCREEN_SCALE_FACTOR:-1}"
export QT_STYLE_OVERRIDE="${QT_STYLE_OVERRIDE:-fusion}"
export IBUS_USE_PORTAL="${IBUS_USE_PORTAL:-1}"
export QT_IM_MODULE="${QT_IM_MODULE:-fcitx}"
export QT_PLUGIN_PATH="$APPDIR/usr/lib/wemeet/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
export QT_QPA_PLATFORM_PLUGIN_PATH="$APPDIR/usr/lib/wemeet/plugins/platforms"
export SHARUN_EXTRA_LIBRARY_PATH="$APPDIR/usr/lib/wemeet:$APPDIR/opt/wemeet/bin${SHARUN_EXTRA_LIBRARY_PATH:+:$SHARUN_EXTRA_LIBRARY_PATH}"
export SHARUN_WORKING_DIR="$APPDIR/opt/wemeet/bin"
export LD_LIBRARY_PATH="$APPDIR/usr/lib/wemeet:$APPDIR/opt/wemeet/bin${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
WRAP="$APPDIR/usr/lib/wemeet/libwemeetwrap.so"
if [ -f "$WRAP" ]; then
  export LD_PRELOAD="$WRAP${LD_PRELOAD:+:$LD_PRELOAD}"
fi

case "$(basename "$ARGV0" 2>/dev/null || basename "$0")" in
  wemeet-x11)
    export XDG_SESSION_TYPE=x11
    export EGL_PLATFORM=x11
    export QT_QPA_PLATFORM=xcb
    unset WAYLAND_DISPLAY
    ;;
  *)
    if [ "${XDG_SESSION_TYPE:-}" = wayland ]; then
      export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"
      export XDG_SESSION_TYPE=x11
      unset WAYLAND_DISPLAY
      export WEMEET_XWAYLAND=1
    else
      export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"
    fi
    ;;
esac

mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/fontconfig"
cd "$APPDIR/opt/wemeet/bin"
exec "$APPDIR/opt/wemeet/bin/wemeetapp" "$@"
APPRUN_EOF
chmod 0755 "$APPDIR/AppRun.sh"
bash -n "$APPDIR/AppRun.sh"

printf '%s\n' "$VERSION" > ~/version

export ARCH=x86_64
export VERSION
export APPNAME=WeMeet
export MAIN_BIN=wemeetapp
export STARTUPWMCLASS=wemeetapp
export ICON="$BUILD_ICON"
export DESKTOP="$BUILD_DESKTOP"
export OUTPATH="$DIST_DIR"
export OUTNAME=wemeet.AppImage
export DEPLOY_OPENGL=1
export DEPLOY_PIPEWIRE=1

BUILD_LIBRARY_PATH="$VENDOR_LIB:$APP_BIN${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

elf_targets=()
while IFS= read -r -d '' target; do
  if readelf -h "$target" >/dev/null 2>&1; then
    elf_targets+=("$target")
  fi
done < <(find "$APP_BIN" "$VENDOR_LIB" -type f -print0)
[[ ${#elf_targets[@]} -gt 0 ]] || die "未找到 ELF 文件。"

missing_dependencies=0
declare -A system_library_seen=()
system_library_targets=()
for target in "${elf_targets[@]}"; do
  target_library_path="$(dirname -- "$target"):$BUILD_LIBRARY_PATH"
  target_dependencies="$(LD_LIBRARY_PATH="$target_library_path" ldd "$target" 2>&1 || true)"
  if grep -Fq 'not found' <<< "$target_dependencies"; then
    printf '缺失依赖文件：%s\n%s\n' "$target" "$target_dependencies" >&2
    missing_dependencies=1
  fi
  while IFS= read -r dependency_path; do
    dependency_path="$(readlink -f "$dependency_path")"
    [[ -f "$dependency_path" ]] || continue
    [[ "$dependency_path" != "$APPDIR/"* ]] || continue
    if [[ -z "${system_library_seen[$dependency_path]+x}" ]]; then
      system_library_seen["$dependency_path"]=1
      system_library_targets+=("$dependency_path")
    fi
  done < <(
    awk '
      $2 == "=>" && $3 ~ /^\// {print $3; next}
      $1 ~ /^\// {print $1}
    ' <<< "$target_dependencies"
  )
done
[[ "$missing_dependencies" -eq 0 ]] || die "腾讯会议组件仍存在缺失动态库。"

shopt -s nullglob
pulse_targets=(
  /usr/lib/libpulse.so.0
  /usr/lib/libpulse-simple.so.0
  /usr/lib/pulseaudio/libpulsecommon-*.so
)
fcitx_targets=(/usr/lib/qt/plugins/platforminputcontexts/*fcitx*)
shopt -u nullglob
[[ -e /usr/lib/libpulse.so.0 ]] || die "构建环境缺少 libpulse.so.0。"

log "使用 quick-sharun 收集外部系统库"
LD_LIBRARY_PATH="$VENDOR_LIB:$APP_BIN${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" quick-sharun \
  "$APP_BIN/wemeetapp" \
  "$VENDOR_LIB/libwemeetwrap.so" \
  "${system_library_targets[@]}" \
  "${pulse_targets[@]}" \
  "${fcitx_targets[@]}"

[[ -x "$APP_BIN/wemeetapp" ]] || die "主程序在打包后丢失。"
readelf -h "$APP_BIN/wemeetapp" >/dev/null 2>&1 || die "wemeetapp 不再是 ELF。"
[[ ! "$APP_BIN/wemeetapp" -ef "$APPDIR/AppRun" ]] || die "wemeetapp 被错误替换成 sharun。"

quick-sharun --make-appimage
[[ -s "$OUTFILE" ]] || die "未生成预期文件：$OUTFILE"
chmod 0755 "$OUTFILE"

printf '%s\n' "$VERSION" > "$DIST_DIR/version.txt"
log "构建完成：$OUTFILE ($VERSION)"
