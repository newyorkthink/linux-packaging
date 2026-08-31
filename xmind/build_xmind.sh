#!/usr/bin/env bash
# 从 Xmind 官方 Linux 64-bit DEB 下载入口动态获取当前稳定版，并重新封装为 AnyLinux AppImage。
# AUR xmind 与 Flathub net.xmind.XMind 仅作为依赖、/opt/Xmind 布局和启动方式参考，不作为二进制来源。
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log() {
  printf '[Xmind] %s\n' "$*"
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

readonly DOWNLOAD_ENTRY='https://xmind.app/zen/download/linux_deb/'
readonly SOURCE_DIR="$SCRIPT_DIR/source"
readonly DEB_FILE="$SOURCE_DIR/xmind.deb"
readonly DEB_EXTRACT_DIR="$SOURCE_DIR/deb"
readonly PACKAGE_ROOT="$SOURCE_DIR/package"
readonly APPDIR="$SCRIPT_DIR/AppDir"
readonly APP_ROOT="$APPDIR/bin"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly OUTFILE="$DIST_DIR/xmind.AppImage"
readonly VERIFY_DIR="$SCRIPT_DIR/verify"
readonly BUILD_DESKTOP="$SCRIPT_DIR/xmind.desktop"
readonly SMOKE_HOME="$SCRIPT_DIR/smoke-home"
readonly SMOKE_RUNTIME="$SCRIPT_DIR/smoke-runtime"
readonly SMOKE_LOG="$SCRIPT_DIR/xmind-smoke.log"

# 每次只清理 Xmind 自己的构建目录、临时 desktop/icon 和旧产物。
rm -rf \
  "$SOURCE_DIR" \
  "$APPDIR" \
  "$DIST_DIR" \
  "$VERIFY_DIR" \
  "$SMOKE_HOME" \
  "$SMOKE_RUNTIME"
rm -f "$BUILD_DESKTOP" "$SCRIPT_DIR"/xmind-build-icon.* "$SMOKE_LOG"
mkdir -p "$SOURCE_DIR" "$DEB_EXTRACT_DIR" "$PACKAGE_ROOT" "$APP_ROOT" "$DIST_DIR"

# 安装 quick-sharun、Electron/GTK 运行库、输入法模块以及隔离 GUI 冒烟测试组件。
yay -S --noconfirm --needed \
  base-devel binutils coreutils curl file findutils gawk grep libarchive patchelf python sed tar \
  appstream-glib desktop-file-utils inetutils util-linux zsync \
  xorg-server xorg-server-common xorg-server-xvfb xorg-xauth \
  nss nspr alsa-lib at-spi2-core cups dbus glib2 gtk3 \
  libnotify libsecret libappindicator shared-mime-info xdg-utils \
  hicolor-icon-theme adwaita-icon-theme fontconfig freetype2 cairo pango gdk-pixbuf2 librsvg \
  libx11 libxext libxi libxrender libxrandr libxcomposite libxdamage libxfixes libxss libxtst \
  libxcb libxkbcommon libxkbcommon-x11 libxkbfile \
  mesa libglvnd libva libvdpau vulkan-icd-loader \
  libpulse pipewire-audio ibus

for command_name in \
  ar awk basename chmod curl dbus-run-session desktop-file-validate file find grep hostname \
  install ldd quick-sharun readelf readlink sed sha256sum sort stat tar timeout xvfb-run python3; do
  command -v "$command_name" >/dev/null 2>&1 || \
    die "构建环境缺少命令：$command_name"
done

#######################################################################
# 2. 获取 Xmind 官方 Linux DEB
#######################################################################

log "解析并下载 Xmind 官方 Linux 64-bit DEB"
EFFECTIVE_URL="$(
  curl -fL \
    --retry 5 \
    --retry-all-errors \
    --retry-delay 2 \
    --connect-timeout 20 \
    --max-time 600 \
    -w '%{url_effective}' \
    "$DOWNLOAD_ENTRY" \
    -o "$DEB_FILE"
)"
readonly EFFECTIVE_URL
[[ -s "$DEB_FILE" ]] || die "Xmind 官方 DEB 下载为空。"

mapfile -t URL_META < <(
  python3 - "$EFFECTIVE_URL" <<'PY'
import re
import sys
from urllib.parse import unquote, urlparse

url = sys.argv[1]
parsed = urlparse(url)
if parsed.scheme != "https":
    raise SystemExit(f"unexpected Xmind download scheme: {parsed.scheme!r}")
if parsed.hostname != "xmind.app" and not re.fullmatch(r"dl[0-9]+\.xmind\.app", parsed.hostname or ""):
    raise SystemExit(f"unexpected Xmind download host: {parsed.hostname!r}")

name = unquote(parsed.path.rsplit("/", 1)[-1])
match = re.fullmatch(
    r"Xmind-for-Linux-amd64bit-(?P<version>[0-9]+(?:\.[0-9]+)+)-(?P<build>[0-9]{12})\.deb",
    name,
)
if not match:
    raise SystemExit(f"unexpected Xmind DEB name: {name!r}")

print(name)
print(match.group("version"))
print(match.group("build"))
PY
)
[[ ${#URL_META[@]} -eq 3 ]] || die "无法完整解析 Xmind 官方 DEB 元数据。"
readonly DEB_NAME="${URL_META[0]}"
readonly VERSION="${URL_META[1]}"
readonly BUILD_ID="${URL_META[2]}"

printf 'Xmind version: %s\nXmind build: %s\nXmind DEB: %s\n' \
  "$VERSION" "$BUILD_ID" "$EFFECTIVE_URL"
file "$DEB_FILE" | grep -q 'Debian binary package' || \
  die "Xmind 官方下载文件不是 Debian 软件包。"
sha256sum "$DEB_FILE"

log "提取 Xmind 官方 DEB"
(
  cd "$DEB_EXTRACT_DIR"
  ar x "$DEB_FILE"
)
shopt -s nullglob
data_archives=("$DEB_EXTRACT_DIR"/data.tar.*)
shopt -u nullglob
[[ ${#data_archives[@]} -eq 1 ]] || die "Xmind DEB 中应且只能有一个 data.tar.*。"
tar -xf "${data_archives[0]}" -C "$PACKAGE_ROOT"

readonly SOURCE_APP_ROOT="$PACKAGE_ROOT/opt/Xmind"
readonly SOURCE_MAIN="$SOURCE_APP_ROOT/xmind"
[[ -d "$SOURCE_APP_ROOT" ]] || die "Xmind 官方包缺少 /opt/Xmind。"
[[ -x "$SOURCE_MAIN" ]] || die "Xmind 官方包缺少 /opt/Xmind/xmind。"
file "$SOURCE_MAIN" | grep -q 'ELF 64-bit' || die "Xmind 主程序不是 64 位 ELF。"
[[ -f "$SOURCE_APP_ROOT/resources/app.asar" ]] || die "Xmind 官方包缺少 resources/app.asar。"

#######################################################################
# 3. 组装 Xmind 官方运行目录
#######################################################################

# 优先使用官方 DEB 自带 desktop；如果上游更名，只允许在官方包内唯一定位。
mapfile -d '' desktop_candidates < <(
  find "$PACKAGE_ROOT/usr/share/applications" \
    -maxdepth 1 -type f -iname '*xmind*.desktop' -print0 2>/dev/null
)
[[ ${#desktop_candidates[@]} -eq 1 ]] || \
  die "Xmind 官方包中无法唯一定位 desktop 文件。"
readonly SOURCE_DESKTOP="${desktop_candidates[0]}"

# 只使用官方包中的品牌图标；选择体积最大的 PNG/SVG 作为 AppImage 主图标。
mapfile -d '' icon_candidates < <(
  find \
    "$PACKAGE_ROOT/usr/share/icons" \
    "$PACKAGE_ROOT/usr/share/pixmaps" \
    "$SOURCE_APP_ROOT" \
    -type f \
    \( -iname '*xmind*.png' -o -iname '*xmind*.svg' \) \
    -print0 2>/dev/null
)
[[ ${#icon_candidates[@]} -gt 0 ]] || die "Xmind 官方包中未找到 PNG/SVG 图标。"

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
  *) die "Xmind 官方图标格式不是 PNG/SVG。" ;;
esac
readonly ICON_EXT
readonly BUILD_ICON="$SCRIPT_DIR/xmind-build-icon.$ICON_EXT"

printf 'Xmind runtime: %s\nXmind desktop: %s\nXmind icon: %s\n' \
  "${SOURCE_APP_ROOT#"$PACKAGE_ROOT"/}" \
  "${SOURCE_DESKTOP#"$PACKAGE_ROOT"/}" \
  "${SOURCE_ICON#"$PACKAGE_ROOT"/}"

log "复制 Xmind 官方 Electron 运行目录"
cp -a "$SOURCE_APP_ROOT"/. "$APP_ROOT"/
[[ -x "$APP_ROOT/xmind" ]] || die "复制后缺少 Xmind 主程序。"
[[ -f "$APP_ROOT/resources/app.asar" ]] || die "复制后缺少 Xmind app.asar。"

# AppImage 内不能依赖 root-owned setuid chrome-sandbox；只修改 AppImage 内副本并显式使用 no-sandbox。
if [[ -e "$APP_ROOT/chrome-sandbox" ]]; then
  chmod 0755 "$APP_ROOT/chrome-sandbox"
fi

# Node 原生模块由 Electron dlopen；保留原文件与相对布局，不让它们成为独立启动入口。
find "$APP_ROOT" -type f -name '*.node' -exec chmod 0644 {} +
mapfile -d '' source_node_modules < <(
  find "$APP_ROOT" -type f -name '*.node' -print0
)
source_node_relative_paths=()
for node_module in "${source_node_modules[@]}"; do
  readelf -h "$node_module" >/dev/null 2>&1 || die "Xmind Node 模块不是 ELF：$node_module"
  source_node_relative_paths+=("${node_module#"$APP_ROOT"/}")
done
printf 'Xmind Node native modules: %s\n' "${#source_node_relative_paths[@]}"

# 官方 desktop 当前带有非标准 Desktop Action 段；AppImage 只保留标准 [Desktop Entry] 主段。
awk '
  /^\[Desktop Entry\]$/ { in_desktop_entry = 1; print; next }
  in_desktop_entry && /^\[/ { exit }
  in_desktop_entry { print }
' "$SOURCE_DESKTOP" > "$BUILD_DESKTOP"
install -Dm0644 "$SOURCE_ICON" "$BUILD_ICON"
[[ "$(grep -c '^\[Desktop Entry\]$' "$BUILD_DESKTOP")" -eq 1 ]] || die "Xmind desktop 缺少唯一 [Desktop Entry] 主段。"
[[ "$(grep -c '^Exec=' "$BUILD_DESKTOP")" -eq 1 ]] || die "Xmind desktop 的 Exec 字段数量异常。"
[[ "$(grep -c '^Icon=' "$BUILD_DESKTOP")" -eq 1 ]] || die "Xmind desktop 的 Icon 字段数量异常。"
sed -i \
  -e '/^Actions=/d' \
  -e 's|^Exec=.*|Exec=xmind --no-sandbox --disable-setuid-sandbox --ozone-platform-hint=auto %U|' \
  -e 's|^Icon=.*|Icon=xmind|' \
  "$BUILD_DESKTOP"
if grep -q '^StartupWMClass=' "$BUILD_DESKTOP"; then
  sed -i 's|^StartupWMClass=.*|StartupWMClass=xmind|' "$BUILD_DESKTOP"
else
  printf 'StartupWMClass=xmind\n' >> "$BUILD_DESKTOP"
fi
if grep -q '^X-AppImage-Version=' "$BUILD_DESKTOP"; then
  sed -i "s|^X-AppImage-Version=.*|X-AppImage-Version=$VERSION|" "$BUILD_DESKTOP"
else
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
exec "$APPDIR/bin/xmind" --no-sandbox --disable-setuid-sandbox --ozone-platform-hint=auto "$@"
APPRUN_EOF
chmod 0755 "$APPDIR/AppRun.sh"
bash -n "$APPDIR/AppRun.sh"

export ARCH=x86_64
export VERSION
export APPNAME=Xmind
export MAIN_BIN=xmind
export STARTUPWMCLASS=xmind
export ICON="$BUILD_ICON"
export DESKTOP="$BUILD_DESKTOP"
export OUTPATH="$DIST_DIR"
export OUTNAME=xmind.AppImage
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export DEPLOY_PIPEWIRE=1
export STRACE_MODE=0
# 保留 Xmind 官方 Electron/Node 二进制；不对闭源运行文件做二次 strip。
export NO_STRIP=1

# 扫描官方运行目录全部 ELF，包括 Electron helper 和 Node 原生模块。
elf_targets=()
while IFS= read -r -d '' target; do
  if readelf -h "$target" >/dev/null 2>&1; then
    elf_targets+=("$target")
  fi
done < <(find "$APP_ROOT" -type f -print0)
[[ ${#elf_targets[@]} -gt 0 ]] || die "Xmind 官方运行目录中未找到 ELF 文件。"
printf 'Xmind ELF files: %s\n' "${#elf_targets[@]}"

elf_library_dirs=()
for target in "${elf_targets[@]}"; do
  elf_library_dirs+=("$(dirname -- "$target")")
done
mapfile -t app_library_dirs < <(
  printf '%s\n' "${elf_library_dirs[@]}" | sort -u
)
[[ ${#app_library_dirs[@]} -gt 0 ]] || die "Xmind ELF 库搜索目录为空。"
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
[[ "$missing_dependencies" -eq 0 ]] || die "Xmind 官方组件仍存在缺失或 ABI 不兼容动态库。"

# Electron 的音频后端存在运行时 dlopen；显式带上 ALSA/PulseAudio/PipeWire 运行库。
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
[[ ${#extra_runtime_targets[@]} -gt 0 ]] || die "Xmind 额外运行目标为空。"

LD_LIBRARY_PATH="$BUILD_LIBRARY_PATH" quick-sharun \
  "${elf_targets[@]}" \
  "${audio_targets[@]}" \
  "${pulse_common_targets[@]}" \
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

log "验证最终 AppImage 内容"
mkdir -p "$VERIFY_DIR"
(
  cd "$VERIFY_DIR"
  "$OUTFILE" --appimage-extract >/dev/null
)
readonly VERIFY_APPDIR="$VERIFY_DIR/squashfs-root"
[[ -x "$VERIFY_APPDIR/AppRun" ]] || die "最终 AppImage 缺少 AppRun。"
[[ -f "$VERIFY_APPDIR/xmind.desktop" ]] || die "最终 AppImage 缺少 xmind.desktop。"
[[ -f "$VERIFY_APPDIR/bin/resources/app.asar" ]] || die "最终 AppImage 缺少 resources/app.asar。"

for node_relative_path in "${source_node_relative_paths[@]}"; do
  node_module="$VERIFY_APPDIR/bin/$node_relative_path"
  [[ -f "$node_module" ]] || die "最终 AppImage 缺少 Node 原生模块：$node_relative_path"
  readelf -h "$node_module" >/dev/null 2>&1 || \
    die "最终 AppImage 中的 Node 模块不是 ELF：$node_relative_path"
done

verify_bundled_library() {
  local library_pattern="$1"
  local library_label="$2"
  local library_path
  library_path="$(find -H "$VERIFY_APPDIR" -type f -name "$library_pattern" -print -quit)"
  [[ -n "$library_path" ]] || die "最终 AppImage 缺少 $library_label 的实际库文件。"
}

verify_bundled_library 'libasound.so.*' libasound.so.2
verify_bundled_library 'libpulse.so.*' libpulse.so.0
verify_bundled_library 'libpipewire-0.3.so.*' libpipewire-0.3.so.0

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
  timeout 30s dbus-run-session -- \
    xvfb-run -a "$OUTFILE" \
      --disable-gpu \
      --user-data-dir="$SMOKE_HOME/profile" \
      >"$SMOKE_LOG" 2>&1
smoke_rc=$?
set -e

cat "$SMOKE_LOG"
printf 'Xmind smoke test exit code: %s\n' "$smoke_rc"
if grep -Eqi \
  'error while loading shared libraries|cannot open shared object file|symbol lookup error|invalid ELF header|wrong ELF class|Exec format error|Trace/breakpoint trap|Segmentation fault|Aborted \(core dumped\)' \
  "$SMOKE_LOG"; then
  die "Xmind 冒烟测试检测到致命运行时错误。"
fi
if [[ "$smoke_rc" -eq 124 ]]; then
  if grep -Eqi 'FATAL:' "$SMOKE_LOG"; then
    die "Xmind 冒烟测试检测到致命 Electron 错误。"
  fi
elif [[ "$smoke_rc" -ne 0 ]]; then
  die "Xmind 在 Xvfb 冒烟测试中异常退出：$smoke_rc"
fi

rm -rf "$VERIFY_DIR" "$SMOKE_HOME" "$SMOKE_RUNTIME"
rm -f "$SMOKE_LOG"

sha256sum "$OUTFILE"
log "构建完成：$OUTFILE"
