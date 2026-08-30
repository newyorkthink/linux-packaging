#!/usr/bin/env bash
# 从 AionUi 官方更新 CDN 动态获取当前 Linux x64 DEB，并重新封装为 AnyLinux AppImage。
# 只保留官方 Electron 应用本体、资源和原生模块；打包层仅补齐 Linux 运行库与便携启动入口。
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log() {
  printf '[AionUi] %s\n' "$*"
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

readonly HOST_ARCH="$(uname -m)"
[[ "$HOST_ARCH" == x86_64 ]] || die "当前仅支持 x86_64。"
command -v yay >/dev/null 2>&1 || die "构建环境缺少命令：yay"

readonly CDN_BASE='https://static.aionui.com/releases'
readonly METADATA_URL="$CDN_BASE/latest-linux.yml"
readonly SOURCE_DIR="$SCRIPT_DIR/source"
readonly METADATA_FILE="$SOURCE_DIR/latest-linux.yml"
readonly DEB_FILE="$SOURCE_DIR/aionui.deb"
readonly DEB_EXTRACT_DIR="$SOURCE_DIR/deb"
readonly PACKAGE_ROOT="$SOURCE_DIR/package"
readonly APPDIR="$SCRIPT_DIR/AppDir"
readonly APP_ROOT="$APPDIR/bin"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly OUTFILE="$DIST_DIR/aionui.AppImage"
readonly VERIFY_DIR="$SCRIPT_DIR/verify"
readonly BUILD_DESKTOP="$SCRIPT_DIR/AionUi.desktop"
readonly BUILD_ICON="$SCRIPT_DIR/aionui.png"
readonly SMOKE_HOME="$SCRIPT_DIR/smoke-home"
readonly SMOKE_RUNTIME="$SCRIPT_DIR/smoke-runtime"
readonly SMOKE_LOG="$SCRIPT_DIR/aionui-smoke.log"

# 每次只清理 AionUi 自己的构建目录、临时元数据和旧产物。
rm -rf \
  "$SOURCE_DIR" \
  "$APPDIR" \
  "$DIST_DIR" \
  "$VERIFY_DIR" \
  "$SMOKE_HOME" \
  "$SMOKE_RUNTIME"
rm -f "$BUILD_DESKTOP" "$BUILD_ICON" "$SMOKE_LOG"
mkdir -p "$SOURCE_DIR" "$DEB_EXTRACT_DIR" "$PACKAGE_ROOT" "$APP_ROOT" "$DIST_DIR"

# 安装 quick-sharun、Electron/GTK 运行库、输入法模块以及隔离 GUI 冒烟测试组件。
yay -S --noconfirm --needed \
  base-devel binutils coreutils curl file findutils gawk grep libarchive patchelf python sed tar \
  appstream-glib desktop-file-utils util-linux zsync \
  xorg-server xorg-server-common xorg-server-xvfb xorg-xauth \
  nss nspr alsa-lib at-spi2-core cups dbus glib2 gtk3 \
  libnotify libsecret shared-mime-info xdg-utils \
  hicolor-icon-theme adwaita-icon-theme fontconfig freetype2 cairo pango gdk-pixbuf2 librsvg \
  libx11 libxext libxi libxrender libxrandr libxcomposite libxdamage libxfixes libxss libxtst \
  libxcb libxkbcommon libxkbcommon-x11 \
  mesa libglvnd libva libvdpau vulkan-icd-loader \
  libpulse pipewire-audio ibus

for command_name in \
  ar awk chmod curl desktop-file-validate file find grep hostname install ldd quick-sharun \
  readelf readlink sed sha256sum sort stat tar timeout xvfb-run python3; do
  command -v "$command_name" >/dev/null 2>&1 || \
    die "构建环境缺少命令：$command_name"
done

log "读取 AionUi 官方 Linux x64 更新元数据"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  "$METADATA_URL" \
  -o "$METADATA_FILE"
[[ -s "$METADATA_FILE" ]] || die "AionUi 官方更新元数据为空。"

mapfile -t RELEASE_META < <(
  python3 - "$METADATA_FILE" <<'PY'
import re
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as fh:
    lines = fh.read().splitlines()

def scalar(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        value = value[1:-1]
    return value

version = ""
for raw in lines:
    match = re.match(r"^version:\s*(.+?)\s*$", raw)
    if match:
        version = scalar(match.group(1))
        break

if not re.fullmatch(r"[0-9]+(?:\.[0-9]+)+", version):
    raise SystemExit(f"invalid version in latest-linux.yml: {version!r}")

asset_name = ""
asset_sha512 = ""
for index, raw in enumerate(lines):
    match = re.match(r"^\s*-\s+url:\s*(.+?)\s*$", raw)
    if not match:
        continue
    candidate = scalar(match.group(1))
    if not re.fullmatch(rf"AionUi-{re.escape(version)}-linux-amd64\.deb", candidate):
        continue
    asset_name = candidate
    for following in lines[index + 1 :]:
        if re.match(r"^\s*-\s+url:", following):
            break
        digest_match = re.match(r"^\s+sha512:\s*(.+?)\s*$", following)
        if digest_match:
            asset_sha512 = scalar(digest_match.group(1))
            break
    break

if not asset_name:
    raise SystemExit("Linux amd64 DEB entry not found in latest-linux.yml")
if not re.fullmatch(r"[A-Za-z0-9+/=]+", asset_sha512):
    raise SystemExit("Linux amd64 DEB sha512 is missing or invalid")

print(version)
print(asset_name)
print(asset_sha512)
PY
)
[[ ${#RELEASE_META[@]} -eq 3 ]] || die "无法完整解析 AionUi Linux x64 元数据。"

readonly VERSION="${RELEASE_META[0]}"
readonly DEB_NAME="${RELEASE_META[1]}"
readonly EXPECTED_SHA512="${RELEASE_META[2]}"
readonly DEB_URL="$CDN_BASE/$VERSION/$DEB_NAME"

[[ "$DEB_NAME" == "AionUi-$VERSION-linux-amd64.deb" ]] || \
  die "AionUi 元数据中的资产名与版本不一致：$DEB_NAME"
[[ "$DEB_URL" == https://static.aionui.com/releases/"$VERSION"/AionUi-"$VERSION"-linux-amd64.deb ]] || \
  die "AionUi DEB URL 不符合预期：$DEB_URL"

printf 'AionUi version: %s\nAionUi DEB: %s\n' "$VERSION" "$DEB_URL"

log "下载 AionUi 官方 Linux x64 DEB"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  "$DEB_URL" \
  -o "$DEB_FILE"
[[ -s "$DEB_FILE" ]] || die "AionUi 官方 DEB 下载为空。"
file "$DEB_FILE" | grep -q 'Debian binary package' || die "AionUi 官方下载文件不是 Debian 软件包。"

ACTUAL_SHA512="$(
  python3 - "$DEB_FILE" <<'PY'
import base64
import hashlib
import sys

digest = hashlib.sha512()
with open(sys.argv[1], "rb") as fh:
    for chunk in iter(lambda: fh.read(1024 * 1024), b""):
        digest.update(chunk)
print(base64.b64encode(digest.digest()).decode("ascii"))
PY
)"
readonly ACTUAL_SHA512
[[ "$ACTUAL_SHA512" == "$EXPECTED_SHA512" ]] || die "AionUi 官方 DEB SHA-512 校验失败。"
sha256sum "$DEB_FILE"

log "提取官方 DEB"
(
  cd "$DEB_EXTRACT_DIR"
  ar x "$DEB_FILE"
)
shopt -s nullglob
data_archives=("$DEB_EXTRACT_DIR"/data.tar.*)
shopt -u nullglob
[[ ${#data_archives[@]} -eq 1 ]] || die "AionUi DEB 中应且只能有一个 data.tar.*。"
tar -xf "${data_archives[0]}" -C "$PACKAGE_ROOT"

# 只接受官方 /opt 下唯一的 AionUi 主程序，避免上游布局变化时误选其他 ELF。
mapfile -d '' main_candidates < <(
  find "$PACKAGE_ROOT/opt" -type f -name 'AionUi' -perm -0100 -print0 2>/dev/null
)
[[ ${#main_candidates[@]} -eq 1 ]] || \
  die "AionUi 官方包中应且只能找到一个 /opt/.../AionUi 主程序，实际为 ${#main_candidates[@]}。"
readonly SOURCE_MAIN="${main_candidates[0]}"
readonly SOURCE_APP_ROOT="$(dirname -- "$SOURCE_MAIN")"
file "$SOURCE_MAIN" | grep -q 'ELF 64-bit' || die "AionUi 主程序不是 64 位 ELF。"
[[ -f "$SOURCE_APP_ROOT/resources/app.asar" ]] || die "AionUi 官方包缺少 resources/app.asar。"
[[ -d "$SOURCE_APP_ROOT/resources/bundled-aioncore" ]] || \
  die "AionUi 官方包缺少 resources/bundled-aioncore。"
find "$SOURCE_APP_ROOT/resources/bundled-aioncore" -type f -print -quit | grep -q . || \
  die "AionUi bundled-aioncore 目录为空。"

# 使用官方 DEB 自带 desktop；上游改名时必须仍能唯一定位。
mapfile -d '' desktop_candidates < <(
  find "$PACKAGE_ROOT/usr/share/applications" -maxdepth 1 -type f -iname '*aionui*.desktop' -print0 2>/dev/null
)
[[ ${#desktop_candidates[@]} -eq 1 ]] || \
  die "AionUi 官方包中无法唯一定位 desktop 文件。"
readonly SOURCE_DESKTOP="${desktop_candidates[0]}"

# 优先使用官方安装到 hicolor/pixmaps 的 AionUi PNG；没有时再回退到应用自带 resources/app.png。
mapfile -d '' icon_candidates < <(
  find \
    "$PACKAGE_ROOT/usr/share/icons" \
    "$PACKAGE_ROOT/usr/share/pixmaps" \
    -type f -iname '*aionui*.png' -print0 2>/dev/null
)
if [[ ${#icon_candidates[@]} -eq 0 && -f "$SOURCE_APP_ROOT/resources/app.png" ]]; then
  icon_candidates=("$SOURCE_APP_ROOT/resources/app.png")
fi
[[ ${#icon_candidates[@]} -gt 0 ]] || die "AionUi 官方包中未找到 PNG 图标。"

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
file "$SOURCE_ICON" | grep -q 'PNG image data' || die "AionUi 官方图标不是 PNG。"

printf 'AionUi runtime: %s\nAionUi desktop: %s\nAionUi icon: %s\n' \
  "${SOURCE_APP_ROOT#"$PACKAGE_ROOT"/}" \
  "${SOURCE_DESKTOP#"$PACKAGE_ROOT"/}" \
  "${SOURCE_ICON#"$PACKAGE_ROOT"/}"

log "复制 AionUi 官方 Electron 运行目录"
cp -a "$SOURCE_APP_ROOT"/. "$APP_ROOT"/
[[ -x "$APP_ROOT/AionUi" ]] || die "复制后缺少 AionUi 主程序。"
[[ -f "$APP_ROOT/resources/app.asar" ]] || die "复制后缺少 AionUi app.asar。"
[[ -d "$APP_ROOT/resources/bundled-aioncore" ]] || die "复制后缺少 bundled-aioncore。"

# AppImage 内不保留有效的 setuid chrome-sandbox；便携入口显式使用 Electron no-sandbox。
if [[ -e "$APP_ROOT/chrome-sandbox" ]]; then
  chmod 0755 "$APP_ROOT/chrome-sandbox"
fi

# Node 原生模块由 Electron dlopen；移除执行位可避免 quick-sharun 把它们误当成独立启动入口。
find "$APP_ROOT" -type f -name '*.node' -exec chmod 0644 {} +
mapfile -d '' source_node_modules < <(
  find "$APP_ROOT" -type f -name '*.node' -print0
)
source_node_relative_paths=()
for node_module in "${source_node_modules[@]}"; do
  readelf -h "$node_module" >/dev/null 2>&1 || die "AionUi Node 模块不是 ELF：$node_module"
  source_node_relative_paths+=("${node_module#"$APP_ROOT"/}")
done
printf 'AionUi Node native modules: %s\n' "${#source_node_relative_paths[@]}"

# 基于官方 desktop 只改 AppImage 必需的 Exec/Icon/版本字段。
install -Dm0644 "$SOURCE_DESKTOP" "$BUILD_DESKTOP"
install -Dm0644 "$SOURCE_ICON" "$BUILD_ICON"
[[ "$(grep -c '^Exec=' "$BUILD_DESKTOP")" -eq 1 ]] || die "AionUi desktop 的 Exec 字段数量异常。"
[[ "$(grep -c '^Icon=' "$BUILD_DESKTOP")" -eq 1 ]] || die "AionUi desktop 的 Icon 字段数量异常。"
sed -i \
  -e 's|^Exec=.*|Exec=AionUi --no-sandbox --disable-setuid-sandbox %U|' \
  -e 's|^Icon=.*|Icon=aionui|' \
  "$BUILD_DESKTOP"
if grep -q '^StartupWMClass=' "$BUILD_DESKTOP"; then
  sed -i 's|^StartupWMClass=.*|StartupWMClass=AionUi|' "$BUILD_DESKTOP"
else
  printf 'StartupWMClass=AionUi\n' >> "$BUILD_DESKTOP"
fi
if grep -q '^X-AppImage-Version=' "$BUILD_DESKTOP"; then
  sed -i "s|^X-AppImage-Version=.*|X-AppImage-Version=$VERSION|" "$BUILD_DESKTOP"
else
  printf 'X-AppImage-Version=%s\n' "$VERSION" >> "$BUILD_DESKTOP"
fi
desktop-file-validate "$BUILD_DESKTOP"

cat > "$APPDIR/AppRun.sh" <<'APPRUN_EOF'
#!/bin/sh
set -e

export SHARUN_EXTRA_LIBRARY_PATH="$APPDIR/bin${SHARUN_EXTRA_LIBRARY_PATH:+:$SHARUN_EXTRA_LIBRARY_PATH}"
export SHARUN_WORKING_DIR="$APPDIR/bin"
export GTK_IM_MODULE="${GTK_IM_MODULE:-ibus}"
export XMODIFIERS="${XMODIFIERS:-@im=ibus}"

cd "$APPDIR/bin"
exec "$APPDIR/bin/AionUi" --no-sandbox --disable-setuid-sandbox "$@"
APPRUN_EOF
chmod 0755 "$APPDIR/AppRun.sh"
bash -n "$APPDIR/AppRun.sh"

printf '%s\n' "$VERSION" > ~/version

export ARCH=x86_64
export VERSION
export APPNAME=AionUi
export MAIN_BIN=AionUi
export STARTUPWMCLASS=AionUi
export ICON="$BUILD_ICON"
export DESKTOP="$BUILD_DESKTOP"
export OUTPATH="$DIST_DIR"
export OUTNAME=aionui.AppImage
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export DEPLOY_PIPEWIRE=1
export STRACE_MODE=0
export NO_STRIP=1

# 扫描官方运行目录全部 ELF，包括 Electron helper、原生模块和 bundled-aioncore。
elf_targets=()
while IFS= read -r -d '' target; do
  if readelf -h "$target" >/dev/null 2>&1; then
    elf_targets+=("$target")
  fi
done < <(find "$APP_ROOT" -type f -print0)
[[ ${#elf_targets[@]} -gt 0 ]] || die "AionUi 官方运行目录中未找到 ELF 文件。"
printf 'AionUi ELF files: %s\n' "${#elf_targets[@]}"

mapfile -t app_library_dirs < <(
  find "$APP_ROOT" -type f -printf '%h\n' | sort -u
)
[[ ${#app_library_dirs[@]} -gt 0 ]] || die "AionUi 官方运行目录为空。"
BUILD_LIBRARY_PATH="$(IFS=:; printf '%s' "${app_library_dirs[*]}")"
BUILD_LIBRARY_PATH="$BUILD_LIBRARY_PATH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

missing_dependencies=0
for target in "${elf_targets[@]}"; do
  target_library_path="$(dirname -- "$target"):$BUILD_LIBRARY_PATH"
  target_dependencies="$(LD_LIBRARY_PATH="$target_library_path" ldd "$target" 2>&1 || true)"
  if grep -Eq 'not found|version .* not found' <<< "$target_dependencies"; then
    printf '缺失/不兼容依赖文件：%s\n%s\n' "$target" "$target_dependencies" >&2
    missing_dependencies=1
  fi
done
[[ "$missing_dependencies" -eq 0 ]] || die "AionUi 官方组件仍存在缺失或 ABI 不兼容动态库。"

audio_targets=(
  /usr/lib/libasound.so.2
  /usr/lib/libpulse.so.0
  /usr/lib/libpulse-simple.so.0
  /usr/lib/libpipewire-0.3.so.0
)
for audio_target in "${audio_targets[@]}"; do
  [[ -e "$audio_target" ]] || die "构建环境缺少音频运行库：$audio_target"
done

shopt -s nullglob
pulse_common_targets=(/usr/lib/pulseaudio/libpulsecommon-*.so)
extra_runtime_targets=(
  /usr/bin/hostname
  /usr/lib/libnss*.so*
  /usr/lib/libsoftokn3.so
  /usr/lib/libfreeblpriv3.so
  /usr/lib/pkcs11/*
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so
)
shopt -u nullglob
[[ ${#pulse_common_targets[@]} -gt 0 ]] || die "构建环境缺少 libpulsecommon。"
[[ ${#extra_runtime_targets[@]} -gt 0 ]] || die "AionUi 额外运行目标为空。"

LD_LIBRARY_PATH="$BUILD_LIBRARY_PATH" quick-sharun \
  "${elf_targets[@]}" \
  "${audio_targets[@]}" \
  "${pulse_common_targets[@]}" \
  "${extra_runtime_targets[@]}"

quick-sharun --make-appimage
[[ -s "$OUTFILE" ]] || die "未生成预期文件：$OUTFILE"
chmod 0755 "$OUTFILE"

# 解包最终 AppImage，确认关键官方资源和原生模块确实保留在最终产物中。
mkdir -p "$VERIFY_DIR"
(
  cd "$VERIFY_DIR"
  "$OUTFILE" --appimage-extract >/dev/null
)
readonly VERIFY_APPDIR="$VERIFY_DIR/squashfs-root"
[[ -x "$VERIFY_APPDIR/AppRun" ]] || die "最终 AppImage 缺少 AppRun。"
[[ -f "$VERIFY_APPDIR/AionUi.desktop" ]] || die "最终 AppImage 缺少 AionUi.desktop。"
[[ -f "$VERIFY_APPDIR/aionui.png" ]] || die "最终 AppImage 缺少 aionui.png。"
[[ -f "$VERIFY_APPDIR/bin/resources/app.asar" ]] || die "最终 AppImage 缺少 resources/app.asar。"
[[ -d "$VERIFY_APPDIR/bin/resources/bundled-aioncore" ]] || \
  die "最终 AppImage 缺少 resources/bundled-aioncore。"

for node_relative_path in "${source_node_relative_paths[@]}"; do
  node_module="$VERIFY_APPDIR/bin/$node_relative_path"
  [[ -f "$node_module" ]] || die "最终 AppImage 缺少 Node 原生模块：$node_relative_path"
  readelf -h "$node_module" >/dev/null 2>&1 || \
    die "最终 AppImage 中的 Node 模块不是 ELF：$node_relative_path"
  [[ ! "$node_module" -ef "$VERIFY_APPDIR/AppRun" ]] || \
    die "最终 AppImage 中的 Node 模块被错误替换成 sharun：$node_relative_path"
done

verify_bundled_library() {
  local library_pattern="$1"
  local library_label="$2"
  local library_path
  library_path="$(
    find -H "$VERIFY_APPDIR" -type f -name "$library_pattern" -print -quit
  )"
  [[ -n "$library_path" ]] || die "最终 AppImage 缺少 $library_label 的实际库文件。"
}

verify_bundled_library 'libasound.so.*' libasound.so.2
verify_bundled_library 'libpulse.so.*' libpulse.so.0
verify_bundled_library 'libpipewire-0.3.so.*' libpipewire-0.3.so.0

# 使用隔离 HOME/XDG_RUNTIME_DIR 做 Xvfb 冒烟测试；124 表示 GUI 存活到超时。
mkdir -p "$SMOKE_HOME" "$SMOKE_RUNTIME"
chmod 0700 "$SMOKE_RUNTIME"
set +e
HOME="$SMOKE_HOME" \
XDG_RUNTIME_DIR="$SMOKE_RUNTIME" \
APPIMAGE_EXTRACT_AND_RUN=1 \
timeout 30s xvfb-run -a \
  "$OUTFILE" \
  --disable-gpu \
  --user-data-dir="$SMOKE_HOME/profile" \
  >"$SMOKE_LOG" 2>&1
smoke_rc=$?
set -e

cat "$SMOKE_LOG"
printf 'AionUi smoke test exit code: %s\n' "$smoke_rc"
if grep -Eqi \
  'error while loading shared libraries|cannot open shared object file|invalid ELF header|wrong ELF class|Exec format error|Trace/breakpoint trap|Segmentation fault' \
  "$SMOKE_LOG"; then
  die "AionUi 冒烟测试检测到致命运行错误。"
fi
if [[ "$smoke_rc" -eq 124 ]]; then
  if grep -Ei 'FATAL:' "$SMOKE_LOG" | \
    grep -Evqi 'FATAL:electron/shell/browser/electron_browser_main_parts\.cc:[0-9]+\] Failed to shutdown\.$'; then
    die "AionUi 冒烟测试检测到致命运行错误。"
  fi
elif grep -Eqi 'FATAL:' "$SMOKE_LOG"; then
  die "AionUi 冒烟测试检测到致命运行错误。"
fi
if [[ "$smoke_rc" -ne 0 && "$smoke_rc" -ne 124 ]]; then
  die "AionUi 在 Xvfb 冒烟测试中异常退出：$smoke_rc"
fi

sha256sum "$OUTFILE"
log "构建完成：$OUTFILE"
