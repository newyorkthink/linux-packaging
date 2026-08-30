#!/usr/bin/env bash
# 从微信官方 x86_64 deb 重新封装 AnyLinux AppImage。
# 官方 AppImage 未包含主程序直接依赖的 libpulse.so.0 和 libpulse-simple.so.0，
# 本脚本从官方 deb 自动提取程序、desktop 和最大尺寸 PNG 图标，并补齐全部运行库。
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
cd "$SCRIPT_DIR"

log() {
  printf '[WeChat] %s\n' "$*"
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

HOST_ARCH="$(uname -m)"
readonly HOST_ARCH
[[ "$HOST_ARCH" == x86_64 ]] || die "当前仅支持 x86_64。"
command -v yay >/dev/null 2>&1 || die "构建环境缺少命令：yay"

readonly OFFICIAL_DEB_URL="https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.deb"
readonly SOURCE_DIR="$SCRIPT_DIR/source"
readonly PACKAGE_ROOT="$SOURCE_DIR/package"
readonly DEB_FILE="$SOURCE_DIR/WeChatLinux_x86_64.deb"
readonly APPDIR="$SCRIPT_DIR/AppDir"
readonly APP_ROOT="$APPDIR/bin"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly OUTFILE="$DIST_DIR/wechat.AppImage"
readonly VERIFY_DIR="$SCRIPT_DIR/verify"
readonly BUILD_DESKTOP="$SCRIPT_DIR/wechat.desktop"
readonly BUILD_ICON="$SCRIPT_DIR/wechat.png"
readonly SMOKE_HOME="$SCRIPT_DIR/smoke-home"
readonly SMOKE_RUNTIME="$SCRIPT_DIR/smoke-runtime"
readonly SMOKE_LOG="$SCRIPT_DIR/wechat-smoke.log"

# 每次只清理 WeChat 自己的构建目录、临时元数据和旧产物。
rm -rf \
  "$SOURCE_DIR" \
  "$APPDIR" \
  "$DIST_DIR" \
  "$VERIFY_DIR" \
  "$SMOKE_HOME" \
  "$SMOKE_RUNTIME"
rm -f "$BUILD_DESKTOP" "$BUILD_ICON" "$SMOKE_LOG"
mkdir -p "$SOURCE_DIR" "$PACKAGE_ROOT" "$APP_ROOT" "$DIST_DIR"

# 安装 quick-sharun 打包工具、AUR wechat-bin 当前声明的运行依赖，
# 以及图形启动测试、输入法、通知、摄像头和 PipeWire 所需组件。
yay -S --noconfirm --needed \
  base-devel binutils coreutils curl file findutils gawk grep inetutils patchelf sed tar xz \
  appstream-glib desktop-file-utils util-linux zsync \
  xorg-server xorg-server-common xorg-server-xvfb \
  nss nspr xcb-util-renderutil xcb-util-keysyms xcb-util-image xcb-util-wm \
  libxkbcommon-x11 libxkbcommon libxcb gcc-libs glibc zlib \
  libxcomposite glib2 libxrender libxext libxi libxtst alsa-lib jack2 dbus \
  libxrandr fontconfig pango freetype2 libxfixes cairo libx11 expat \
  libvlc libxdamage libdrm mesa libglvnd libpulse systemd-libs krb5 \
  at-spi2-core cups gtk3 libnotify libsecret libxss shared-mime-info \
  xdg-utils hicolor-icon-theme adwaita-icon-theme noto-fonts-cjk \
  pipewire pipewire-audio ibus

for command_name in \
  ar awk curl dbus-run-session desktop-file-validate file find grep hostname \
  install ldd quick-sharun readelf readlink sed sha256sum sort stat tar timeout xvfb-run; do
  command -v "$command_name" >/dev/null 2>&1 || \
    die "构建环境缺少命令：$command_name"
done

log "下载微信官方 x86_64 deb"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  "$OFFICIAL_DEB_URL" \
  -o "$DEB_FILE"
[[ -s "$DEB_FILE" ]] || die "官方下载文件为空。"
file "$DEB_FILE" | grep -q 'Debian binary package' || \
  die "官方下载文件不是 Debian 软件包。"
sha256sum "$DEB_FILE"

log "提取官方 deb"
(
  cd "$SOURCE_DIR"
  ar x "$DEB_FILE"
)

shopt -s nullglob
control_archives=("$SOURCE_DIR"/control.tar.*)
data_archives=("$SOURCE_DIR"/data.tar.*)
shopt -u nullglob
[[ ${#control_archives[@]} -eq 1 ]] || \
  die "官方 deb 中应且只能有一个 control.tar.*。"
[[ ${#data_archives[@]} -eq 1 ]] || \
  die "官方 deb 中应且只能有一个 data.tar.*。"

VERSION="$(
  tar -xOf "${control_archives[0]}" ./control \
    | awk '$1 == "Version:" {print $2; exit}'
)"
[[ "$VERSION" =~ ^[0-9][0-9A-Za-z.+:~_-]*$ ]] || \
  die "无法从官方 deb 解析有效版本：$VERSION"
printf 'WeChat version: %s\n' "$VERSION"

tar -xf "${data_archives[0]}" -C "$PACKAGE_ROOT"
readonly SOURCE_APP_ROOT="$PACKAGE_ROOT/opt/wechat"
[[ -x "$SOURCE_APP_ROOT/wechat" ]] || die "官方 deb 缺少可执行主程序。"
file "$SOURCE_APP_ROOT/wechat" | grep -q 'ELF 64-bit' || \
  die "官方 WeChat 主程序不是 64 位 ELF。"

# 从官方包内自动定位唯一的 WeChat desktop 文件。
mapfile -d '' desktop_candidates < <(
  find "$PACKAGE_ROOT/usr/share/applications" \
    -maxdepth 1 \
    -type f \
    -iname '*wechat*.desktop' \
    -print0
)
[[ ${#desktop_candidates[@]} -eq 1 ]] || \
  die "官方 deb 中应且只能找到一个 WeChat desktop 文件，实际为 ${#desktop_candidates[@]}。"
readonly SOURCE_DESKTOP="${desktop_candidates[0]}"

# 从官方包内所有 wechat.png 中选择文件体积最大的图标，当前对应 256x256。
mapfile -d '' icon_candidates < <(
  find "$PACKAGE_ROOT/usr/share/icons" \
    -type f \
    -iname 'wechat.png' \
    -print0
)
[[ ${#icon_candidates[@]} -gt 0 ]] || die "官方 deb 中未找到 wechat.png。"

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
file "$SOURCE_ICON" | grep -q 'PNG image data' || die "找到的微信图标不是 PNG。"
printf 'WeChat desktop: %s\nWeChat icon: %s\n' \
  "${SOURCE_DESKTOP#"$PACKAGE_ROOT"/}" \
  "${SOURCE_ICON#"$PACKAGE_ROOT"/}"

# 保持官方完整运行目录的相对布局，WeChat、VLC 插件和 WMPF 子进程均从该目录加载资源。
cp -a "$SOURCE_APP_ROOT"/. "$APP_ROOT"/

# 收集官方运行目录内每一个实际含文件的目录，仅供构建阶段审计和解析嵌套私有库。
# 运行时仍由官方各 ELF 自带的 RPATH/RUNPATH 选择同目录库，避免同名私有库相互覆盖。
mapfile -t app_library_dirs < <(
  find "$APP_ROOT" -type f -printf '%h\n' | sort -u
)
[[ ${#app_library_dirs[@]} -gt 0 ]] || die "官方运行目录为空。"
BUILD_LIBRARY_PATH="$(IFS=:; printf '%s' "${app_library_dirs[*]}")"
BUILD_LIBRARY_PATH="$BUILD_LIBRARY_PATH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# quick-sharun 从官方包内提取的 desktop 和 PNG 生成 AppImage 顶层桌面集成文件。
install -Dm0644 "$SOURCE_DESKTOP" "$BUILD_DESKTOP"
install -Dm0644 "$SOURCE_ICON" "$BUILD_ICON"
[[ "$(grep -c '^Exec=' "$BUILD_DESKTOP")" -eq 1 ]] || \
  die "官方 desktop 的 Exec 字段数量异常。"
[[ "$(grep -c '^Icon=' "$BUILD_DESKTOP")" -eq 1 ]] || \
  die "官方 desktop 的 Icon 字段数量异常。"
sed -i \
  -e 's|^Exec=.*|Exec=wechat %U|' \
  -e 's|^Icon=.*|Icon=wechat|' \
  "$BUILD_DESKTOP"
if ! grep -q '^StartupWMClass=' "$BUILD_DESKTOP"; then
  printf 'StartupWMClass=wechat\n' >> "$BUILD_DESKTOP"
fi
if ! grep -q '^X-AppImage-Version=' "$BUILD_DESKTOP"; then
  printf 'X-AppImage-Version=%s\n' "$VERSION" >> "$BUILD_DESKTOP"
fi
desktop-file-validate "$BUILD_DESKTOP"

# 入口固定从包内程序目录启动，同时保留用户现有的输入法环境变量。
cat > "$APPDIR/AppRun.sh" <<'APPRUN_EOF'
#!/bin/sh
set -e

export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"
export QT_AUTO_SCREEN_SCALE_FACTOR="${QT_AUTO_SCREEN_SCALE_FACTOR:-1}"
export SHARUN_EXTRA_LIBRARY_PATH="$APPDIR/bin${SHARUN_EXTRA_LIBRARY_PATH:+:$SHARUN_EXTRA_LIBRARY_PATH}"
export SHARUN_WORKING_DIR="$APPDIR/bin"
export VLC_PLUGIN_PATH="$APPDIR/bin/vlc_plugins"

cd "$APPDIR/bin"
exec "$APPDIR/bin/wechat" "$@"
APPRUN_EOF
chmod 0755 "$APPDIR/AppRun.sh"
bash -n "$APPDIR/AppRun.sh"

printf '%s\n' "$VERSION" > ~/version

export ARCH=x86_64
export VERSION
export APPNAME=WeChat
export MAIN_BIN=wechat
export STARTUPWMCLASS=wechat
export ICON="$BUILD_ICON"
export DESKTOP="$BUILD_DESKTOP"
export OUTPATH="$DIST_DIR"
export OUTNAME=wechat.AppImage
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export DEPLOY_PIPEWIRE=1

# 扫描官方完整运行目录内的所有 ELF，而不只扫描主程序；这样 VLC、WMPF、
# OCR、文件预览和音视频通话组件的间接运行库也会一并部署。
elf_targets=()
while IFS= read -r -d '' target; do
  if readelf -h "$target" >/dev/null 2>&1; then
    elf_targets+=("$target")
  fi
done < <(find "$APP_ROOT" -type f -print0)
[[ ${#elf_targets[@]} -gt 0 ]] || die "官方运行目录中未找到 ELF 文件。"
printf 'WeChat ELF files: %s\n' "${#elf_targets[@]}"

# 在 quick-sharun 前一次性审计全部 ELF；嵌套私有库和系统库有任何缺失时，
# 输出所有对应文件后再停止，避免打包过程逐个暴露依赖问题。
missing_dependencies=0
for target in "${elf_targets[@]}"; do
  target_library_path="$(dirname -- "$target"):$BUILD_LIBRARY_PATH"
  target_dependencies="$(LD_LIBRARY_PATH="$target_library_path" ldd "$target" 2>&1 || true)"
  if grep -Fq 'not found' <<< "$target_dependencies"; then
    printf '缺失依赖文件：%s\n%s\n' "$target" "$target_dependencies" >&2
    missing_dependencies=1
  fi
done
[[ "$missing_dependencies" -eq 0 ]] || die "官方 WeChat 组件仍存在缺失动态库。"

# 明确把 PulseAudio 客户端库交给 quick-sharun；这是官方 AppImage 缺失并导致
# libpulse.so.0 启动错误的关键修复。libpulsecommon 的具体版本由当前 Arch 包决定。
shopt -s nullglob
pulse_targets=(
  /usr/lib/libpulse.so.0
  /usr/lib/libpulse-simple.so.0
  /usr/lib/pulseaudio/libpulsecommon-*.so
)
shopt -u nullglob
[[ -e /usr/lib/libpulse.so.0 ]] || die "构建环境缺少 libpulse.so.0。"
[[ -e /usr/lib/libpulse-simple.so.0 ]] || die "构建环境缺少 libpulse-simple.so.0。"

LD_LIBRARY_PATH="$BUILD_LIBRARY_PATH" quick-sharun \
  "${elf_targets[@]}" \
  "${pulse_targets[@]}" \
  /usr/bin/hostname

# 在封装前确认关键修复库已经进入 AppDir。
mapfile -t bundled_pulse < <(
  find "$APPDIR" \( -type f -o -type l \) -name 'libpulse.so.0' -print
)
mapfile -t bundled_pulse_simple < <(
  find "$APPDIR" \( -type f -o -type l \) -name 'libpulse-simple.so.0' -print
)
[[ ${#bundled_pulse[@]} -gt 0 ]] || die "AppDir 未包含 libpulse.so.0。"
[[ ${#bundled_pulse_simple[@]} -gt 0 ]] || die "AppDir 未包含 libpulse-simple.so.0。"

quick-sharun --make-appimage
[[ -s "$OUTFILE" ]] || die "未生成预期文件：$OUTFILE"
chmod 0755 "$OUTFILE"

# 解包最终 AppImage 再检查一次，避免只验证打包前的临时 AppDir。
mkdir -p "$VERIFY_DIR"
(
  cd "$VERIFY_DIR"
  "$OUTFILE" --appimage-extract >/dev/null
)
readonly VERIFY_APPDIR="$VERIFY_DIR/squashfs-root"
[[ -x "$VERIFY_APPDIR/AppRun" ]] || die "最终 AppImage 缺少 AppRun。"
[[ -f "$VERIFY_APPDIR/wechat.desktop" ]] || die "最终 AppImage 缺少 wechat.desktop。"
[[ -f "$VERIFY_APPDIR/wechat.png" ]] || die "最终 AppImage 缺少 wechat.png。"

verify_bundled_library() {
  local library_name="$1"
  local library_path resolved_path

  library_path="$(
    find "$VERIFY_APPDIR" \
      \( -type f -o -type l \) \
      -name "$library_name" \
      -print \
      -quit
  )"
  [[ -n "$library_path" ]] || die "最终 AppImage 缺少 $library_name。"
  resolved_path="$(readlink -f "$library_path")"
  [[ -f "$resolved_path" ]] || die "最终 AppImage 中的 $library_name 是无效链接。"
  [[ "$resolved_path" == "$VERIFY_APPDIR/"* ]] || \
    die "最终 AppImage 中的 $library_name 指向包外路径：$resolved_path"
}

verify_bundled_library libpulse.so.0
verify_bundled_library libpulse-simple.so.0

# 在隔离 HOME、D-Bus 会话和虚拟 X11 中直接启动最终 AppImage；正常 GUI 会持续运行到超时。
mkdir -p "$SMOKE_HOME" "$SMOKE_RUNTIME"
chmod 0700 "$SMOKE_RUNTIME"
set +e
HOME="$SMOKE_HOME" \
XDG_RUNTIME_DIR="$SMOKE_RUNTIME" \
QT_QPA_PLATFORM=xcb \
APPIMAGE_EXTRACT_AND_RUN=1 \
timeout 30s xvfb-run -a dbus-run-session -- \
  "$OUTFILE" >"$SMOKE_LOG" 2>&1
smoke_status=$?
set -e

if [[ "$smoke_status" -ne 124 ]]; then
  tail -n 250 "$SMOKE_LOG" >&2 || true
  die "最终 AppImage 图形启动测试提前退出，状态码：$smoke_status"
fi
if grep -Eqi \
  'error while loading shared libraries|symbol lookup error|Could not load the Qt platform plugin|Segmentation fault|Aborted \(core dumped\)' \
  "$SMOKE_LOG"; then
  tail -n 250 "$SMOKE_LOG" >&2 || true
  die "最终 AppImage 启动日志包含致命错误。"
fi

sha256sum "$OUTFILE" > "$OUTFILE.sha256"
log "构建完成：$OUTFILE"
