#!/usr/bin/env bash
# 从 Folo 官方 Linux x64 AppImage 提取 Electron 程序，再用 quick-sharun 重新封装。
# 上游 AppImage 使用 @pengx17/electron-forge-maker-appimage；这里保留官方应用资源，
# 重点补齐 PulseAudio / ALSA / PipeWire 运行库，避免 Linux 上音频运行时依赖宿主环境。
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
cd "$SCRIPT_DIR"

log() {
  printf '[Folo] %s\n' "$*"
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

HOST_ARCH="$(uname -m)"
readonly HOST_ARCH
[[ "$HOST_ARCH" == x86_64 ]] || die "当前仅支持 x86_64。"
command -v yay >/dev/null 2>&1 || die "构建环境缺少命令：yay"

readonly RELEASES_API="https://api.github.com/repos/RSSNext/Folo/releases?per_page=100"
readonly SOURCE_DIR="$SCRIPT_DIR/source"
readonly RELEASES_JSON="$SOURCE_DIR/releases.json"
readonly OFFICIAL_APPIMAGE="$SOURCE_DIR/Folo-official.AppImage"
readonly EXTRACT_DIR="$SOURCE_DIR/extracted"
readonly EXTRACT_ROOT="$EXTRACT_DIR/squashfs-root"
readonly APPDIR="$SCRIPT_DIR/AppDir"
readonly APP_ROOT="$APPDIR/bin"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly OUTFILE="$DIST_DIR/folo.AppImage"
readonly VERIFY_DIR="$SCRIPT_DIR/verify"
readonly BUILD_DESKTOP="$SCRIPT_DIR/Folo.desktop"
readonly BUILD_ICON="$SCRIPT_DIR/folo.png"
readonly SMOKE_HOME="$SCRIPT_DIR/smoke-home"
readonly SMOKE_RUNTIME="$SCRIPT_DIR/smoke-runtime"
readonly SMOKE_LOG="$SCRIPT_DIR/folo-smoke.log"

# 每次只清理 Folo 自己的构建目录、临时元数据和旧产物。
rm -rf \
  "$SOURCE_DIR" \
  "$APPDIR" \
  "$DIST_DIR" \
  "$VERIFY_DIR" \
  "$SMOKE_HOME" \
  "$SMOKE_RUNTIME"
rm -f "$BUILD_DESKTOP" "$BUILD_ICON" "$SMOKE_LOG"
mkdir -p "$SOURCE_DIR" "$EXTRACT_DIR" "$APP_ROOT" "$DIST_DIR"

# 安装 Electron 构建审计、桌面集成、Xvfb 冒烟测试以及音频/图形运行时依赖。
yay -S --noconfirm --needed \
  base-devel binutils coreutils curl file findutils gawk grep inetutils patchelf sed \
  appstream-glib desktop-file-utils util-linux zsync \
  xorg-server xorg-server-common xorg-server-xvfb \
  nss nspr gtk3 at-spi2-core cups dbus glib2 pango cairo expat fontconfig freetype2 \
  libx11 libxext libxi libxtst libxss libxrandr libxcomposite libxdamage libxfixes \
  libxkbcommon libxkbfile libdrm mesa libglvnd libva libvdpau \
  alsa-lib libpulse pipewire pipewire-audio \
  libnotify libsecret shared-mime-info xdg-utils hicolor-icon-theme adwaita-icon-theme \
  ibus noto-fonts-cjk python

for command_name in \
  chmod curl desktop-file-validate file find grep hostname install ldd quick-sharun readelf readlink \
  sed sha256sum sort stat timeout xvfb-run python3; do
  command -v "$command_name" >/dev/null 2>&1 || \
    die "构建环境缺少命令：$command_name"
done

log "解析 Folo 最新稳定 Desktop Linux x64 Release"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "$RELEASES_API" \
  -o "$RELEASES_JSON"
[[ -s "$RELEASES_JSON" ]] || die "Folo Releases API 返回为空。"

mapfile -t release_meta < <(
  python3 - "$RELEASES_JSON" <<'PY'
import json
import re
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    releases = json.load(fh)

pattern = re.compile(r"^Folo-(?P<version>[0-9]+(?:\.[0-9]+)+)-linux-x64\.AppImage$")
for release in releases:
    if release.get("draft") or release.get("prerelease"):
        continue
    tag = release.get("tag_name", "")
    if not re.fullmatch(r"desktop/v[0-9]+(?:\.[0-9]+)+", tag):
        continue
    for asset in release.get("assets", []):
        name = asset.get("name", "")
        match = pattern.fullmatch(name)
        if not match:
            continue
        digest = asset.get("digest") or ""
        print(tag)
        print(match.group("version"))
        print(asset.get("browser_download_url", ""))
        print(digest)
        raise SystemExit(0)

raise SystemExit("没有找到稳定的 Folo Linux x64 AppImage Release。")
PY
)
[[ ${#release_meta[@]} -eq 4 ]] || die "无法完整解析 Folo Release 元数据。"
readonly RELEASE_TAG="${release_meta[0]}"
readonly VERSION="${release_meta[1]}"
readonly APPIMAGE_URL="${release_meta[2]}"
readonly APPIMAGE_DIGEST="${release_meta[3]}"
[[ "$RELEASE_TAG" == "desktop/v$VERSION" ]] || \
  die "Release tag 与 AppImage 版本不一致：$RELEASE_TAG / $VERSION"
[[ "$APPIMAGE_URL" == https://github.com/RSSNext/Folo/releases/download/*/Folo-*-linux-x64.AppImage ]] || \
  die "解析出的 AppImage URL 不符合预期：$APPIMAGE_URL"
printf 'Folo release: %s\nFolo AppImage: %s\n' "$RELEASE_TAG" "$APPIMAGE_URL"

log "下载 Folo 官方 AppImage"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  "$APPIMAGE_URL" \
  -o "$OFFICIAL_APPIMAGE"
[[ -s "$OFFICIAL_APPIMAGE" ]] || die "官方下载文件为空。"
chmod 0755 "$OFFICIAL_APPIMAGE"
file "$OFFICIAL_APPIMAGE" | grep -q 'ELF 64-bit' || \
  die "官方下载文件不是 64 位 AppImage ELF。"

if [[ "$APPIMAGE_DIGEST" == sha256:* ]]; then
  expected_sha256="${APPIMAGE_DIGEST#sha256:}"
  actual_sha256="$(sha256sum "$OFFICIAL_APPIMAGE" | awk '{print $1}')"
  [[ "$actual_sha256" == "$expected_sha256" ]] || \
    die "官方 AppImage SHA-256 校验失败。"
  printf 'Folo SHA-256: %s\n' "$actual_sha256"
else
  log "GitHub Release 未提供 SHA-256 digest，仅记录本地摘要"
  sha256sum "$OFFICIAL_APPIMAGE"
fi

log "提取官方 AppImage"
(
  cd "$EXTRACT_DIR"
  "$OFFICIAL_APPIMAGE" --appimage-extract >/dev/null
)
[[ -d "$EXTRACT_ROOT" ]] || die "官方 AppImage 提取失败。"

# 官方 Electron AppImage 中 app.asar 所在目录就是需要保留的完整应用运行目录。
mapfile -d '' asar_candidates < <(
  find "$EXTRACT_ROOT" -type f -path '*/resources/app.asar' -print0
)
[[ ${#asar_candidates[@]} -eq 1 ]] || \
  die "官方 AppImage 中应且只能找到一个 resources/app.asar，实际为 ${#asar_candidates[@]}。"
readonly SOURCE_ASAR="${asar_candidates[0]}"
readonly SOURCE_APP_ROOT="$(dirname -- "$(dirname -- "$SOURCE_ASAR")")"

# 从官方 AppImage 中定位 desktop 文件，并从 Exec 字段解析真正的 Electron 主程序名。
mapfile -d '' desktop_candidates < <(
  find "$EXTRACT_ROOT" -type f -iname 'Folo.desktop' -print0
)
[[ ${#desktop_candidates[@]} -ge 1 ]] || die "官方 AppImage 中未找到 Folo.desktop。"
SOURCE_DESKTOP="${desktop_candidates[0]}"
for desktop_candidate in "${desktop_candidates[@]}"; do
  if [[ "$desktop_candidate" == "$EXTRACT_ROOT/Folo.desktop" ]]; then
    SOURCE_DESKTOP="$desktop_candidate"
    break
  fi
done
readonly SOURCE_DESKTOP

MAIN_EXEC="$(
  python3 - "$SOURCE_DESKTOP" <<'PY'
import shlex
import sys

exec_line = ""
with open(sys.argv[1], "r", encoding="utf-8") as fh:
    for raw in fh:
        if raw.startswith("Exec="):
            exec_line = raw[len("Exec="):].strip()
            break

if not exec_line:
    raise SystemExit("desktop 缺少 Exec 字段")
parts = shlex.split(exec_line)
if not parts:
    raise SystemExit("desktop Exec 字段为空")
print(parts[0].rsplit("/", 1)[-1])
PY
)"
[[ "$MAIN_EXEC" =~ ^[A-Za-z0-9._+-]+$ ]] || die "无法解析安全的主程序名：$MAIN_EXEC"

SOURCE_MAIN="$SOURCE_APP_ROOT/$MAIN_EXEC"
if [[ ! -x "$SOURCE_MAIN" ]]; then
  mapfile -d '' main_candidates < <(
    find "$SOURCE_APP_ROOT" -maxdepth 1 -type f -perm -0100 -iname 'folo' -print0
  )
  [[ ${#main_candidates[@]} -eq 1 ]] || \
    die "官方运行目录中未找到唯一的 Folo 主程序。"
  SOURCE_MAIN="${main_candidates[0]}"
  MAIN_EXEC="$(basename -- "$SOURCE_MAIN")"
fi
readonly SOURCE_MAIN
readonly MAIN_EXEC
file "$SOURCE_MAIN" | grep -q 'ELF 64-bit' || die "Folo 主程序不是 64 位 ELF。"

# 只使用官方 AppImage 自带图标，优先系统图标目录中的 Folo PNG，并取文件体积最大的版本。
mapfile -d '' icon_candidates < <(
  find "$EXTRACT_ROOT/usr/share/icons" -type f -iname 'Folo.png' -print0 2>/dev/null || true
)
if [[ ${#icon_candidates[@]} -eq 0 ]]; then
  mapfile -d '' icon_candidates < <(
    find "$EXTRACT_ROOT" -type f -iname 'Folo.png' -print0
  )
fi
[[ ${#icon_candidates[@]} -gt 0 ]] || die "官方 AppImage 中未找到 Folo PNG 图标。"

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
file "$SOURCE_ICON" | grep -q 'PNG image data' || die "找到的 Folo 图标不是 PNG。"

printf 'Folo runtime: %s\nFolo main: %s\nFolo desktop: %s\nFolo icon: %s\n' \
  "${SOURCE_APP_ROOT#"$EXTRACT_ROOT"/}" \
  "$MAIN_EXEC" \
  "${SOURCE_DESKTOP#"$EXTRACT_ROOT"/}" \
  "${SOURCE_ICON#"$EXTRACT_ROOT"/}"

# v1.12.0 的 resources/app.asar 位于 AppImage 根目录；该目录同时混有 maker 的 AppRun、desktop、
# 图标和 usr/lib 兼容层。兼容层中的旧 GTK2/GConf/AppIndicator 库不是 Electron 运行目录本身，
# 不能作为应用 ELF 一起交给 quick-sharun 审计。只在这种根目录布局下剥离 AppImage 包装层。
if [[ "$SOURCE_APP_ROOT" == "$EXTRACT_ROOT" ]]; then
  mapfile -d '' runtime_entries < <(
    find "$SOURCE_APP_ROOT" -mindepth 1 -maxdepth 1 -print0
  )
  [[ ${#runtime_entries[@]} -gt 0 ]] || die "官方 Folo 根目录为空。"
  for runtime_entry in "${runtime_entries[@]}"; do
    runtime_name="$(basename -- "$runtime_entry")"
    case "$runtime_name" in
      AppRun|*.desktop|.DirIcon|usr)
        continue
        ;;
    esac
    cp -a "$runtime_entry" "$APP_ROOT/"
  done
  [[ ! -e "$APP_ROOT/usr" ]] || die "AppImage 包装层 usr/ 被错误复制到 Electron 运行目录。"
else
  # 如果上游以后恢复独立 Electron 目录，则原样保留该目录，避免猜测未来布局。
  cp -a "$SOURCE_APP_ROOT"/. "$APP_ROOT"/
fi
[[ -x "$APP_ROOT/$MAIN_EXEC" ]] || die "复制后缺少 Folo 主程序。"
[[ -f "$APP_ROOT/resources/app.asar" ]] || die "复制后缺少 app.asar。"

# Node 原生模块由 Electron 进程 dlopen，不应因上游执行位被 quick-sharun 当成独立入口包装。
find "$APP_ROOT" -type f -name '*.node' -exec chmod 0644 {} +
mapfile -d '' source_node_modules < <(
  find "$APP_ROOT" -type f -name '*.node' -print0
)
source_node_relative_paths=()
for node_module in "${source_node_modules[@]}"; do
  readelf -h "$node_module" >/dev/null 2>&1 || \
    die "官方 Folo Node 模块不是 ELF：$node_module"
  source_node_relative_paths+=("${node_module#"$APP_ROOT"/}")
done
printf 'Folo Node native modules: %s\n' "${#source_node_relative_paths[@]}"

# 使用官方 desktop 和图标生成新的 AppImage 桌面集成文件。
install -Dm0644 "$SOURCE_DESKTOP" "$BUILD_DESKTOP"
install -Dm0644 "$SOURCE_ICON" "$BUILD_ICON"
[[ "$(grep -c '^Exec=' "$BUILD_DESKTOP")" -eq 1 ]] || die "官方 desktop 的 Exec 字段数量异常。"
[[ "$(grep -c '^Icon=' "$BUILD_DESKTOP")" -eq 1 ]] || die "官方 desktop 的 Icon 字段数量异常。"
sed -i \
  -e "s|^Exec=.*|Exec=$MAIN_EXEC --no-sandbox --disable-setuid-sandbox %U|" \
  -e 's|^Icon=.*|Icon=folo|' \
  "$BUILD_DESKTOP"
if grep -q '^StartupWMClass=' "$BUILD_DESKTOP"; then
  sed -i 's|^StartupWMClass=.*|StartupWMClass=Folo|' "$BUILD_DESKTOP"
else
  printf 'StartupWMClass=Folo\n' >> "$BUILD_DESKTOP"
fi
if grep -q '^X-AppImage-Version=' "$BUILD_DESKTOP"; then
  sed -i "s|^X-AppImage-Version=.*|X-AppImage-Version=$VERSION|" "$BUILD_DESKTOP"
else
  printf 'X-AppImage-Version=%s\n' "$VERSION" >> "$BUILD_DESKTOP"
fi
desktop-file-validate "$BUILD_DESKTOP"

# 官方 desktop 本身就使用 --no-sandbox/--disable-setuid-sandbox；直接启动 AppImage 时保持相同行为。
cat > "$APPDIR/AppRun.sh" <<APPRUN_EOF
#!/bin/sh
set -e
export SHARUN_EXTRA_LIBRARY_PATH="\$APPDIR/bin\${SHARUN_EXTRA_LIBRARY_PATH:+:\$SHARUN_EXTRA_LIBRARY_PATH}"
export SHARUN_WORKING_DIR="\$APPDIR/bin"
cd "\$APPDIR/bin"
exec "\$APPDIR/bin/$MAIN_EXEC" --no-sandbox --disable-setuid-sandbox "\$@"
APPRUN_EOF
chmod 0755 "$APPDIR/AppRun.sh"
bash -n "$APPDIR/AppRun.sh"

printf '%s\n' "$VERSION" > ~/version

export ARCH=x86_64
export VERSION
export APPNAME=Folo
export MAIN_BIN="$MAIN_EXEC"
export STARTUPWMCLASS=Folo
export ICON="$BUILD_ICON"
export DESKTOP="$BUILD_DESKTOP"
export OUTPATH="$DIST_DIR"
export OUTNAME=folo.AppImage
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export DEPLOY_PIPEWIRE=1
export STRACE_MODE=0
export NO_STRIP=1

# 扫描官方 Electron 运行目录中的全部 ELF，避免只处理主程序而漏掉 Chromium/Electron 子进程与私有库。
elf_targets=()
while IFS= read -r -d '' target; do
  if readelf -h "$target" >/dev/null 2>&1; then
    elf_targets+=("$target")
  fi
done < <(find "$APP_ROOT" -type f -print0)
[[ ${#elf_targets[@]} -gt 0 ]] || die "官方 Folo 运行目录中未找到 ELF 文件。"
printf 'Folo ELF files: %s\n' "${#elf_targets[@]}"

# 在 quick-sharun 前审计所有官方 ELF 的直接依赖；同目录私有库通过完整运行目录解析。
mapfile -t app_library_dirs < <(
  find "$APP_ROOT" -type f -printf '%h\n' | sort -u
)
[[ ${#app_library_dirs[@]} -gt 0 ]] || die "官方 Folo 运行目录为空。"
BUILD_LIBRARY_PATH="$(IFS=:; printf '%s' "${app_library_dirs[*]}")"
BUILD_LIBRARY_PATH="$BUILD_LIBRARY_PATH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

missing_dependencies=0
for target in "${elf_targets[@]}"; do
  target_library_path="$(dirname -- "$target"):$BUILD_LIBRARY_PATH"
  target_dependencies="$(LD_LIBRARY_PATH="$target_library_path" ldd "$target" 2>&1 || true)"
  if grep -Fq 'not found' <<< "$target_dependencies"; then
    printf '缺失依赖文件：%s\n%s\n' "$target" "$target_dependencies" >&2
    missing_dependencies=1
  fi
done
[[ "$missing_dependencies" -eq 0 ]] || die "官方 Folo 组件仍存在缺失动态库。"

# 明确部署 Linux 音频客户端库；DEPLOY_PIPEWIRE=1 同时负责 PipeWire/SPA 运行模块。
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
shopt -u nullglob
[[ ${#pulse_common_targets[@]} -gt 0 ]] || die "构建环境缺少 libpulsecommon。"

LD_LIBRARY_PATH="$BUILD_LIBRARY_PATH" quick-sharun \
  "${elf_targets[@]}" \
  "${audio_targets[@]}" \
  "${pulse_common_targets[@]}" \
  /usr/bin/hostname \
  /usr/lib/libnss* \
  /usr/lib/libsoftokn3.so \
  /usr/lib/libfreeblpriv3.so \
  /usr/lib/pkcs11/* \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so

quick-sharun --make-appimage
[[ -s "$OUTFILE" ]] || die "未生成预期文件：$OUTFILE"
chmod 0755 "$OUTFILE"

# 解包最终 AppImage，确认应用资源和音频修复库确实进入最终产物。
mkdir -p "$VERIFY_DIR"
(
  cd "$VERIFY_DIR"
  "$OUTFILE" --appimage-extract >/dev/null
)
readonly VERIFY_APPDIR="$VERIFY_DIR/squashfs-root"
[[ -x "$VERIFY_APPDIR/AppRun" ]] || die "最终 AppImage 缺少 AppRun。"
[[ -f "$VERIFY_APPDIR/Folo.desktop" ]] || die "最终 AppImage 缺少 Folo.desktop。"
[[ -f "$VERIFY_APPDIR/folo.png" ]] || die "最终 AppImage 缺少 folo.png。"
find -H "$VERIFY_APPDIR" -type f -path '*/resources/app.asar' -print -quit | grep -q . || \
  die "最终 AppImage 缺少 resources/app.asar。"

verify_bundled_library() {
  local library_pattern="$1"
  local library_label="$2"
  local library_path
  library_path="$(
    # quick-sharun 当前 DwarFS uruntime 会把 squashfs-root 提取为指向 AppDir 的入口链接。
    find -H "$VERIFY_APPDIR" \
      -type f \
      -name "$library_pattern" \
      -print \
      -quit
  )"
  [[ -n "$library_path" ]] || die "最终 AppImage 缺少 $library_label 的实际库文件。"
}

verify_bundled_library 'libasound.so.*' libasound.so.2
verify_bundled_library 'libpulse.so.*' libpulse.so.0
verify_bundled_library 'libpulse-simple.so.*' libpulse-simple.so.0
verify_bundled_library 'libpipewire-0.3.so.*' libpipewire-0.3.so.0

# 如果上游运行目录包含 Node 原生模块，最终 AppImage 必须按原相对路径保留，不能被替换成 sharun 入口。
for node_relative_path in "${source_node_relative_paths[@]}"; do
  node_module="$VERIFY_APPDIR/bin/$node_relative_path"
  [[ -f "$node_module" ]] || die "最终 AppImage 缺少 Node 原生模块：$node_relative_path"
  readelf -h "$node_module" >/dev/null 2>&1 || \
    die "最终 AppImage 中的 Node 模块不是 ELF：$node_relative_path"
  [[ ! "$node_module" -ef "$VERIFY_APPDIR/AppRun" ]] || \
    die "最终 AppImage 中的 Node 模块被错误替换成 sharun：$node_relative_path"
done

# Xvfb 只能验证 GUI 启动和动态库完整性，不能模拟真实声卡；音频库已在上一步做最终产物检查。
mkdir -p "$SMOKE_HOME" "$SMOKE_RUNTIME"
chmod 0700 "$SMOKE_RUNTIME"
set +e
HOME="$SMOKE_HOME" \
XDG_RUNTIME_DIR="$SMOKE_RUNTIME" \
APPIMAGE_EXTRACT_AND_RUN=1 \
timeout 25s xvfb-run -a \
  "$OUTFILE" \
  --disable-gpu \
  --user-data-dir="$SMOKE_HOME/profile" \
  >"$SMOKE_LOG" 2>&1
smoke_rc=$?
set -e

cat "$SMOKE_LOG"
printf 'Folo smoke test exit code: %s\n' "$smoke_rc"
if grep -Eqi \
  'error while loading shared libraries|cannot open shared object file|invalid ELF header|wrong ELF class|Exec format error|FATAL:|Trace/breakpoint trap|Segmentation fault' \
  "$SMOKE_LOG"; then
  die "Folo 冒烟测试检测到致命运行错误。"
fi
if [[ "$smoke_rc" -ne 0 && "$smoke_rc" -ne 124 ]]; then
  die "Folo 在 Xvfb 冒烟测试中异常退出：$smoke_rc"
fi

sha256sum "$OUTFILE"
log "构建完成：$OUTFILE"
