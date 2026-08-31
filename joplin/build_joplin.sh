#!/usr/bin/env bash
# 从 Joplin 官方 GitHub Release 中选择版本号最高的已发布 Linux x64 DEB，
# 在 Ubuntu 22.04 上使用 linuxdeploy 重新封装为 AppImage。
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

if command -v sudo >/dev/null 2>&1; then
  APT=(sudo apt-get)
else
  APT=(apt-get)
fi

log "安装 Ubuntu/linuxdeploy 构建与 Electron 运行依赖"
"${APT[@]}" update
DEBIAN_FRONTEND=noninteractive "${APT[@]}" install -y --no-install-recommends \
  binutils ca-certificates coreutils curl desktop-file-utils dpkg file findutils gawk grep python3 sed \
  xz-utils xvfb xauth \
  libasound2 libatk-bridge2.0-0 libatk1.0-0 libcups2 libdbus-1-3 libdrm2 libgbm1 \
  libglib2.0-0 libgtk-3-0 libnspr4 libnss3 libnotify4 libsecret-1-0 \
  libx11-6 libxcb1 libxcomposite1 libxdamage1 libxext6 libxfixes3 libxkbcommon0 \
  libxrandr2 libxss1 libxtst6 libgl1 libva2 libvdpau1 libpulse0 ibus-gtk3

for command_name in \
  awk chmod curl desktop-file-validate dpkg-deb file find grep ldd python3 readelf sed sha256sum sort \
  timeout xvfb-run; do
  command -v "$command_name" >/dev/null 2>&1 || die "构建环境缺少命令：$command_name"
done

readonly RELEASES_API='https://api.github.com/repos/laurent22/joplin/releases?per_page=30'
readonly SOURCE_DIR="$SCRIPT_DIR/source"
readonly RELEASES_JSON="$SOURCE_DIR/releases.json"
readonly DEB_FILE="$SOURCE_DIR/joplin.deb"
readonly PACKAGE_ROOT="$SOURCE_DIR/package"
readonly LINUXDEPLOY="$SOURCE_DIR/linuxdeploy-x86_64.AppImage"
readonly CUSTOM_APPRUN="$SOURCE_DIR/AppRun"
readonly APPDIR="$SCRIPT_DIR/AppDir"
readonly APP_ROOT="$APPDIR/opt/Joplin"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly OUTFILE="$DIST_DIR/joplin.AppImage"
readonly VERIFY_DIR="$SCRIPT_DIR/verify"
readonly BUILD_DESKTOP="$SCRIPT_DIR/joplin.desktop"
readonly BUILD_ICON="$SCRIPT_DIR/joplin.png"
readonly SMOKE_HOME="$SCRIPT_DIR/smoke-home"
readonly SMOKE_RUNTIME="$SCRIPT_DIR/smoke-runtime"
readonly SMOKE_LOG="$SCRIPT_DIR/joplin-smoke.log"

# 只清理 Joplin 自己的构建目录、测试目录和旧产物。
rm -rf \
  "$SOURCE_DIR" \
  "$APPDIR" \
  "$DIST_DIR" \
  "$VERIFY_DIR" \
  "$SMOKE_HOME" \
  "$SMOKE_RUNTIME"
rm -f "$BUILD_DESKTOP" "$BUILD_ICON" "$SMOKE_LOG"
mkdir -p "$SOURCE_DIR" "$PACKAGE_ROOT" "$APP_ROOT" "$DIST_DIR"

log "读取 Joplin 官方 Release 元数据"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  -H 'Accept: application/vnd.github+json' \
  "$RELEASES_API" \
  -o "$RELEASES_JSON"
[[ -s "$RELEASES_JSON" ]] || die "Joplin Release 元数据为空。"

# 选择版本号最高的已发布（非 draft）Linux x64 DEB，而不是只取 releases/latest。
# 这样不会把已经被较新 Joplin 迁移过的用户配置再次交给较旧稳定版读取。
mapfile -t RELEASE_META < <(
  python3 - "$RELEASES_JSON" <<'PY'
import json
import re
import sys
from urllib.parse import urlparse

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    releases = json.load(fh)

candidates = []
for release in releases:
    if release.get("draft"):
        continue

    tag = str(release.get("tag_name", ""))
    match = re.fullmatch(r"v?([0-9]+(?:\.[0-9]+)+)", tag)
    if not match:
        continue

    version = match.group(1)
    version_key = tuple(int(part) for part in version.split("."))
    asset_name = f"Joplin-{version}.deb"
    assets = [asset for asset in release.get("assets", []) if asset.get("name") == asset_name]
    if len(assets) != 1:
        continue

    asset = assets[0]
    url = str(asset.get("browser_download_url", ""))
    digest = str(asset.get("digest", ""))
    parsed = urlparse(url)
    expected_path = f"/laurent22/joplin/releases/download/{tag}/{asset_name}"
    if parsed.scheme != "https" or parsed.netloc != "github.com" or parsed.path != expected_path:
        continue
    if not re.fullmatch(r"sha256:[0-9a-fA-F]{64}", digest):
        continue

    release_kind = "prerelease" if release.get("prerelease") else "stable"
    candidates.append((version_key, version, url, digest.split(":", 1)[1].lower(), release_kind))

if not candidates:
    raise SystemExit("no valid published Joplin Linux x64 DEB release found")

_, version, url, digest, release_kind = max(candidates, key=lambda item: item[0])
print(version)
print(url)
print(digest)
print(release_kind)
PY
)
[[ ${#RELEASE_META[@]} -eq 4 ]] || die "无法完整解析 Joplin 已发布版本元数据。"

readonly VERSION="${RELEASE_META[0]}"
readonly DEB_URL="${RELEASE_META[1]}"
readonly EXPECTED_SHA256="${RELEASE_META[2]}"
readonly RELEASE_KIND="${RELEASE_META[3]}"

printf 'Joplin version: %s (%s)\nJoplin DEB: %s\n' "$VERSION" "$RELEASE_KIND" "$DEB_URL"

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
dpkg-deb -x "$DEB_FILE" "$PACKAGE_ROOT"

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
[[ "$(basename -- "$SOURCE_MAIN")" == joplin ]] || die "Joplin 官方主程序文件名不是 joplin。"
file "$SOURCE_MAIN" | grep -q 'ELF 64-bit' || die "Joplin 主程序不是 64 位 ELF。"

mapfile -d '' desktop_candidates < <(
  find "$PACKAGE_ROOT/usr/share/applications" -maxdepth 1 -type f -iname '*joplin*.desktop' -print0 2>/dev/null
)
[[ ${#desktop_candidates[@]} -eq 1 ]] || die "Joplin 官方包中无法唯一定位 desktop 文件。"
readonly SOURCE_DESKTOP="${desktop_candidates[0]}"

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

# linuxdeploy 只接受固定的 hicolor 图标尺寸；Joplin 官方包同时包含 1024x1024，
# 因此不能按文件体积盲选最大图标。读取 PNG IHDR，选择 linuxdeploy 支持的最大正方形尺寸。
mapfile -d '' selected_icon < <(
  python3 - "${icon_candidates[@]}" <<'PY'
import struct
import sys

supported = {8, 16, 20, 22, 24, 28, 32, 36, 42, 48, 64, 72, 96, 128, 160, 192, 256, 384, 480, 512}
best = None

for path in sys.argv[1:]:
    try:
        with open(path, "rb") as fh:
            header = fh.read(24)
    except OSError:
        continue

    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        continue

    width, height = struct.unpack(">II", header[16:24])
    if width != height or width not in supported:
        continue

    candidate = (width, path)
    if best is None or candidate[0] > best[0]:
        best = candidate

if best is None:
    raise SystemExit("no linuxdeploy-compatible square PNG icon found")

size, path = best
sys.stdout.buffer.write(path.encode("utf-8") + b"\0" + str(size).encode("ascii") + b"\0")
PY
)
[[ ${#selected_icon[@]} -eq 2 ]] || die "Joplin 官方包中没有 linuxdeploy 支持尺寸的 PNG 图标。"
readonly SOURCE_ICON="${selected_icon[0]}"
readonly SOURCE_ICON_SIZE="${selected_icon[1]}"
file "$SOURCE_ICON" | grep -q 'PNG image data' || die "Joplin 官方图标不是 PNG。"

printf 'Joplin runtime: %s\nJoplin desktop: %s\nJoplin icon: %s (%sx%s)\n' \
  "${SOURCE_APP_ROOT#"$PACKAGE_ROOT"/}" \
  "${SOURCE_DESKTOP#"$PACKAGE_ROOT"/}" \
  "${SOURCE_ICON#"$PACKAGE_ROOT"/}" \
  "$SOURCE_ICON_SIZE" \
  "$SOURCE_ICON_SIZE"

log "复制 Joplin 官方 Electron 运行目录"
cp -a "$SOURCE_APP_ROOT"/. "$APP_ROOT"/
[[ -x "$APP_ROOT/joplin" ]] || die "复制后缺少 Joplin 主程序。"
[[ -f "$APP_ROOT/resources/app.asar" ]] || die "复制后缺少 Joplin resources/app.asar。"

# 最终 AppImage 不引入有效 setuid；保持 Electron 用户命名空间沙箱的普通文件权限。
if [[ -e "$APP_ROOT/chrome-sandbox" ]]; then
  chmod 0755 "$APP_ROOT/chrome-sandbox"
fi

# 保留官方 Node 原生模块及其相对路径，不改 app.asar。
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

readonly APP_ICON_DIR="$APPDIR/usr/share/icons/hicolor/${SOURCE_ICON_SIZE}x${SOURCE_ICON_SIZE}/apps"
mkdir -p \
  "$APPDIR/usr/share/applications" \
  "$APP_ICON_DIR"
cp -a "$BUILD_DESKTOP" "$APPDIR/usr/share/applications/joplin.desktop"
cp -a "$BUILD_ICON" "$APP_ICON_DIR/joplin.png"
readonly APP_DESKTOP="$APPDIR/usr/share/applications/joplin.desktop"
readonly APP_ICON="$APP_ICON_DIR/joplin.png"

# 构建前检查官方 Electron 目录中的全部 ELF 在 Ubuntu 22.04 上没有缺失依赖。
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

log "下载 linuxdeploy"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage \
  -o "$LINUXDEPLOY"
[[ -s "$LINUXDEPLOY" ]] || die "linuxdeploy 下载为空。"
chmod 0755 "$LINUXDEPLOY"

export ARCH=x86_64
export APPIMAGE_EXTRACT_AND_RUN=1
export LDAI_OUTPUT="$OUTFILE"

# AppDir 内保留一个桌面入口 wrapper，并给 linuxdeploy 提供显式 AppRun。
# 这两个脚本都只定位 AppImage 内部 /opt/Joplin，不改用户 HOME/XDG。
mkdir -p "$APPDIR/usr/bin"
cat > "$APPDIR/usr/bin/joplin" <<'WRAPPER_EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

HERE="$(dirname "$(readlink -f "$0")")"
ROOT="$(readlink -f "$HERE/../..")"

cd "$ROOT/opt/Joplin"
exec "$ROOT/opt/Joplin/joplin" "$@"
WRAPPER_EOF
chmod 0755 "$APPDIR/usr/bin/joplin"
bash -n "$APPDIR/usr/bin/joplin"

cat > "$CUSTOM_APPRUN" <<'APPRUN_EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(dirname "$(readlink -f "$0")")"
cd "$ROOT/opt/Joplin"
exec "$ROOT/opt/Joplin/joplin" "$@"
APPRUN_EOF
chmod 0755 "$CUSTOM_APPRUN"
bash -n "$CUSTOM_APPRUN"

# linuxdeploy 官方支持 --deploy-deps-only：对 AppDir 中已有 ELF 只部署依赖，
# 不把 Joplin 官方主程序或 .node 文件再复制到 usr/bin/usr/lib。
linuxdeploy_args=(
  --appdir "$APPDIR"
  --desktop-file "$APP_DESKTOP"
  --icon-file "$APP_ICON"
  --custom-apprun "$CUSTOM_APPRUN"
)
for target in "${elf_targets[@]}"; do
  linuxdeploy_args+=(--deploy-deps-only "$target")
done

log "使用 linuxdeploy 部署 Joplin 全部 ELF 的运行依赖并生成 AppImage"
"$LINUXDEPLOY" "${linuxdeploy_args[@]}" --output appimage
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
[[ -x "$VERIFY_APPDIR/usr/bin/joplin" ]] || die "最终 AppImage 缺少 Joplin 启动 wrapper。"
[[ -x "$VERIFY_APPDIR/opt/Joplin/joplin" ]] || die "最终 AppImage 缺少 Joplin 官方主程序。"
[[ -f "$VERIFY_APPDIR/opt/Joplin/resources/app.asar" ]] || die "最终 AppImage 缺少 resources/app.asar。"

for node_relative_path in "${source_node_relative_paths[@]}"; do
  node_module="$VERIFY_APPDIR/opt/Joplin/$node_relative_path"
  [[ -f "$node_module" ]] || die "最终 AppImage 缺少 Node 原生模块：$node_relative_path"
  readelf -h "$node_module" >/dev/null 2>&1 || \
    die "最终 AppImage 中的 Node 模块不是 ELF：$node_relative_path"
done

# 最终主程序必须能在 AppImage 自带 usr/lib + 官方 /opt/Joplin 运行目录下解析依赖。
final_dependencies="$(
  LD_LIBRARY_PATH="$VERIFY_APPDIR/usr/lib:$VERIFY_APPDIR/opt/Joplin" \
    ldd "$VERIFY_APPDIR/opt/Joplin/joplin" 2>&1 || true
)"
printf '%s\n' "$final_dependencies"
if grep -Eq 'not found|version .* not found' <<< "$final_dependencies"; then
  die "最终 AppImage 的 Joplin 主程序仍存在缺失或 ABI 不兼容动态库。"
fi

# 使用隔离 HOME/XDG 目录做 Xvfb 冒烟测试；--no-sandbox 只用于 root CI 测试，
# 不写入正式 AppImage 启动入口，也不接触真实用户配置。
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
if [[ "$smoke_rc" -ne 0 && "$smoke_rc" -ne 124 ]]; then
  die "Joplin 在 Xvfb 冒烟测试中异常退出：$smoke_rc"
fi

sha256sum "$OUTFILE"
log "构建完成：$OUTFILE"
