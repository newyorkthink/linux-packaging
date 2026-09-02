#!/usr/bin/env bash
# 从 GitKraken 官方 production Linux x64 tar.gz 重新封装 AnyLinux AppImage。
# 仅补充 AppImage 运行依赖、中文 UTF-8 locale 与 GTK 输入法兼容，不修改授权逻辑或应用功能。
set -Eeuo pipefail

export LC_ALL=C

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
cd "$SCRIPT_DIR"

log() {
  printf '[GitKraken] %s\n' "$*"
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

HOST_ARCH="$(uname -m)"
readonly HOST_ARCH
[[ "$HOST_ARCH" == x86_64 ]] || die "当前仅支持 x86_64。"
command -v yay >/dev/null 2>&1 || die "构建环境缺少命令：yay"

readonly RELEASES_URL="https://api.gitkraken.dev/releases/production/linux/x64/RELEASES"
readonly WORK_DIR="$SCRIPT_DIR/.work"
readonly RELEASES_JSON="$WORK_DIR/RELEASES.json"
readonly SOURCE_ARCHIVE="$WORK_DIR/gitkraken-amd64.tar.gz"
readonly ARCHIVE_LIST="$WORK_DIR/archive-files.txt"
readonly EXTRACT_DIR="$WORK_DIR/extracted"
readonly APPDIR="$SCRIPT_DIR/AppDir"
readonly APP_ROOT="$APPDIR/bin"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly OUTFILE="$DIST_DIR/gitkraken.AppImage"
readonly VERIFY_DIR="$WORK_DIR/verify"
readonly BUILD_DESKTOP="$SCRIPT_DIR/gitkraken.desktop"
readonly BUILD_ICON="$SCRIPT_DIR/gitkraken.png"
readonly SMOKE_HOME="$WORK_DIR/smoke-home"
readonly SMOKE_RUNTIME="$WORK_DIR/smoke-runtime"
readonly SMOKE_LOG="$WORK_DIR/gitkraken-smoke.log"

# 每次只清理 GitKraken 当前项目自己的构建目录、临时元数据和旧产物。
rm -rf "$WORK_DIR" "$APPDIR" "$DIST_DIR"
rm -f "$BUILD_DESKTOP" "$BUILD_ICON"
mkdir -p "$WORK_DIR" "$EXTRACT_DIR" "$APP_ROOT" "$DIST_DIR"

# 安装 Electron/Chromium 运行依赖、GTK 输入法模块以及构建验证工具。
yay -S --noconfirm --needed \
  base-devel binutils coreutils curl file findutils gawk grep jq patchelf sed tar \
  appstream-glib desktop-file-utils util-linux zsync \
  xorg-server xorg-server-common xorg-server-xvfb \
  nss nspr gtk3 libsecret libxkbfile at-spi2-core cups dbus glib2 pango cairo expat \
  fontconfig freetype2 libx11 libxext libxi libxtst libxss libxrandr libxcomposite \
  libxdamage libxfixes libxkbcommon libxcb libdrm mesa libglvnd libva libvdpau wayland \
  alsa-lib libpulse pipewire pipewire-audio libnotify systemd-libs shared-mime-info xdg-utils \
  hicolor-icon-theme adwaita-icon-theme ibus fcitx5-gtk

for command_name in \
  chmod cp curl desktop-file-validate file find grep hostname jq ldd quick-sharun readelf \
  sed sha256sum sort stat tar timeout xvfb-run; do
  command -v "$command_name" >/dev/null 2>&1 || \
    die "构建环境缺少命令：$command_name"
done

readonly IBUS_GTK3_MODULE="/usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so"
readonly FCITX5_GTK3_MODULE="/usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so"
[[ -f "$IBUS_GTK3_MODULE" ]] || die "未找到 IBus GTK3 输入模块：$IBUS_GTK3_MODULE"
[[ -f "$FCITX5_GTK3_MODULE" ]] || die "未找到 Fcitx5 GTK3 输入模块：$FCITX5_GTK3_MODULE"

log "读取 GitKraken 官方 production release 元数据"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  --max-time 120 \
  "$RELEASES_URL" \
  -o "$RELEASES_JSON"
[[ -s "$RELEASES_JSON" ]] || die "GitKraken release 元数据为空。"

VERSION="$(jq -er '.name | strings' "$RELEASES_JSON")" || \
  die "无法从 GitKraken release 元数据解析版本。"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || \
  die "GitKraken production 版本格式异常：$VERSION"
readonly VERSION
printf 'GitKraken version: %s\n' "$VERSION"
printf '%s\n' "$VERSION" > "$DIST_DIR/version.txt"
printf '%s\n' "$VERSION" > ~/version

DOWNLOAD_URL="https://api.gitkraken.dev/releases/production/linux/x64/${VERSION}/gitkraken-amd64.tar.gz"
readonly DOWNLOAD_URL
[[ "$DOWNLOAD_URL" =~ ^https://api\.gitkraken\.dev/releases/production/linux/x64/[0-9]+\.[0-9]+\.[0-9]+/gitkraken-amd64\.tar\.gz$ ]] || \
  die "GitKraken 下载地址校验失败：$DOWNLOAD_URL"

log "下载 GitKraken 官方 Linux x64 tar.gz"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  --max-time 1800 \
  "$DOWNLOAD_URL" \
  -o "$SOURCE_ARCHIVE"
[[ -s "$SOURCE_ARCHIVE" ]] || die "GitKraken 官方下载文件为空。"
file "$SOURCE_ARCHIVE" | grep -q 'gzip compressed data' || \
  die "GitKraken 官方下载文件不是预期的 tar.gz。"
sha256sum "$SOURCE_ARCHIVE" | sed "s#  .*#  gitkraken-amd64.tar.gz#" > "$DIST_DIR/source.sha256"
cat "$DIST_DIR/source.sha256"

log "检查并提取 GitKraken 官方归档"
tar -tzf "$SOURCE_ARCHIVE" > "$ARCHIVE_LIST"
[[ -s "$ARCHIVE_LIST" ]] || die "GitKraken 官方归档文件列表为空。"
if grep -Eq '(^/|(^|/)\.\.(/|$))' "$ARCHIVE_LIST"; then
  die "GitKraken 官方归档包含不安全路径。"
fi
if grep -Evq '^gitkraken(/|$)' "$ARCHIVE_LIST"; then
  die "GitKraken 官方归档包含 gitkraken/ 目录之外的文件。"
fi
tar -xzf "$SOURCE_ARCHIVE" -C "$EXTRACT_DIR"

readonly SOURCE_APP_ROOT="$EXTRACT_DIR/gitkraken"
readonly SOURCE_MAIN="$SOURCE_APP_ROOT/gitkraken"
readonly SOURCE_LAUNCHER="$SOURCE_APP_ROOT/resources/bin/gitkraken.sh"
readonly SOURCE_ICON="$SOURCE_APP_ROOT/gitkraken.png"
readonly SOURCE_SANDBOX="$SOURCE_APP_ROOT/chrome-sandbox"

[[ -x "$SOURCE_MAIN" ]] || die "官方包缺少 GitKraken 主程序：$SOURCE_MAIN"
[[ -f "$SOURCE_LAUNCHER" ]] || die "官方包缺少 GitKraken launcher：$SOURCE_LAUNCHER"
[[ -f "$SOURCE_ICON" ]] || die "官方包缺少 GitKraken 图标：$SOURCE_ICON"
[[ -f "$SOURCE_SANDBOX" ]] || die "官方包缺少 chrome-sandbox：$SOURCE_SANDBOX"
file "$SOURCE_MAIN" | grep -q 'ELF 64-bit LSB.*x86-64' || \
  die "GitKraken 主程序不是 x86_64 ELF。"
file "$SOURCE_ICON" | grep -q 'PNG image data' || die "GitKraken 图标不是 PNG。"

# 原样保留官方 GitKraken 应用目录内容；只把容器根目录改为 AppImage 内部 bin/。
cp -a "$SOURCE_APP_ROOT"/. "$APP_ROOT"/
chmod 4755 "$APP_ROOT/chrome-sandbox"
install -Dm0644 "$SOURCE_ICON" "$BUILD_ICON"

# 基于上游 AUR/官方 desktop 语义生成便携入口，不改变 GitKraken 的应用行为。
cat > "$BUILD_DESKTOP" <<DESKTOP_EOF
[Desktop Entry]
Name=GitKraken
Comment=Unleash your repo
GenericName=Git Client
Exec=gitkraken %U
Icon=gitkraken
Type=Application
StartupNotify=true
Categories=GNOME;GTK;Development;RevisionControl;
StartupWMClass=gitkraken
X-AppImage-Version=$VERSION
DESKTOP_EOF
desktop-file-validate "$BUILD_DESKTOP"

# 运行时只补充中文 UTF-8 locale，并继承宿主已配置的 GTK_IM_MODULE / 输入法会话。
cat > "$APPDIR/AppRun.sh" <<'APPRUN_EOF'
#!/bin/sh
set -e
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export SHARUN_EXTRA_LIBRARY_PATH="$APPDIR/bin${SHARUN_EXTRA_LIBRARY_PATH:+:$SHARUN_EXTRA_LIBRARY_PATH}"
export SHARUN_WORKING_DIR="$APPDIR/bin"
cd "$APPDIR/bin"
exec "$APPDIR/bin/gitkraken" "$@"
APPRUN_EOF
chmod 0755 "$APPDIR/AppRun.sh"
bash -n "$APPDIR/AppRun.sh"

export ARCH=x86_64
export VERSION
export APPNAME=GitKraken
export MAIN_BIN=gitkraken
export STARTUPWMCLASS=gitkraken
export ICON="$BUILD_ICON"
export DESKTOP="$BUILD_DESKTOP"
export OUTPATH="$DIST_DIR"
export OUTNAME=gitkraken.AppImage
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export DEPLOY_PIPEWIRE=1
export STRACE_MODE=0
export NO_STRIP=1

# 扫描官方应用目录中的全部 ELF，避免遗漏 Chromium helper、原生模块和私有库。
elf_targets=()
while IFS= read -r -d '' target; do
  if readelf -h "$target" >/dev/null 2>&1; then
    elf_targets+=("$target")
  fi
done < <(find "$APP_ROOT" -type f -print0)
[[ ${#elf_targets[@]} -gt 0 ]] || die "官方 GitKraken 运行目录中未找到 ELF 文件。"
printf 'GitKraken ELF files: %s\n' "${#elf_targets[@]}"

mapfile -t app_library_dirs < <(
  find "$APP_ROOT" -type f -printf '%h\n' | sort -u
)
[[ ${#app_library_dirs[@]} -gt 0 ]] || die "官方 GitKraken 运行目录为空。"
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
[[ "$missing_dependencies" -eq 0 ]] || die "官方 GitKraken 组件仍存在缺失动态库。"

# Electron 运行库由 quick-sharun 收集；同时带入 IBus/Fcitx5 的 GTK3 输入法模块。
LD_LIBRARY_PATH="$BUILD_LIBRARY_PATH" quick-sharun \
  "${elf_targets[@]}" \
  /usr/bin/hostname \
  /usr/lib/libnss* \
  /usr/lib/libsoftokn3.so \
  /usr/lib/libfreeblpriv3.so \
  /usr/lib/pkcs11/* \
  "$IBUS_GTK3_MODULE" \
  "$FCITX5_GTK3_MODULE"

# 保留上游 Electron sandbox 文件权限；CI 的 root 冒烟测试另行使用 --no-sandbox，不改变正式启动方式。
chmod 4755 "$APP_ROOT/chrome-sandbox"
quick-sharun --make-appimage

[[ -s "$OUTFILE" ]] || die "未生成预期文件：$OUTFILE"
chmod 0755 "$OUTFILE"
file "$OUTFILE"
"$OUTFILE" --appimage-version >/dev/null
sha256sum "$OUTFILE" > "$OUTFILE.sha256"

# 解包最终 AppImage，核对上游程序、中文 locale、输入模块、desktop 和图标。
mkdir -p "$VERIFY_DIR"
(
  cd "$VERIFY_DIR"
  "$OUTFILE" --appimage-extract >/dev/null
)
readonly VERIFY_APPDIR="$VERIFY_DIR/squashfs-root"
[[ -x "$VERIFY_APPDIR/AppRun" ]] || die "最终 AppImage 缺少 AppRun。"
[[ -f "$VERIFY_APPDIR/gitkraken.desktop" ]] || die "最终 AppImage 缺少 gitkraken.desktop。"
[[ -f "$VERIFY_APPDIR/gitkraken.png" ]] || die "最终 AppImage 缺少 gitkraken.png。"
[[ -x "$VERIFY_APPDIR/bin/gitkraken" ]] || die "最终 AppImage 缺少 GitKraken 主程序。"
[[ -f "$VERIFY_APPDIR/bin/resources/bin/gitkraken.sh" ]] || die "最终 AppImage 缺少官方 launcher。"
[[ -f "$VERIFY_APPDIR/bin/chrome-sandbox" ]] || die "最终 AppImage 缺少 chrome-sandbox。"
find "$VERIFY_APPDIR" -type f -name 'im-ibus.so' -print -quit | grep -q . || \
  die "最终 AppImage 缺少 IBus GTK3 输入模块。"
find "$VERIFY_APPDIR" -type f -name 'im-fcitx5.so' -print -quit | grep -q . || \
  die "最终 AppImage 缺少 Fcitx5 GTK3 输入模块。"
grep -R -Fq 'LANG=zh_CN.UTF-8' "$VERIFY_APPDIR" || die "最终 AppImage 缺少 zh_CN.UTF-8 locale 设置。"
grep -R -Fq 'LANGUAGE=zh_CN:zh' "$VERIFY_APPDIR" || die "最终 AppImage 缺少 zh_CN:zh locale 设置。"
desktop-file-validate "$VERIFY_APPDIR/gitkraken.desktop"

final_main_dependencies="$(
  LD_LIBRARY_PATH="$VERIFY_APPDIR/bin:$VERIFY_APPDIR/shared/lib" \
    ldd "$VERIFY_APPDIR/bin/gitkraken" 2>&1 || true
)"
if grep -Fq 'not found' <<< "$final_main_dependencies"; then
  printf '%s\n' "$final_main_dependencies" >&2
  die "最终 AppImage 的 GitKraken 主程序仍存在缺失动态库。"
fi

# 使用隔离 HOME/XDG 目录做非交互 GUI 冒烟测试；root CI 仅在测试命令中关闭 Chromium sandbox。
mkdir -p "$SMOKE_HOME" "$SMOKE_RUNTIME"
chmod 0700 "$SMOKE_RUNTIME"
set +e
HOME="$SMOKE_HOME" \
XDG_CONFIG_HOME="$SMOKE_HOME/.config" \
XDG_CACHE_HOME="$SMOKE_HOME/.cache" \
XDG_RUNTIME_DIR="$SMOKE_RUNTIME" \
APPIMAGE_EXTRACT_AND_RUN=1 \
timeout 25s xvfb-run -a \
  "$OUTFILE" \
  --no-sandbox \
  --disable-setuid-sandbox \
  --disable-gpu \
  --user-data-dir="$SMOKE_HOME/profile" \
  >"$SMOKE_LOG" 2>&1
smoke_rc=$?
set -e

cat "$SMOKE_LOG"
printf 'GitKraken smoke test exit code: %s\n' "$smoke_rc"
if grep -Eqi \
  'error while loading shared libraries|cannot open shared object file|symbol lookup error|invalid ELF header|wrong ELF class|Exec format error|Trace/breakpoint trap|Segmentation fault|Aborted \(core dumped\)' \
  "$SMOKE_LOG"; then
  die "GitKraken 冒烟测试检测到致命运行错误。"
fi
if [[ "$smoke_rc" -ne 0 && "$smoke_rc" -ne 124 ]]; then
  die "GitKraken 冒烟测试异常退出：$smoke_rc"
fi

log "构建完成：$OUTFILE"
