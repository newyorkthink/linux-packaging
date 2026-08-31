#!/usr/bin/env bash
# 从 Joplin 官方 GitHub Release 动态获取当前稳定版 Linux x64 DEB，并重新封装为 AnyLinux AppImage。
# 仅保留官方 Electron 应用本体、资源、desktop/icon 与原生模块；打包层只补齐便携运行所需依赖。
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log() {
  printf '[Joplin] %s\n' "$*"
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

readonly HOST_ARCH="$(uname -m)"
[[ "$HOST_ARCH" == x86_64 ]] || die "当前仅支持 x86_64。"
command -v yay >/dev/null 2>&1 || die "构建环境缺少命令：yay"

readonly RELEASE_API='https://api.github.com/repos/laurent22/joplin/releases/latest'
readonly SOURCE_DIR="$SCRIPT_DIR/source"
readonly RELEASE_JSON="$SOURCE_DIR/release.json"
readonly DEB_FILE="$SOURCE_DIR/joplin.deb"
readonly DEB_EXTRACT_DIR="$SOURCE_DIR/deb"
readonly PACKAGE_ROOT="$SOURCE_DIR/package"
readonly APPDIR="$SCRIPT_DIR/AppDir"
readonly APP_ROOT="$APPDIR/bin"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly OUTFILE="$DIST_DIR/joplin.AppImage"
readonly VERIFY_DIR="$SCRIPT_DIR/verify"
readonly BUILD_DESKTOP="$SCRIPT_DIR/joplin.desktop"
readonly BUILD_ICON="$SCRIPT_DIR/joplin.png"
readonly SMOKE_HOME="$SCRIPT_DIR/smoke-home"
readonly SMOKE_RUNTIME="$SCRIPT_DIR/smoke-runtime"
readonly SMOKE_LOG="$SCRIPT_DIR/joplin-smoke.log"

# 每次只清理 Joplin 自己的 CI 构建目录、临时文件和旧产物。
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
  appstream-glib desktop-file-utils inetutils util-linux zsync \
  xorg-server xorg-server-common xorg-server-xvfb xorg-xauth \
  nss nspr alsa-lib at-spi2-core cups dbus glib2 gtk3 \
  libnotify libsecret shared-mime-info xdg-utils \
  hicolor-icon-theme adwaita-icon-theme fontconfig freetype2 cairo pango gdk-pixbuf2 librsvg \
  libx11 libxext libxi libxrender libxrandr libxcomposite libxdamage libxfixes libxss libxtst \
  libxcb libxkbcommon libxkbcommon-x11 \
  mesa libglvnd libva libvdpau vulkan-icd-loader \
  libpulse pipewire-audio ibus

for command_name in \
  ar chmod curl desktop-file-validate file find grep hostname ldd quick-sharun \
  readelf sed sha256sum sort stat tar timeout xvfb-run python3; do
  command -v "$command_name" >/dev/null 2>&1 || \
    die "构建环境缺少命令：$command_name"
done

log "读取 Joplin 官方最新稳定版 Release 元数据"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  -H 'Accept: application/vnd.github+json' \
  "$RELEASE_API" \
  -o "$RELEASE_JSON"
[[ -s "$RELEASE_JSON" ]] || die "Joplin Release 元数据为空。"

mapfile -t RELEASE_META < <(
  python3 - "$RELEASE_JSON" <<'PY'
import json
import re
import sys
from urllib.parse import urlparse

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    release = json.load(fh)

if release.get("draft") or release.get("prerelease"):
    raise SystemExit("latest release is not a stable release")

tag = str(release.get("tag_name", ""))
match = re.fullmatch(r"v?([0-9]+(?:\.[0-9]+)+)", tag)
if not match:
    raise SystemExit(f"invalid stable tag: {tag!r}")
version = match.group(1)
asset_name = f"Joplin-{version}.deb"
assets = [asset for asset in release.get("assets", []) if asset.get("name") == asset_name]
if len(assets) != 1:
    raise SystemExit(f"expected exactly one {asset_name!r} asset, got {len(assets)}")
asset = assets[0]
url = str(asset.get("browser_download_url", ""))
digest = str(asset.get("digest", ""))
parsed = urlparse(url)
expected_path = f"/laurent22/joplin/releases/download/{tag}/{asset_name}"
if parsed.scheme != "https" or parsed.netloc != "github.com" or parsed.path != expected_path:
    raise SystemExit(f"unexpected Joplin DEB URL: {url!r}")
if not re.fullmatch(r"sha256:[0-9a-fA-F]{64}", digest):
    raise SystemExit(f"missing or invalid GitHub asset digest: {digest!r}")
print(version)
print(url)
print(digest.split(":", 1)[1].lower())
PY
)
[[ ${#RELEASE_META[@]} -eq 3 ]] || die "无法完整解析 Joplin 最新稳定版元数据。"

readonly VERSION="${RELEASE_META[0]}"
readonly DEB_URL="${RELEASE_META[1]}"
readonly EXPECTED_SHA256="${RELEASE_META[2]}"

printf 'Joplin version: %s\nJoplin DEB: %s\n' "$VERSION" "$DEB_URL"

log "下载 Joplin 官方 Linux x64 DEB"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  "$DEB_URL" \
  -o "$DEB_FILE"
[[ -s "$DEB_FILE" ]] || die "Joplin 官方 DEB 下载为空。"
file "$DEB_FILE" | grep -q 'Debian binary package' || die "Joplin 官方下载文件不是 Debian 软件包。"

readonly ACTUAL_SHA256="$(sha256sum "$DEB_FILE" | awk '{print $1}')"
[[ "$ACTUAL_SHA256" == "$EXPECTED_SHA256" ]] || die "Joplin 官方 DEB SHA-256 校验失败。"
sha256sum "$DEB_FILE"

log "提取 Joplin 官方 DEB"
(
  cd "$DEB_EXTRACT_DIR"
  ar x "$DEB_FILE"
)
shopt -s nullglob
data_archives=("$DEB_EXTRACT_DIR"/data.tar.*)
shopt -u nullglob
[[ ${#data_archives[@]} -eq 1 ]] || die "Joplin DEB 中应且只能有一个 data.tar.*。"
tar -xf "${data_archives[0]}" -C "$PACKAGE_ROOT"

# 以 Electron 的 resources/app.asar 为锚点定位官方应用目录，避免写死 /opt 下的版本化路径。
mapfile -d '' app_asar_candidates < <(
  find "$PACKAGE_ROOT/opt" -type f -path '*/resources/app.asar' -print0 2>/dev/null
)
[[ ${#app_asar_candidates[@]} -eq 1 ]] || \
  die "Joplin 官方包中应且只能找到一个 /opt/.../resources/app.asar，实际为 ${#app_asar_candidates[@]}。"
readonly SOURCE_APP_ROOT="$(dirname -- "$(dirname -- "${app_asar_candidates[0]}")")"

mapfile -d '' main_candidates < <(
  find "$SOURCE_APP_ROOT" -maxdepth 1 -type f -iname 'joplin' -perm -0100 -print0
)
[[ ${#main_candidates[@]} -eq 1 ]] || \
  die "Joplin 官方应用目录中应且只能找到一个 joplin 主程序，实际为 ${#main_candidates[@]}。"
readonly SOURCE_MAIN="${main_candidates[0]}"
file "$SOURCE_MAIN" | grep -q 'ELF 64-bit' || die "Joplin 主程序不是 64 位 ELF。"

# 复用官方 desktop 文件，避免自行改变协议、MIME 类型或分类。
mapfile -d '' desktop_candidates < <(
  find "$PACKAGE_ROOT/usr/share/applications" -maxdepth 1 -type f -iname '*joplin*.desktop' -print0 2>/dev/null
)
[[ ${#desktop_candidates[@]} -eq 1 ]] || die "Joplin 官方包中无法唯一定位 desktop 文件。"
readonly SOURCE_DESKTOP="${desktop_candidates[0]}"

# 优先使用官方 DEB 安装的 Joplin PNG，选择文件体积最大的候选作为 AppImage 主图标。
mapfile -d '' icon_candidates < <(
  find \
    "$PACKAGE_ROOT/usr/share/icons" \
    "$PACKAGE_ROOT/usr/share/pixmaps" \
    -type f -iname '*joplin*.png' -print0 2>/dev/null
)
if [[ ${#icon_candidates[@]} -eq 0 ]]; then
  mapfile -d '' icon_candidates < <(
    find "$SOURCE_APP_ROOT/resources" -type f -name '*.png' -path '*/icons/*' -print0 2>/dev/null
  )
fi
[[ ${#icon_candidates[@]} -gt 0 ]] || die "Joplin 官方包中未找到 PNG 图标。"
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
file "$SOURCE_ICON" | grep -q 'PNG image data' || die "Joplin 官方图标不是 PNG。"

printf 'Joplin runtime: %s\nJoplin desktop: %s\nJoplin icon: %s\n' \
  "${SOURCE_APP_ROOT#"$PACKAGE_ROOT"/}" \
  "${SOURCE_DESKTOP#"$PACKAGE_ROOT"/}" \
  "${SOURCE_ICON#"$PACKAGE_ROOT"/}"

log "复制 Joplin 官方 Electron 运行目录"
cp -a "$SOURCE_APP_ROOT"/. "$APP_ROOT"/
[[ -x "$APP_ROOT/$(basename -- "$SOURCE_MAIN")" ]] || die "复制后缺少 Joplin 主程序。"
[[ -f "$APP_ROOT/resources/app.asar" ]] || die "复制后缺少 Joplin resources/app.asar。"

# 不在最终 AppImage 中引入有效 setuid；Joplin 默认保持 Electron 自身的用户命名空间沙箱行为。
if [[ -e "$APP_ROOT/chrome-sandbox" ]]; then
  chmod 0755 "$APP_ROOT/chrome-sandbox"
fi

# Node 原生模块由 Electron dlopen；移除执行位，避免被误识别为独立启动程序。
find "$APP_ROOT" -type f -name '*.node' -exec chmod 0644 {} +
mapfile -d '' source_node_modules < <(
  find "$APP_ROOT" -type f -name '*.node' -print0
)
source_node_relative_paths=()
for node_module in "${source_node_modules[@]}"; do
  readelf -h "$node_module" >/dev/null 2>&1 || die "Joplin Node 模块不是 ELF：$node_module"
  source_node_relative_paths+=("${node_module#"$APP_ROOT"/}")
done
printf 'Joplin Node native modules: %s\n' "${#source_node_relative_paths[@]}"

# 基于官方 desktop 只修改 AppImage 所需的 Exec、Icon 和版本字段。
cp -a "$SOURCE_DESKTOP" "$BUILD_DESKTOP"
cp -a "$SOURCE_ICON" "$BUILD_ICON"
chmod 0644 "$BUILD_DESKTOP" "$BUILD_ICON"
[[ "$(grep -c '^Exec=' "$BUILD_DESKTOP")" -eq 1 ]] || die "Joplin desktop 的 Exec 字段数量异常。"
[[ "$(grep -c '^Icon=' "$BUILD_DESKTOP")" -eq 1 ]] || die "Joplin desktop 的 Icon 字段数量异常。"
sed -i \
  -e 's|^Exec=.*|Exec=joplin %U|' \
  -e 's|^Icon=.*|Icon=joplin|' \
  "$BUILD_DESKTOP"
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

cd "$APPDIR/bin"
exec "$APPDIR/bin/joplin" "$@"
APPRUN_EOF
chmod 0755 "$APPDIR/AppRun.sh"
bash -n "$APPDIR/AppRun.sh"

export ARCH=x86_64
export VERSION
export APPNAME=Joplin
export MAIN_BIN=joplin
export STARTUPWMCLASS='@joplin/app-desktop'
export ICON="$BUILD_ICON"
export DESKTOP="$BUILD_DESKTOP"
export OUTPATH="$DIST_DIR"
export OUTNAME=joplin.AppImage
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export DEPLOY_PIPEWIRE=1
export STRACE_MODE=0
export NO_STRIP=1

# 扫描官方运行目录内全部 ELF，包括 Electron helper 与 Node 原生模块。
elf_targets=()
while IFS= read -r -d '' target; do
  if readelf -h "$target" >/dev/null 2>&1; then
    elf_targets+=("$target")
  fi
done < <(find "$APP_ROOT" -type f -print0)
[[ ${#elf_targets[@]} -gt 0 ]] || die "Joplin 官方运行目录中未找到 ELF 文件。"
printf 'Joplin ELF files: %s\n' "${#elf_targets[@]}"

elf_library_dirs=()
for target in "${elf_targets[@]}"; do
  elf_library_dirs+=("$(dirname -- "$target")")
done
mapfile -t app_library_dirs < <(
  printf '%s\n' "${elf_library_dirs[@]}" | sort -u
)
[[ ${#app_library_dirs[@]} -gt 0 ]] || die "Joplin ELF 库搜索目录为空。"
BUILD_LIBRARY_PATH="$(IFS=:; printf '%s' "${app_library_dirs[*]}")"
if [[ -n "${LD_LIBRARY_PATH:-}" ]]; then
  BUILD_LIBRARY_PATH="$BUILD_LIBRARY_PATH:$LD_LIBRARY_PATH"
fi

missing_dependencies=0
for target in "${elf_targets[@]}"; do
  target_library_path="$(dirname -- "$target"):$BUILD_LIBRARY_PATH"
  target_dependencies="$(LD_LIBRARY_PATH="$target_library_path" ldd "$target" 2>&1 || true)"
  if grep -Eq 'not found|version .* not found' <<< "$target_dependencies"; then
    printf '缺失/不兼容依赖文件：%s\n%s\n' "$target" "$target_dependencies" >&2
    missing_dependencies=1
  fi
done
[[ "$missing_dependencies" -eq 0 ]] || die "Joplin 官方组件仍存在缺失或 ABI 不兼容动态库。"

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
[[ ${#extra_runtime_targets[@]} -gt 0 ]] || die "Joplin 额外运行目标为空。"

LD_LIBRARY_PATH="$BUILD_LIBRARY_PATH" quick-sharun \
  "${elf_targets[@]}" \
  "${audio_targets[@]}" \
  "${pulse_common_targets[@]}" \
  "${extra_runtime_targets[@]}"

quick-sharun --make-appimage
[[ -s "$OUTFILE" ]] || die "未生成预期文件：$OUTFILE"
chmod 0755 "$OUTFILE"

# 解包最终 AppImage，确认官方应用资源、desktop/icon 与原生模块都保留完整。
mkdir -p "$VERIFY_DIR"
(
  cd "$VERIFY_DIR"
  "$OUTFILE" --appimage-extract >/dev/null
)
readonly VERIFY_APPDIR="$VERIFY_DIR/squashfs-root"
[[ -x "$VERIFY_APPDIR/AppRun" ]] || die "最终 AppImage 缺少 AppRun。"
[[ -f "$VERIFY_APPDIR/joplin.desktop" ]] || die "最终 AppImage 缺少 joplin.desktop。"
[[ -f "$VERIFY_APPDIR/joplin.png" ]] || die "最终 AppImage 缺少 joplin.png。"
[[ -x "$VERIFY_APPDIR/bin/joplin" ]] || die "最终 AppImage 缺少 Joplin 主程序。"
[[ -f "$VERIFY_APPDIR/bin/resources/app.asar" ]] || die "最终 AppImage 缺少 resources/app.asar。"

for node_relative_path in "${source_node_relative_paths[@]}"; do
  node_module="$VERIFY_APPDIR/bin/$node_relative_path"
  [[ -f "$node_module" ]] || die "最终 AppImage 缺少 Node 原生模块：$node_relative_path"
  readelf -h "$node_module" >/dev/null 2>&1 || \
    die "最终 AppImage 中的 Node 模块不是 ELF：$node_relative_path"
done

# 使用隔离 HOME/XDG 目录做 Xvfb 冒烟测试；--no-sandbox 仅用于 root CI runner，不写入最终启动入口。
mkdir -p \
  "$SMOKE_HOME/config" \
  "$SMOKE_HOME/cache" \
  "$SMOKE_HOME/data" \
  "$SMOKE_RUNTIME"
chmod 0700 "$SMOKE_RUNTIME"
set +e
HOME="$SMOKE_HOME" \
XDG_CONFIG_HOME="$SMOKE_HOME/config" \
XDG_CACHE_HOME="$SMOKE_HOME/cache" \
XDG_DATA_HOME="$SMOKE_HOME/data" \
XDG_RUNTIME_DIR="$SMOKE_RUNTIME" \
APPIMAGE_EXTRACT_AND_RUN=1 \
timeout 30s xvfb-run -a \
  "$OUTFILE" \
  --no-sandbox \
  --disable-gpu \
  >"$SMOKE_LOG" 2>&1
smoke_rc=$?
set -e

cat "$SMOKE_LOG"
printf 'Joplin smoke test exit code: %s\n' "$smoke_rc"
if grep -Eqi \
  'error while loading shared libraries|cannot open shared object file|invalid ELF header|wrong ELF class|Exec format error|Invalid layout component:|Trace/breakpoint trap|Segmentation fault' \
  "$SMOKE_LOG"; then
  die "Joplin 冒烟测试检测到致命运行错误。"
fi
if grep -Fq \
  'Fontconfig warning: We will not regenerate the cache because some cache files were generated by a newer version' \
  "$SMOKE_LOG"; then
  die "Joplin 冒烟测试检测到 Fontconfig cache 版本不兼容警告。"
fi
if [[ "$smoke_rc" -ne 0 && "$smoke_rc" -ne 124 ]]; then
  die "Joplin 在 Xvfb 冒烟测试中异常退出：$smoke_rc"
fi

sha256sum "$OUTFILE"
log "构建完成：$OUTFILE"
