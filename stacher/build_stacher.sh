#!/usr/bin/env bash
# 从 Stacher 官方 Linux x64 更新端点动态下载当前 DEB，并用 quick-sharun 重新封装为 AnyLinux AppImage。
# AUR stacher7 仅作为依赖和包布局参考，不作为二进制来源。
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
cd "$SCRIPT_DIR"

log() {
  printf '[Stacher] %s\n' "$*"
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

#######################################################################
# 1. 构建环境与依赖
#######################################################################

HOST_ARCH="$(uname -m)"
readonly HOST_ARCH
[[ "$HOST_ARCH" == x86_64 ]] || die "当前仅支持 x86_64。"
command -v yay >/dev/null 2>&1 || die "构建环境缺少命令：yay"

readonly UPDATE_URL='https://api.stacher.io/api/update/linux/x64/latest'
readonly SOURCE_DIR="$SCRIPT_DIR/source"
readonly PACKAGE_FILE="$SOURCE_DIR/stacher7.deb"
readonly DEB_EXTRACT_DIR="$SOURCE_DIR/deb"
readonly PACKAGE_ROOT="$SOURCE_DIR/package"
readonly CONTROL_ROOT="$SOURCE_DIR/control"
readonly APPDIR="$SCRIPT_DIR/AppDir"
readonly APP_ROOT="$APPDIR/bin"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly OUTFILE="$DIST_DIR/stacher.AppImage"
readonly VERIFY_DIR="$SCRIPT_DIR/verify"
readonly BUILD_DESKTOP="$SCRIPT_DIR/stacher7.desktop"
readonly SMOKE_HOME="$SCRIPT_DIR/smoke-home"
readonly SMOKE_RUNTIME="$SCRIPT_DIR/smoke-runtime"
readonly SMOKE_LOG="$SCRIPT_DIR/stacher-smoke.log"

# 每次只清理 Stacher 自己的构建目录、临时文件和旧产物。
rm -rf \
  "$SOURCE_DIR" \
  "$APPDIR" \
  "$DIST_DIR" \
  "$VERIFY_DIR" \
  "$SMOKE_HOME" \
  "$SMOKE_RUNTIME"
rm -f "$BUILD_DESKTOP" "$SCRIPT_DIR"/stacher7-build-icon.* "$SMOKE_LOG"
mkdir -p "$SOURCE_DIR" "$DEB_EXTRACT_DIR" "$PACKAGE_ROOT" "$CONTROL_ROOT" "$APP_ROOT" "$DIST_DIR"

# 安装 Electron 依赖审计、桌面集成、音频/图形运行库以及隔离 GUI 测试组件。
yay -S --noconfirm --needed \
  base-devel binutils coreutils curl file findutils gawk grep inetutils patchelf python sed tar zstd \
  appstream-glib desktop-file-utils util-linux zsync \
  xorg-server xorg-server-common xorg-server-xvfb xorg-xauth \
  nss nspr alsa-lib at-spi2-core cups dbus glib2 gtk3 pango cairo expat fontconfig freetype2 \
  libx11 libxext libxi libxtst libxss libxrender libxrandr libxcomposite libxdamage libxfixes \
  libxcb libxkbcommon libxkbcommon-x11 libdrm mesa libglvnd libva libvdpau vulkan-icd-loader \
  libpulse pipewire pipewire-audio \
  libnotify libsecret shared-mime-info xdg-utils hicolor-icon-theme adwaita-icon-theme \
  gdk-pixbuf2 librsvg ibus

for command_name in \
  ar awk chmod curl dbus-run-session desktop-file-validate file find grep hostname install ldd \
  quick-sharun readelf readlink sed sha256sum sort stat tar timeout xvfb-run; do
  command -v "$command_name" >/dev/null 2>&1 || \
    die "构建环境缺少命令：$command_name"
done

#######################################################################
# 2. 获取并核对 Stacher 官方 Linux DEB
#######################################################################

log "从 Stacher 官方 Linux 更新端点下载当前 x64 DEB"
EFFECTIVE_URL="$(
  curl -fL \
    --retry 5 \
    --retry-all-errors \
    --retry-delay 2 \
    --connect-timeout 20 \
    --max-time 300 \
    --output "$PACKAGE_FILE" \
    --write-out '%{url_effective}' \
    "$UPDATE_URL"
)"
readonly EFFECTIVE_URL
[[ -s "$PACKAGE_FILE" ]] || die "Stacher 官方下载文件为空。"
file "$PACKAGE_FILE" | grep -q 'Debian binary package' || \
  die "Stacher 官方下载文件不是 Debian 软件包。"
sha256sum "$PACKAGE_FILE"
printf 'Stacher source URL: %s\n' "$EFFECTIVE_URL"

(
  cd "$DEB_EXTRACT_DIR"
  ar x "$PACKAGE_FILE"
)
shopt -s nullglob
control_archives=("$DEB_EXTRACT_DIR"/control.tar.*)
data_archives=("$DEB_EXTRACT_DIR"/data.tar.*)
shopt -u nullglob
[[ ${#control_archives[@]} -eq 1 ]] || die "官方 DEB 中应且只能有一个 control.tar.*。"
[[ ${#data_archives[@]} -eq 1 ]] || die "官方 DEB 中应且只能有一个 data.tar.*。"
tar -xf "${control_archives[0]}" -C "$CONTROL_ROOT"
tar -xf "${data_archives[0]}" -C "$PACKAGE_ROOT"

[[ -f "$CONTROL_ROOT/control" ]] || die "官方 DEB 缺少 control 元数据。"
VERSION="$(awk -F': ' '$1 == "Version" {print $2; exit}' "$CONTROL_ROOT/control")"
DEB_ARCH="$(awk -F': ' '$1 == "Architecture" {print $2; exit}' "$CONTROL_ROOT/control")"
readonly VERSION DEB_ARCH
[[ "$VERSION" =~ ^[0-9]+([.][0-9]+)+([+~-][A-Za-z0-9.+~-]+)?$ ]] || \
  die "官方 DEB 版本格式异常：$VERSION"
[[ "$DEB_ARCH" == amd64 ]] || die "官方 DEB 架构不是 amd64：$DEB_ARCH"

if [[ "$EFFECTIVE_URL" =~ /stacher7_([0-9]+([.][0-9]+)+)_amd64[.]deb([?].*)?$ ]]; then
  URL_VERSION="${BASH_REMATCH[1]}"
  [[ "$VERSION" == "$URL_VERSION" || "$VERSION" == "$URL_VERSION"-* ]] || \
    die "DEB control 版本与官方下载文件名不一致：$VERSION / $URL_VERSION"
fi
printf 'Stacher version: %s\n' "$VERSION"

#######################################################################
# 3. 保留官方 Electron 运行目录、desktop 和图标
#######################################################################

SOURCE_APP_ROOT="$PACKAGE_ROOT/usr/lib/stacher7"
if [[ ! -f "$SOURCE_APP_ROOT/resources/app.asar" ]]; then
  mapfile -d '' asar_candidates < <(
    find "$PACKAGE_ROOT" -type f -path '*/resources/app.asar' -print0
  )
  [[ ${#asar_candidates[@]} -eq 1 ]] || \
    die "官方 DEB 中无法唯一定位 resources/app.asar。"
  SOURCE_APP_ROOT="$(dirname -- "$(dirname -- "${asar_candidates[0]}")")"
fi
readonly SOURCE_APP_ROOT
[[ -d "$SOURCE_APP_ROOT" ]] || die "官方 DEB 缺少 Stacher 运行目录。"
[[ -f "$SOURCE_APP_ROOT/resources/app.asar" ]] || die "官方运行目录缺少 resources/app.asar。"

readonly MAIN_EXEC='Stacher7'
readonly SOURCE_MAIN="$SOURCE_APP_ROOT/$MAIN_EXEC"
[[ -x "$SOURCE_MAIN" ]] || die "官方运行目录缺少可执行主程序：$MAIN_EXEC"
file "$SOURCE_MAIN" | grep -q 'ELF 64-bit' || die "Stacher 主程序不是 64 位 ELF。"

if [[ -f "$PACKAGE_ROOT/usr/share/applications/stacher7.desktop" ]]; then
  SOURCE_DESKTOP="$PACKAGE_ROOT/usr/share/applications/stacher7.desktop"
else
  mapfile -d '' desktop_candidates < <(
    find "$PACKAGE_ROOT/usr/share/applications" -maxdepth 1 -type f -iname '*stacher*.desktop' -print0 2>/dev/null
  )
  [[ ${#desktop_candidates[@]} -eq 1 ]] || \
    die "官方 DEB 中无法唯一定位 Stacher desktop 文件。"
  SOURCE_DESKTOP="${desktop_candidates[0]}"
fi
readonly SOURCE_DESKTOP

mapfile -d '' icon_candidates < <(
  find \
    "$PACKAGE_ROOT/usr/share/pixmaps" \
    "$PACKAGE_ROOT/usr/share/icons" \
    -type f \
    \( -iname 'stacher7*.png' -o -iname 'stacher7*.svg' -o \
       -iname '*stacher*.png' -o -iname '*stacher*.svg' \) \
    -print0 2>/dev/null
)
[[ ${#icon_candidates[@]} -gt 0 ]] || die "官方 DEB 中未找到 Stacher 图标。"
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
readonly BUILD_ICON="$SCRIPT_DIR/stacher7-build-icon.$ICON_EXT"

printf 'Stacher runtime: %s\nStacher desktop: %s\nStacher icon: %s\n' \
  "${SOURCE_APP_ROOT#"$PACKAGE_ROOT"/}" \
  "${SOURCE_DESKTOP#"$PACKAGE_ROOT"/}" \
  "${SOURCE_ICON#"$PACKAGE_ROOT"/}"

log "复制 Stacher 官方完整 Electron 运行目录"
cp -a "$SOURCE_APP_ROOT"/. "$APP_ROOT"/
[[ -x "$APP_ROOT/$MAIN_EXEC" ]] || die "复制后缺少 Stacher 主程序。"
[[ -f "$APP_ROOT/resources/app.asar" ]] || die "复制后缺少 app.asar。"

# AppImage 内无法依赖发行版安装阶段设置 chrome-sandbox 的 setuid 权限；运行时保持无沙箱启动。
if [[ -e "$APP_ROOT/chrome-sandbox" ]]; then
  chmod 0755 "$APP_ROOT/chrome-sandbox"
fi

# Electron 原生 Node 模块必须保持上游二进制本体，不能被打包器替换成启动入口。
find "$APP_ROOT" -type f -name '*.node' -exec chmod 0644 {} +
mapfile -d '' source_node_modules < <(
  find "$APP_ROOT" -type f -name '*.node' -print0
)
source_node_relative_paths=()
for node_module in "${source_node_modules[@]}"; do
  readelf -h "$node_module" >/dev/null 2>&1 || \
    die "官方 Stacher Node 模块不是 ELF：$node_module"
  source_node_relative_paths+=("${node_module#"$APP_ROOT"/}")
done
printf 'Stacher Node native modules: %s\n' "${#source_node_relative_paths[@]}"

install -Dm0644 "$SOURCE_DESKTOP" "$BUILD_DESKTOP"
install -Dm0644 "$SOURCE_ICON" "$BUILD_ICON"
[[ "$(grep -c '^Exec=' "$BUILD_DESKTOP")" -eq 1 ]] || die "官方 desktop 的 Exec 字段数量异常。"
[[ "$(grep -c '^Icon=' "$BUILD_DESKTOP")" -eq 1 ]] || die "官方 desktop 的 Icon 字段数量异常。"
sed -i \
  -e "s|^Exec=.*|Exec=$MAIN_EXEC --no-sandbox --disable-setuid-sandbox %U|" \
  -e 's|^Icon=.*|Icon=stacher7|' \
  "$BUILD_DESKTOP"
if grep -q '^StartupWMClass=' "$BUILD_DESKTOP"; then
  sed -i 's|^StartupWMClass=.*|StartupWMClass=Stacher7|' "$BUILD_DESKTOP"
else
  printf 'StartupWMClass=Stacher7\n' >> "$BUILD_DESKTOP"
fi
if grep -q '^X-AppImage-Version=' "$BUILD_DESKTOP"; then
  sed -i "s|^X-AppImage-Version=.*|X-AppImage-Version=$VERSION|" "$BUILD_DESKTOP"
else
  printf 'X-AppImage-Version=%s\n' "$VERSION" >> "$BUILD_DESKTOP"
fi
desktop-file-validate "$BUILD_DESKTOP"

#######################################################################
# 4. quick-sharun AppImage 打包
#######################################################################

cat > "$APPDIR/AppRun.sh" <<APPRUN_EOF
#!/bin/sh
set -e
export SHARUN_EXTRA_LIBRARY_PATH="\$APPDIR/bin\${SHARUN_EXTRA_LIBRARY_PATH:+:\$SHARUN_EXTRA_LIBRARY_PATH}"
export SHARUN_WORKING_DIR="\$APPDIR/bin"
export GTK_IM_MODULE="\${GTK_IM_MODULE:-ibus}"
export XMODIFIERS="\${XMODIFIERS:-@im=ibus}"
cd "\$APPDIR/bin"
exec "\$APPDIR/bin/$MAIN_EXEC" --no-sandbox --disable-setuid-sandbox "\$@"
APPRUN_EOF
chmod 0755 "$APPDIR/AppRun.sh"
bash -n "$APPDIR/AppRun.sh"
printf '%s\n' "$VERSION" > ~/version

export ARCH=x86_64
export VERSION
export APPNAME=Stacher7
export MAIN_BIN="$MAIN_EXEC"
export STARTUPWMCLASS=Stacher7
export ICON="$BUILD_ICON"
export DESKTOP="$BUILD_DESKTOP"
export OUTPATH="$DIST_DIR"
export OUTNAME=stacher.AppImage
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export DEPLOY_PIPEWIRE=1
export STRACE_MODE=0
export NO_STRIP=1

# 扫描官方 Electron 目录中的全部 ELF，覆盖 Chromium 子进程、私有库和 Node 原生模块。
elf_targets=()
while IFS= read -r -d '' target; do
  if readelf -h "$target" >/dev/null 2>&1; then
    elf_targets+=("$target")
  fi
done < <(find "$APP_ROOT" -type f -print0)
[[ ${#elf_targets[@]} -gt 0 ]] || die "官方 Stacher 运行目录中未找到 ELF 文件。"
printf 'Stacher ELF files: %s\n' "${#elf_targets[@]}"

mapfile -t app_library_dirs < <(
  find "$APP_ROOT" -type f -printf '%h\n' | sort -u
)
[[ ${#app_library_dirs[@]} -gt 0 ]] || die "官方 Stacher 运行目录为空。"
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
[[ "$missing_dependencies" -eq 0 ]] || die "Stacher 官方组件仍存在缺失或 ABI 不兼容动态库。"

# Stacher 7 内置媒体播放与转换界面，明确部署 ALSA / PulseAudio / PipeWire 客户端运行库。
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

LD_LIBRARY_PATH="$BUILD_LIBRARY_PATH" quick-sharun \
  "${elf_targets[@]}" \
  "${audio_targets[@]}" \
  "${pulse_common_targets[@]}" \
  "${extra_runtime_targets[@]}"

quick-sharun --make-appimage

#######################################################################
# 5. 最终 AppImage 完整性验证
#######################################################################

[[ -s "$OUTFILE" ]] || die "未生成预期文件：$OUTFILE"
chmod 0755 "$OUTFILE"
file "$OUTFILE"
"$OUTFILE" --appimage-version >/dev/null
sha256sum "$OUTFILE" > "$OUTFILE.sha256"

log "验证最终 AppImage 可提取及关键资源完整性"
mkdir -p "$VERIFY_DIR"
(
  cd "$VERIFY_DIR"
  "$OUTFILE" --appimage-extract >/dev/null
)
readonly VERIFY_APPDIR="$VERIFY_DIR/squashfs-root"
[[ -x "$VERIFY_APPDIR/AppRun" ]] || die "最终 AppImage 缺少 AppRun。"
find -H "$VERIFY_APPDIR" -type f -name 'stacher7.desktop' -print -quit | grep -q . || \
  die "最终 AppImage 缺少 stacher7.desktop。"
find -H "$VERIFY_APPDIR" -type f \( -name 'stacher7*.png' -o -name 'stacher7*.svg' \) -print -quit | grep -q . || \
  die "最终 AppImage 缺少 Stacher 图标。"
find -H "$VERIFY_APPDIR" -type f -path '*/resources/app.asar' -print -quit | grep -q . || \
  die "最终 AppImage 缺少 resources/app.asar。"

verify_bundled_library() {
  local library_pattern="$1"
  local library_label="$2"
  local library_path
  library_path="$(find -H "$VERIFY_APPDIR" -type f -name "$library_pattern" -print -quit)"
  [[ -n "$library_path" ]] || die "最终 AppImage 缺少 $library_label 的实际库文件。"
}
verify_bundled_library 'libasound.so.*' libasound.so.2
verify_bundled_library 'libpulse.so.*' libpulse.so.0
verify_bundled_library 'libpulse-simple.so.*' libpulse-simple.so.0
verify_bundled_library 'libpipewire-0.3.so.*' libpipewire-0.3.so.0

for node_relative_path in "${source_node_relative_paths[@]}"; do
  node_module="$VERIFY_APPDIR/bin/$node_relative_path"
  [[ -f "$node_module" ]] || die "最终 AppImage 缺少 Node 原生模块：$node_relative_path"
  readelf -h "$node_module" >/dev/null 2>&1 || \
    die "最终 AppImage 中的 Node 模块不是 ELF：$node_relative_path"
  [[ ! "$node_module" -ef "$VERIFY_APPDIR/AppRun" ]] || \
    die "最终 AppImage 中的 Node 模块被错误替换成 sharun：$node_relative_path"
done

#######################################################################
# 6. 隔离 Xvfb 启动测试
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
printf 'Stacher smoke test exit code: %s\n' "$smoke_rc"
if grep -Eqi \
  'error while loading shared libraries|cannot open shared object file|symbol lookup error|invalid ELF header|wrong ELF class|Exec format error|Trace/breakpoint trap|Segmentation fault|Aborted \(core dumped\)|A JavaScript error occurred in the main process' \
  "$SMOKE_LOG"; then
  die "Stacher 冒烟测试检测到致命运行错误。"
fi
if [[ "$smoke_rc" -ne 0 && "$smoke_rc" -ne 124 ]]; then
  die "Stacher 在 Xvfb 冒烟测试中异常退出：$smoke_rc"
fi

rm -rf "$VERIFY_DIR" "$SMOKE_HOME" "$SMOKE_RUNTIME"
rm -f "$SMOKE_LOG"
log "已生成：$OUTFILE"
