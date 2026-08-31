#!/usr/bin/env bash
# 从 Postman 官方 latest Linux x64 tar.gz 重新封装 AnyLinux AppImage。
# 保留官方 Electron 应用目录、desktop 和图标，只补齐 AppImage 运行库与便携启动入口。
set -Eeuo pipefail

export LC_ALL=C

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
cd "$SCRIPT_DIR"

log() {
  printf '[Postman] %s\n' "$*"
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

HOST_ARCH="$(uname -m)"
readonly HOST_ARCH
[[ "$HOST_ARCH" == x86_64 ]] || die "当前仅支持 x86_64。"
command -v yay >/dev/null 2>&1 || die "构建环境缺少命令：yay"

readonly DOWNLOAD_URL="https://dl.pstmn.io/download/latest/linux64"
readonly SOURCE_DIR="$SCRIPT_DIR/source"
readonly TARBALL="$SOURCE_DIR/postman-linux-x64.tar.gz"
readonly EXTRACT_DIR="$SOURCE_DIR/extracted"
readonly ARCHIVE_LIST="$SOURCE_DIR/archive-files.txt"
readonly APPDIR="$SCRIPT_DIR/AppDir"
readonly APP_ROOT="$APPDIR/bin"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly OUTFILE="$DIST_DIR/postman.AppImage"
readonly VERIFY_DIR="$SCRIPT_DIR/verify"
readonly BUILD_DESKTOP="$SCRIPT_DIR/postman.desktop"
readonly BUILD_ICON="$SCRIPT_DIR/postman.png"
readonly SMOKE_HOME="$SCRIPT_DIR/smoke-home"
readonly SMOKE_RUNTIME="$SCRIPT_DIR/smoke-runtime"
readonly SMOKE_LOG="$SCRIPT_DIR/postman-smoke.log"

# 每次只清理 Postman 自己的构建目录、临时元数据和旧产物。
rm -rf \
  "$SOURCE_DIR" \
  "$APPDIR" \
  "$DIST_DIR" \
  "$VERIFY_DIR" \
  "$SMOKE_HOME" \
  "$SMOKE_RUNTIME"
rm -f "$BUILD_DESKTOP" "$BUILD_ICON" "$SMOKE_LOG"
mkdir -p "$SOURCE_DIR" "$EXTRACT_DIR" "$APP_ROOT" "$DIST_DIR"

# 安装 Electron 依赖部署、desktop 校验和隔离 GUI 冒烟测试所需组件。
yay -S --noconfirm --needed \
  base-devel binutils coreutils curl file findutils gawk grep inetutils openssl patchelf sed tar \
  appstream-glib desktop-file-utils util-linux zsync \
  xorg-server xorg-server-common xorg-server-xvfb \
  nss nspr gtk3 at-spi2-core cups dbus glib2 pango cairo expat fontconfig freetype2 \
  libx11 libxext libxi libxtst libxss libxrandr libxcomposite libxdamage libxfixes \
  libxkbcommon libxkbfile libxcb libdrm mesa libglvnd libva libvdpau wayland \
  alsa-lib libpulse pipewire pipewire-audio \
  libnotify libsecret systemd-libs shared-mime-info xdg-utils \
  hicolor-icon-theme adwaita-icon-theme ibus noto-fonts-cjk python

for command_name in \
  chmod cp curl desktop-file-validate file find grep hostname install ldd quick-sharun readelf \
  readlink sed sha256sum sort stat tar timeout xvfb-run xdg-mime xdg-open xdg-settings python3; do
  command -v "$command_name" >/dev/null 2>&1 || \
    die "构建环境缺少命令：$command_name"
done

log "下载 Postman 官方 latest Linux x64 tar.gz"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  --max-time 1800 \
  "$DOWNLOAD_URL" \
  -o "$TARBALL"
[[ -s "$TARBALL" ]] || die "Postman 官方下载文件为空。"
file "$TARBALL" | grep -Eq 'gzip compressed data|POSIX tar archive' || \
  die "Postman 官方下载文件不是预期的 tar.gz。"
printf 'Postman source SHA-256: '
sha256sum "$TARBALL" | awk '{print $1}'

log "检查并提取 Postman 官方归档"
tar -tzf "$TARBALL" > "$ARCHIVE_LIST"
[[ -s "$ARCHIVE_LIST" ]] || die "Postman 官方归档文件列表为空。"
if grep -Eq '(^/|(^|/)\.\.(/|$))' "$ARCHIVE_LIST"; then
  die "Postman 官方归档包含不安全路径。"
fi
if grep -Evq '^Postman(/|$)' "$ARCHIVE_LIST"; then
  die "Postman 官方归档包含 Postman/ 目录之外的文件。"
fi
tar -xzf "$TARBALL" -C "$EXTRACT_DIR"

readonly SOURCE_APP_ROOT="$EXTRACT_DIR/Postman/app"
readonly SOURCE_MAIN="$SOURCE_APP_ROOT/Postman"
readonly SOURCE_DESKTOP="$SOURCE_APP_ROOT/resources/Postman.desktop"
readonly SOURCE_ICON="$SOURCE_APP_ROOT/resources/app/assets/icon.png"
readonly SOURCE_PACKAGE_JSON="$SOURCE_APP_ROOT/resources/app/package.json"

[[ -x "$SOURCE_MAIN" ]] || die "官方包缺少 Postman 主程序：$SOURCE_MAIN"
[[ -f "$SOURCE_DESKTOP" ]] || die "官方包缺少 resources/Postman.desktop。"
[[ -f "$SOURCE_ICON" ]] || die "官方包缺少官方 Postman PNG 图标。"
[[ -f "$SOURCE_PACKAGE_JSON" ]] || die "官方包缺少 resources/app/package.json。"
file "$SOURCE_MAIN" | grep -q 'ELF 64-bit LSB.*x86-64' || \
  die "Postman 主程序不是 x86_64 ELF。"
file "$SOURCE_ICON" | grep -q 'PNG image data' || die "官方 Postman 图标不是 PNG。"

VERSION="$(
  python3 - "$SOURCE_PACKAGE_JSON" <<'PY'
import json
import re
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    package = json.load(fh)

version = package.get("version", "")
if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){2}(?:[-+][0-9A-Za-z.-]+)?", version):
    raise SystemExit(f"无效的 Postman 版本：{version!r}")
print(version)
PY
)"
readonly VERSION
printf 'Postman version: %s\n' "$VERSION"
printf '%s\n' "$VERSION" > ~/version

# 原样保留官方 Electron app/ 运行目录，避免遗漏 Chromium helper、原生模块或私有库。
cp -a "$SOURCE_APP_ROOT"/. "$APP_ROOT"/
[[ -x "$APP_ROOT/Postman" ]] || die "复制后缺少 Postman 主程序。"
[[ -f "$APP_ROOT/resources/app/package.json" ]] || die "复制后缺少 Postman 应用资源。"

# Electron 登录、OAuth 和外部链接会调用 xdg-utils；放入 AppImage PATH，避免依赖宿主脚本位置。
install -Dm0755 /usr/bin/xdg-open "$APP_ROOT/xdg-open"
install -Dm0755 /usr/bin/xdg-mime "$APP_ROOT/xdg-mime"
install -Dm0755 /usr/bin/xdg-settings "$APP_ROOT/xdg-settings"

# Node 原生模块由 Electron/Node 在运行时 dlopen，不把执行位当成独立程序入口。
find "$APP_ROOT" -type f -name '*.node' -exec chmod 0644 {} +

# 使用官方 desktop 和图标，仅把绝对安装路径改成 AppImage 内的便携入口。
install -Dm0644 "$SOURCE_DESKTOP" "$BUILD_DESKTOP"
install -Dm0644 "$SOURCE_ICON" "$BUILD_ICON"
[[ "$(grep -c '^Exec=' "$BUILD_DESKTOP")" -eq 1 ]] || die "官方 desktop 的 Exec 字段数量异常。"
[[ "$(grep -c '^Icon=' "$BUILD_DESKTOP")" -eq 1 ]] || die "官方 desktop 的 Icon 字段数量异常。"
sed -i \
  -e 's|^Exec=.*|Exec=Postman %U|' \
  -e 's|^Icon=.*|Icon=postman|' \
  "$BUILD_DESKTOP"
if grep -q '^StartupWMClass=' "$BUILD_DESKTOP"; then
  sed -i 's|^StartupWMClass=.*|StartupWMClass=postman|' "$BUILD_DESKTOP"
else
  printf 'StartupWMClass=postman\n' >> "$BUILD_DESKTOP"
fi
if grep -q '^X-AppImage-Version=' "$BUILD_DESKTOP"; then
  sed -i "s|^X-AppImage-Version=.*|X-AppImage-Version=$VERSION|" "$BUILD_DESKTOP"
else
  printf 'X-AppImage-Version=%s\n' "$VERSION" >> "$BUILD_DESKTOP"
fi
desktop-file-validate "$BUILD_DESKTOP"

# 运行时只切换到官方应用目录并启动 Postman，不修改宿主系统配置或权限。
cat > "$APPDIR/AppRun.sh" <<'APPRUN_EOF'
#!/bin/sh
set -e
export SHARUN_EXTRA_LIBRARY_PATH="$APPDIR/bin${SHARUN_EXTRA_LIBRARY_PATH:+:$SHARUN_EXTRA_LIBRARY_PATH}"
export SHARUN_WORKING_DIR="$APPDIR/bin"
cd "$APPDIR/bin"
exec "$APPDIR/bin/Postman" "$@"
APPRUN_EOF
chmod 0755 "$APPDIR/AppRun.sh"
bash -n "$APPDIR/AppRun.sh"

export ARCH=x86_64
export VERSION
export APPNAME=Postman
export MAIN_BIN=Postman
export STARTUPWMCLASS=postman
export ICON="$BUILD_ICON"
export DESKTOP="$BUILD_DESKTOP"
export OUTPATH="$DIST_DIR"
export OUTNAME=postman.AppImage
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export DEPLOY_PIPEWIRE=1
export STRACE_MODE=0
export NO_STRIP=1

# 扫描官方 Electron 运行目录中的全部 ELF，避免遗漏 Chromium helper、原生模块和私有库。
elf_targets=()
while IFS= read -r -d '' target; do
  if readelf -h "$target" >/dev/null 2>&1; then
    elf_targets+=("$target")
  fi
done < <(find "$APP_ROOT" -type f -print0)
[[ ${#elf_targets[@]} -gt 0 ]] || die "官方 Postman 运行目录中未找到 ELF 文件。"
printf 'Postman ELF files: %s\n' "${#elf_targets[@]}"

mapfile -t app_library_dirs < <(
  find "$APP_ROOT" -type f -printf '%h\n' | sort -u
)
[[ ${#app_library_dirs[@]} -gt 0 ]] || die "官方 Postman 运行目录为空。"
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
[[ "$missing_dependencies" -eq 0 ]] || die "官方 Postman 组件仍存在缺失动态库。"

# Electron 运行库由 quick-sharun 收集；xdg-utils 脚本已按官方应用需要放入 AppImage。
LD_LIBRARY_PATH="$BUILD_LIBRARY_PATH" quick-sharun \
  "${elf_targets[@]}" \
  /usr/bin/hostname \
  /usr/lib/libnss* \
  /usr/lib/libsoftokn3.so \
  /usr/lib/libfreeblpriv3.so \
  /usr/lib/pkcs11/* \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so

quick-sharun --make-appimage
[[ -s "$OUTFILE" ]] || die "未生成预期文件：$OUTFILE"
chmod 0755 "$OUTFILE"

# 解包最终 AppImage，核对官方应用资源、desktop、图标与 AppRun。
mkdir -p "$VERIFY_DIR"
(
  cd "$VERIFY_DIR"
  "$OUTFILE" --appimage-extract >/dev/null
)
readonly VERIFY_APPDIR="$VERIFY_DIR/squashfs-root"
[[ -x "$VERIFY_APPDIR/AppRun" ]] || die "最终 AppImage 缺少 AppRun。"
[[ -f "$VERIFY_APPDIR/postman.desktop" ]] || die "最终 AppImage 缺少 postman.desktop。"
[[ -f "$VERIFY_APPDIR/postman.png" ]] || die "最终 AppImage 缺少 postman.png。"
[[ -x "$VERIFY_APPDIR/bin/Postman" ]] || die "最终 AppImage 缺少 Postman 主程序。"
[[ -f "$VERIFY_APPDIR/bin/resources/app/package.json" ]] || die "最终 AppImage 缺少 Postman 应用资源。"

desktop-file-validate "$VERIFY_APPDIR/postman.desktop"

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
printf 'Postman smoke test exit code: %s\n' "$smoke_rc"
if grep -Eqi \
  'error while loading shared libraries|cannot open shared object file|invalid ELF header|wrong ELF class|Exec format error|Trace/breakpoint trap|Segmentation fault' \
  "$SMOKE_LOG"; then
  die "Postman 冒烟测试检测到致命运行错误。"
fi
if [[ "$smoke_rc" -eq 124 ]]; then
  if grep -Ei 'FATAL:' "$SMOKE_LOG" | \
    grep -Evqi 'FATAL:electron/shell/browser/electron_browser_main_parts\.cc:[0-9]+\] Failed to shutdown\.$'; then
    die "Postman 冒烟测试检测到致命运行错误。"
  fi
elif grep -Eqi 'FATAL:' "$SMOKE_LOG"; then
  die "Postman 冒烟测试检测到致命运行错误。"
fi
if [[ "$smoke_rc" -ne 0 && "$smoke_rc" -ne 124 ]]; then
  die "Postman 在 Xvfb 冒烟测试中异常退出：$smoke_rc"
fi

sha256sum "$OUTFILE"
log "构建完成：$OUTFILE"
