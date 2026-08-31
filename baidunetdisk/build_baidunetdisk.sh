#!/usr/bin/env bash
# 从百度官方 Linux 客户端元数据动态获取当前 x86_64 包，并重新封装为 AnyLinux AppImage。
# AUR baidunetdisk-bin / baidunetdisk-electron 仅作为依赖和包布局参考，不作为二进制来源。
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log() {
  printf '[BaiduNetDisk] %s\n' "$*"
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

#######################################################################
# 1. 构建环境与依赖
#######################################################################

readonly HOST_ARCH="$(uname -m)"
[[ "$HOST_ARCH" == x86_64 ]] || die "当前仅支持 x86_64。"
command -v yay >/dev/null 2>&1 || die "构建环境缺少命令：yay"

readonly CLIENT_API='https://pan.baidu.com/disk/cmsdata?do=client'
readonly SOURCE_DIR="$SCRIPT_DIR/source"
readonly PACKAGE_ROOT="$SOURCE_DIR/package"
readonly PACKAGE_FILE="$SOURCE_DIR/baidunetdisk-package"
readonly DEB_EXTRACT_DIR="$SOURCE_DIR/deb"
readonly APPDIR="$SCRIPT_DIR/AppDir"
readonly APP_ROOT="$APPDIR/bin"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly OUTFILE="$DIST_DIR/baidunetdisk.AppImage"
readonly VERIFY_DIR="$SCRIPT_DIR/verify"
readonly BUILD_DESKTOP="$SCRIPT_DIR/baidunetdisk.desktop"
readonly SMOKE_HOME="$SCRIPT_DIR/smoke-home"
readonly SMOKE_RUNTIME="$SCRIPT_DIR/smoke-runtime"
readonly SMOKE_LOG="$SCRIPT_DIR/baidunetdisk-smoke.log"

# 每次只清理百度网盘自己的构建目录、临时元数据和旧产物。
rm -rf \
  "$SOURCE_DIR" \
  "$APPDIR" \
  "$DIST_DIR" \
  "$VERIFY_DIR" \
  "$SMOKE_HOME" \
  "$SMOKE_RUNTIME"
rm -f "$BUILD_DESKTOP" "$SCRIPT_DIR"/baidunetdisk-build-icon.* "$SMOKE_LOG"
mkdir -p "$SOURCE_DIR" "$PACKAGE_ROOT" "$APP_ROOT" "$DIST_DIR"

# 安装 quick-sharun 所需工具、百度网盘 Electron/GTK 运行库和隔离图形测试组件。
# gtkmm 是 AUR 中保留的 GTK2 C++ ABI；它会拉取百度网盘当前仍需要的旧 GTK2 运行库。
yay -S --noconfirm --needed \
  base-devel binutils coreutils curl file findutils gawk grep libarchive patchelf python sed tar \
  appstream-glib desktop-file-utils inetutils util-linux zsync \
  xorg-server xorg-server-common xorg-server-xvfb xorg-xauth \
  nss nspr alsa-lib at-spi2-core cups dbus glib2 gtk3 gtkmm \
  libnotify libsecret libxss libxtst xdg-utils shared-mime-info \
  hicolor-icon-theme adwaita-icon-theme fontconfig freetype2 cairo pango gdk-pixbuf2 librsvg \
  libx11 libxext libxi libxrender libxrandr libxcomposite libxdamage libxfixes \
  libxcb libxkbcommon libxkbcommon-x11 mesa libglvnd libva libvdpau vulkan-icd-loader \
  libpulse pipewire-audio ibus

for command_name in \
  ar awk bsdtar chmod curl dbus-run-session desktop-file-validate file find grep \
  hostname install ldd quick-sharun readelf readlink sed sha256sum sort stat tar \
  timeout xvfb-run; do
  command -v "$command_name" >/dev/null 2>&1 || \
    die "构建环境缺少命令：$command_name"
done

#######################################################################
# 2. 获取百度官方 Linux 安装包
#######################################################################

log "读取百度官方 Linux 客户端元数据"
CLIENT_JSON="$(
  curl -fsSL \
    --retry 5 \
    --retry-all-errors \
    --retry-delay 2 \
    --connect-timeout 20 \
    "$CLIENT_API"
)"
[[ -n "$CLIENT_JSON" ]] || die "百度官方客户端元数据为空。"

mapfile -t CLIENT_META < <(
  printf '%s' "$CLIENT_JSON" | python3 -c '
import json, sys
payload = json.load(sys.stdin)
linux = payload.get("linux") or {}
print(linux.get("version") or "")
print(linux.get("url") or "")
'
)
[[ ${#CLIENT_META[@]} -eq 2 ]] || die "无法解析百度 Linux 客户端元数据。"

RAW_VERSION="${CLIENT_META[0]}"
PACKAGE_URL="${CLIENT_META[1]}"
if [[ "$RAW_VERSION" =~ ^(百度网盘Linux电脑客户端)?V?([0-9]+(\.[0-9]+)+)$ ]]; then
  VERSION="${BASH_REMATCH[2]}"
else
  die "百度官方元数据中的版本格式异常：$RAW_VERSION"
fi
readonly RAW_VERSION PACKAGE_URL VERSION

[[ "$PACKAGE_URL" =~ ^https://([A-Za-z0-9-]+\.)*(baidu\.com|baidupcs\.com)/ ]] || \
  die "百度官方元数据返回了非预期下载域名：$PACKAGE_URL"

PACKAGE_URL_PATH="${PACKAGE_URL%%\?*}"
readonly PACKAGE_URL_PATH
case "$PACKAGE_URL_PATH" in
  *.rpm) PACKAGE_TYPE=rpm ;;
  *.deb) PACKAGE_TYPE=deb ;;
  *) die "百度官方 Linux 下载地址不是 RPM 或 DEB：$PACKAGE_URL" ;;
esac
readonly PACKAGE_TYPE

# 当前官方 URL 的路径和文件名均含版本号；若接口字段不一致则停止，避免误打包其他资产。
[[ "$PACKAGE_URL_PATH" == *"$VERSION"* ]] || \
  die "官方下载地址与元数据版本不一致：version=$VERSION url=$PACKAGE_URL"

log "下载百度网盘官方 Linux 包：$VERSION ($PACKAGE_TYPE)"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  "$PACKAGE_URL" \
  -o "$PACKAGE_FILE"
[[ -s "$PACKAGE_FILE" ]] || die "百度官方下载文件为空。"
sha256sum "$PACKAGE_FILE"

case "$PACKAGE_TYPE" in
  rpm)
    file "$PACKAGE_FILE" | grep -qi 'RPM' || die "官方下载文件不是 RPM 软件包。"
    bsdtar -xf "$PACKAGE_FILE" -C "$PACKAGE_ROOT"
    ;;
  deb)
    file "$PACKAGE_FILE" | grep -q 'Debian binary package' || \
      die "官方下载文件不是 Debian 软件包。"
    mkdir -p "$DEB_EXTRACT_DIR"
    (
      cd "$DEB_EXTRACT_DIR"
      ar x "$PACKAGE_FILE"
    )
    shopt -s nullglob
    data_archives=("$DEB_EXTRACT_DIR"/data.tar.*)
    shopt -u nullglob
    [[ ${#data_archives[@]} -eq 1 ]] || \
      die "官方 DEB 中应且只能有一个 data.tar.*。"
    tar -xf "${data_archives[0]}" -C "$PACKAGE_ROOT"
    ;;
esac

#######################################################################
# 3. 组装百度官方运行目录
#######################################################################

readonly SOURCE_APP_ROOT="$PACKAGE_ROOT/opt/baidunetdisk"
[[ -d "$SOURCE_APP_ROOT" ]] || die "官方包缺少 /opt/baidunetdisk。"
[[ -x "$SOURCE_APP_ROOT/baidunetdisk" ]] || die "官方包缺少可执行主程序。"
file "$SOURCE_APP_ROOT/baidunetdisk" | grep -q 'ELF 64-bit' || \
  die "百度网盘主程序不是 64 位 ELF。"

# 优先使用官方固定 desktop 路径；仅在上游改名时才在官方包内回退查找。
if [[ -f "$PACKAGE_ROOT/usr/share/applications/baidunetdisk.desktop" ]]; then
  SOURCE_DESKTOP="$PACKAGE_ROOT/usr/share/applications/baidunetdisk.desktop"
else
  mapfile -d '' desktop_candidates < <(
    find "$PACKAGE_ROOT/usr/share/applications" \
      -maxdepth 1 -type f -iname '*baidu*netdisk*.desktop' -print0 2>/dev/null
  )
  [[ ${#desktop_candidates[@]} -eq 1 ]] || \
    die "官方包中无法唯一定位百度网盘 desktop 文件。"
  SOURCE_DESKTOP="${desktop_candidates[0]}"
fi
readonly SOURCE_DESKTOP

# 只从官方包中选择品牌图标；优先 hicolor 图标，并按文件大小选择信息量最高的一份。
mapfile -d '' icon_candidates < <(
  find \
    "$PACKAGE_ROOT/usr/share/icons" \
    "$PACKAGE_ROOT/usr/share/pixmaps" \
    "$SOURCE_APP_ROOT" \
    -type f \
    \( -iname '*baidunetdisk*.png' -o -iname '*baidunetdisk*.svg' -o \
       -iname '*baidu*netdisk*.png' -o -iname '*baidu*netdisk*.svg' \) \
    -print0 2>/dev/null
)
[[ ${#icon_candidates[@]} -gt 0 ]] || die "官方包中未找到百度网盘图标。"

SOURCE_ICON="${icon_candidates[0]}"
source_icon_size="$(stat -c '%s' "$SOURCE_ICON")"
for icon_candidate in "${icon_candidates[@]:1}"; do
  icon_size="$(stat -c '%s' "$icon_candidate")"
  if (( icon_size > source_icon_size )); then
    SOURCE_ICON="$icon_candidate"
    source_icon_size="$icon_size"
  fi
done
readonly SOURCE_ICON

case "$SOURCE_ICON" in
  *.png|*.PNG) ICON_EXT=png ;;
  *.svg|*.SVG) ICON_EXT=svg ;;
  *) die "官方图标格式不是 PNG/SVG。" ;;
esac
readonly ICON_EXT
readonly BUILD_ICON="$SCRIPT_DIR/baidunetdisk-build-icon.$ICON_EXT"

log "复制官方百度网盘完整运行目录"
cp -a "$SOURCE_APP_ROOT"/. "$APP_ROOT"/

# 删除上游误带入的 node-gyp 构建期 Python 启动器；它们不参与应用运行，且绑定已淘汰的 Python 3.6 ABI。
mapfile -d '' node_gyp_bin_dirs < <(
  find "$APP_ROOT" -type d -name node_gyp_bins -print0
)
if [[ ${#node_gyp_bin_dirs[@]} -gt 0 ]]; then
  printf 'BaiduNetDisk node-gyp helper directories removed: %s\n' "${#node_gyp_bin_dirs[@]}"
  rm -rf -- "${node_gyp_bin_dirs[@]}"
fi

# AppImage 无法依赖宿主机上的有效 setuid chrome-sandbox；与 Flathub 一致使用 --no-sandbox。
# 只移除 AppImage 内 chrome-sandbox 的 setuid 位，不修改宿主系统文件。
if [[ -e "$APP_ROOT/chrome-sandbox" ]]; then
  chmod 0755 "$APP_ROOT/chrome-sandbox"
fi

install -Dm0644 "$SOURCE_DESKTOP" "$BUILD_DESKTOP"
install -Dm0644 "$SOURCE_ICON" "$BUILD_ICON"

[[ "$(grep -c '^Exec=' "$BUILD_DESKTOP")" -eq 1 ]] || \
  die "官方 desktop 的 Exec 字段数量异常。"
[[ "$(grep -c '^Icon=' "$BUILD_DESKTOP")" -eq 1 ]] || \
  die "官方 desktop 的 Icon 字段数量异常。"
sed -i \
  -e 's|^Exec=.*|Exec=baidunetdisk %U|' \
  -e 's|^Icon=.*|Icon=baidunetdisk|' \
  "$BUILD_DESKTOP"
if ! grep -q '^StartupWMClass=' "$BUILD_DESKTOP"; then
  printf 'StartupWMClass=baidunetdisk\n' >> "$BUILD_DESKTOP"
fi
if ! grep -q '^X-AppImage-Version=' "$BUILD_DESKTOP"; then
  printf 'X-AppImage-Version=%s\n' "$VERSION" >> "$BUILD_DESKTOP"
fi
desktop-file-validate "$BUILD_DESKTOP"

#######################################################################
# 4. AppImage 打包
#######################################################################

cat > "$APPDIR/AppRun.sh" <<'APPRUN_EOF'
#!/bin/sh
set -e

export SHARUN_EXTRA_LIBRARY_PATH="$APPDIR/bin${SHARUN_EXTRA_LIBRARY_PATH:+:$SHARUN_EXTRA_LIBRARY_PATH}"
export SHARUN_WORKING_DIR="$APPDIR/bin"
export GTK_IM_MODULE="${GTK_IM_MODULE:-ibus}"
export XMODIFIERS="${XMODIFIERS:-@im=ibus}"

cd "$APPDIR/bin"
exec "$APPDIR/bin/baidunetdisk" --no-sandbox "$@"
APPRUN_EOF
chmod 0755 "$APPDIR/AppRun.sh"
bash -n "$APPDIR/AppRun.sh"

export ARCH=x86_64
export VERSION
export APPNAME='Baidu Netdisk'
export MAIN_BIN=baidunetdisk
export STARTUPWMCLASS=baidunetdisk
export ICON="$BUILD_ICON"
export DESKTOP="$BUILD_DESKTOP"
export OUTPATH="$DIST_DIR"
export OUTNAME=baidunetdisk.AppImage
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export DEPLOY_PIPEWIRE=1
# Flathub 明确禁用 strip；百度网盘运行文件被 strip 后会破坏应用。
export NO_STRIP=1

# 保持官方 Electron/Node 私有库的相对布局，只让 quick-sharun 部署主程序和外部系统库。
mapfile -t app_library_dirs < <(
  find "$APP_ROOT" -type f -printf '%h\n' | sort -u
)
[[ ${#app_library_dirs[@]} -gt 0 ]] || die "官方运行目录为空。"
BUILD_LIBRARY_PATH="$(IFS=:; printf '%s' "${app_library_dirs[*]}")"
BUILD_LIBRARY_PATH="$BUILD_LIBRARY_PATH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

elf_targets=()
while IFS= read -r -d '' target; do
  if readelf -h "$target" >/dev/null 2>&1; then
    elf_targets+=("$target")
  fi
done < <(find "$APP_ROOT" -type f -print0)
[[ ${#elf_targets[@]} -gt 0 ]] || die "官方运行目录中未找到 ELF 文件。"
printf 'BaiduNetDisk ELF files: %s\n' "${#elf_targets[@]}"

missing_dependencies=0
declare -A system_library_seen=()
system_library_targets=()
for target in "${elf_targets[@]}"; do
  target_library_path="$(dirname -- "$target"):$BUILD_LIBRARY_PATH"
  target_dependencies="$(LD_LIBRARY_PATH="$target_library_path" ldd "$target" 2>&1 || true)"
  if grep -Eq 'not found|version .* not found' <<< "$target_dependencies"; then
    printf '缺失/不兼容依赖文件：%s\n%s\n' "$target" "$target_dependencies" >&2
    missing_dependencies=1
  fi

  while IFS= read -r dependency_path; do
    dependency_path="$(readlink -f "$dependency_path")"
    [[ -f "$dependency_path" ]] || continue
    [[ "$dependency_path" != "$APP_ROOT/"* ]] || continue
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
[[ "$missing_dependencies" -eq 0 ]] || die "百度网盘官方组件仍存在缺失或 ABI 不兼容动态库。"
[[ ${#system_library_targets[@]} -gt 0 ]] || die "未解析到百度网盘外部系统库。"
printf 'BaiduNetDisk external libraries: %s\n' "${#system_library_targets[@]}"

shopt -s nullglob
extra_runtime_targets=(
  /usr/bin/hostname
  /usr/lib/libnss*.so*
  /usr/lib/libsoftokn3.so
  /usr/lib/libfreeblpriv3.so
  /usr/lib/pkcs11/*
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so
  /usr/lib/gtk-2.0/*/immodules/im-ibus.so
)
shopt -u nullglob

LD_LIBRARY_PATH="$BUILD_LIBRARY_PATH" quick-sharun \
  "$APP_ROOT/baidunetdisk" \
  "${system_library_targets[@]}" \
  "${extra_runtime_targets[@]}"

quick-sharun --make-appimage

#######################################################################
# 5. AppImage 产物完整性验证
#######################################################################

[[ -s "$OUTFILE" ]] || die "未生成预期文件：$OUTFILE"
chmod 0755 "$OUTFILE"
file "$OUTFILE"
"$OUTFILE" --appimage-version >/dev/null
sha256sum "$OUTFILE" > "$OUTFILE.sha256"

log "验证 AppImage 可提取"
mkdir -p "$VERIFY_DIR"
(
  cd "$VERIFY_DIR"
  "$OUTFILE" --appimage-extract >/dev/null
)
[[ -x "$VERIFY_DIR/squashfs-root/AppRun" ]] || die "AppImage 提取后缺少 AppRun。"
rm -rf "$VERIFY_DIR"

#######################################################################
# 6. 隔离启动测试
#######################################################################

log "执行隔离 Xvfb 图形启动测试"
mkdir -p \
  "$SMOKE_HOME/.config" \
  "$SMOKE_HOME/.cache" \
  "$SMOKE_HOME/.local/share" \
  "$SMOKE_RUNTIME"
chmod 0700 "$SMOKE_RUNTIME"

set +e
HOME="$SMOKE_HOME" \
XDG_CONFIG_HOME="$SMOKE_HOME/.config" \
XDG_CACHE_HOME="$SMOKE_HOME/.cache" \
XDG_DATA_HOME="$SMOKE_HOME/.local/share" \
XDG_RUNTIME_DIR="$SMOKE_RUNTIME" \
APPIMAGE_EXTRACT_AND_RUN=1 \
  timeout 25s dbus-run-session -- \
    xvfb-run -a "$OUTFILE" --disable-gpu >"$SMOKE_LOG" 2>&1
smoke_status=$?
set -e

if [[ "$smoke_status" -ne 0 && "$smoke_status" -ne 124 ]]; then
  cat "$SMOKE_LOG" >&2
  die "百度网盘图形启动测试异常退出，状态码：$smoke_status"
fi
if grep -Eqi \
  'error while loading shared libraries|symbol lookup error|invalid ELF header|wrong ELF class|Exec format error|Trace/breakpoint trap|Segmentation fault|Aborted \(core dumped\)|sqlcipher_page_cipher: hmac check failed|sqlite3codec: error decrypting|sqlcipher_codec_ctx_set_error' \
  "$SMOKE_LOG"; then
  cat "$SMOKE_LOG" >&2
  die "百度网盘启动日志包含致命运行时错误。"
fi

rm -rf "$SMOKE_HOME" "$SMOKE_RUNTIME"
rm -f "$SMOKE_LOG"

log "已生成：$OUTFILE"
