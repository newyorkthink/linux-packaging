#!/usr/bin/env bash
# 从飞书官方 Linux API 动态获取当前 x86_64 DEB，并重新封装为 AnyLinux AppImage。
# AUR feishu-bin 与 Nixpkgs feishu 仅用于核对官方包布局、运行依赖和启动入口，不作为二进制来源。
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log() {
  printf '[Feishu] %s\n' "$*"
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

####################################################################
# 1. 构建环境与依赖
#######################################################################

readonly HOST_ARCH="$(uname -m)"
[[ "$HOST_ARCH" == x86_64 ]] || die "当前仅支持 x86_64。"
command -v yay >/dev/null 2>&1 || die "构建环境缺少命令：yay"

readonly CLIENT_API='https://www.feishu.cn/api/package_info?platform=10'
readonly SOURCE_DIR="$SCRIPT_DIR/source"
readonly PACKAGE_ROOT="$SOURCE_DIR/package"
readonly PACKAGE_FILE="$SOURCE_DIR/feishu.deb"
readonly DEB_EXTRACT_DIR="$SOURCE_DIR/deb"
readonly APPDIR="$SCRIPT_DIR/AppDir"
readonly APP_ROOT="$APPDIR/bin"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly OUTFILE="$DIST_DIR/feishu.AppImage"
readonly VERIFY_DIR="$SCRIPT_DIR/verify"
readonly BUILD_DESKTOP="$SCRIPT_DIR/feishu.desktop"
readonly BUILD_ICON="$SCRIPT_DIR/feishu.png"
readonly SMOKE_HOME="$SCRIPT_DIR/smoke-home"
readonly SMOKE_RUNTIME="$SCRIPT_DIR/smoke-runtime"
readonly SMOKE_LOG="$SCRIPT_DIR/feishu-smoke.log"

# 每次只清理 Feishu 自己的构建目录、临时元数据和旧产物。
rm -rf \
  "$SOURCE_DIR" \
  "$APPDIR" \
  "$DIST_DIR" \
  "$VERIFY_DIR" \
  "$SMOKE_HOME" \
  "$SMOKE_RUNTIME"
rm -f "$BUILD_DESKTOP" "$BUILD_ICON" "$SMOKE_LOG"
mkdir -p "$SOURCE_DIR" "$PACKAGE_ROOT" "$APP_ROOT" "$DIST_DIR"

# 安装 quick-sharun 所需工兛、飞书 Chromium/GTK 运行库以及隔离图形测试组件。
yay -S --noconfirm --needed \
  base-devel binutils coreutils curl file findutils gawk grep patchelf python sed tar xz zstd \
  appstream-glib desktop-file-utils inetutils util-linux zsync \
  xorg-server xorg-server-common xorg-server-xvfb xorg-xauth \
  nss nspr alsa-lib at-spi2-core cups dbus glib2 gtk3 \
  libnotify libsecret libxss libxtst xdg-utils shared-mime-info \
  hicolor-icon-theme adwaita-icon-theme fontconfig freetype2 cairo pango gdk-pixbuf2 librsvg \
  libx11 libxext libxi libxrender libxrandr libxcomposite libxdamage libxfixes libxcursor \
  libxcb libxkbcommon libxkbcommon-x11 libxkbfile libxshmfence \
  mesa libglvnd libva libvdpau vulkan-icd-loader \
  libpulse pipewire pipewire-audio ibus \
  gnutls libgcrypt libappindicator-gtk3 libdbusmenu-gtk3 pciutils libmfx libc++

for command_name in \
  ar awk chmod curl dbus-run-session desktop-file-validate file find grep hostname \
  install ldd md5sum quick-sharun readelf readlink sed sha256sum sort stat tar timeout xvfb-run; do
  command -v "$command_name" >/dev/null 2>&1 || \
    die "构建环境缺少命令：$command_name"
done

#######################################################################
# 2. 获取飞书官方 Linux 安装包
#######################################################################

log "读取飞书官方 Linux 客户端元数据"
CLIENT_JSON="$(
  curl -fsSL \
    --retry 5 \
    --retry-all-errors \
    --retry-delay 2 \
    --connect-timeout 20 \
    -A 'Mozilla/5.0' \
    "$CLIENT_API"
)"
[[ -n "$CLIENT_JSON" ]] || die "飞书官方客户端元数据为空。"

PACKAGE_INFO="$(
  printf '%s' "$CLIENT_JSON" | python3 -c '
import json
import os
import re
import sys
from urllib.parse import urlsplit

payload = json.load(sys.stdin)
data = payload.get("data") or {}
url = data.get("download_link") or ""
digest = str(data.get("hash") or "").strip().lower()
version_number = str(data.get("version_number") or "")

parsed = urlsplit(url)
host = (parsed.hostname or "").lower()
filename = os.path.basename(parsed.path)
match = re.fullmatch(r"Feishu-linux_x64-([0-9]+(?:\.[0-9]+)+)\.deb", filename)

if parsed.scheme != "https":
    raise SystemExit("官方 download_link 不是 HTTPS")
if not (host == "feishucdn.com" or host.endswith(".feishucdn.com")):
    raise SystemExit(f"官方 download_link 域名异常: {host}")
if match is None:
    raise SystemExit(f"官方 x86_64 DEB 文件名异常: {filename}")
if not re.fullmatch(r"(?:[0-9a-f]{32}|[0-9a-f]{64})", digest):
    raise SystemExit("官方 hash 格式异常")

version = match.group(1)
if version_number and version not in version_number:
    raise SystemExit(f"版本字段与下载文件不一致: {version_number} / {version}")

print(url + "\t" + digest + "\t" + version)
'
)"
IFS=$'\t' read -r PACKAGE_URL EXPECTED_HASH VERSION <<< "$PACKAGE_INFO"
[[ -n "$PACKAGE_URL" && -n "$EXPECTED_HASH" && -n "$VERSION" ]] || \
  die "无法解析飞书官方下载信息。"
readonly PACKAGE_URL EXPECTED_HASH VERSION

log "下载飞书官方 DEB：$VERSION"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  -A 'Mozilla/5.0' \
  "$PACKAGE_URL" \
  -o "$PACKAGE_FILE"
[[ -s "$PACKAGE_FILE" ]] || die "飞书官方下载文件为空。"
file "$PACKAGE_FILE" | grep -q 'Debian binary package' || \
  die "飞书官方下载文件不是 Debian 软件包。"

case "${#EXPECTED_HASH}" in
  32)
    ACTUAL_HASH="$(md5sum "$PACKAGE_FILE" | awk '{print $1}')"
    ;;
  64)
    ACTUAL_HASH="$(sha256sum "$PACKAGE_FILE" | awk '{print $1}')"
    ;;
  *)
    die "不支持的官方 hash 长度：${#EXPECTED_HASH}"
    ;;
esac
[[ "$ACTUAL_HASH" == "$EXPECTED_HASH" ]] || \
  die "飞书官方包校验失败：期望 $EXPECTED_HASH，实际 $ACTUAL_HASH"
sha256sum "$PACKAGE_FILE"

mkdir -p "$DEB_EXTRACT_DIR"
(
  cd "$DEB_EXTRACT_DIR"
  ar x "$PACKAGE_FILE"
)

shopt -s nullglob
control_archives=("$DEB_EXTRACT_DIR"/control.tar.*)
data_archives=("$DEB_EXTRACT_DIR"/data.tar.*)
shopt -u nullglob
[[ ${#control_archives[@]} -eq 1 ]] || \
  die "官方 DEB 中应且只能有一个 control.tar.*。"
[[ ${#data_archives[@]} -eq 1 ]] || \
  die "官方 DEB 中应且只能有一个 data.tar.*。"

DEB_VERSION="$(
  tar -xOf "${control_archives[0]}" ./control \
    | awk '$1 == "Version:" {print $2; exit}'
)"
DEB_ARCH="$(
  tar -xOf "${control_archives[0]}" ./control \
    | awk '$1 == "Architecture:" {print $2; exit}'
)"
[[ "$DEB_ARCH" == amd64 ]] || die "官方 DEB 架构异常：$DEB_ARCH"
[[ "$DEB_VERSION" == "$VERSION" || "$DEB_VERSION" == "$VERSION-"* ]] || \
  die "官方 DEB 版本与 API 不一致：API=$VERSION，DEB=$DEB_VERSION"
readonly DEB_VERSION DEB_ARCH

tar -xf "${data_archives[0]}" -C "$PACKAGE_ROOT"

#######################################################################
# 3. 组装飞书官方运行目录
#######################################################################

readonly SOURCE_APP_ROOT="$PACKAGE_ROOT/opt/bytedance/feishu"
readonly SOURCE_DESKTOP="$PACKAGE_ROOT/usr/share/applications/bytedance-feishu.desktop"
[[ -d "$SOURCE_APP_ROOT" ]] || die "官方包缺少 /opt/bytedance/feishu。"
[[ -x "$SOURCE_APP_ROOT/bytedance-feishu" ]] || die "官方包缺少 bytedance-feishu 启动器。"
[[ -x "$SOURCE_APP_ROOT/feishu" ]] || die "官方包缺少 feishu 主程序。"
[[ -f "$SOURCE_DESKTOP" ]] || die "官方包缺少 bytedance-feishu.desktop。"
file "$SOURCE_APP_ROOT/feishu" | grep -q 'ELF 64-bit' || \
  die "飞书主程序不是 64 位 ELF。"
if [[ -e "$SOURCE_APP_ROOT/vulcan/vulcan" ]]; then
  [[ -x "$SOURCE_APP_ROOT/vulcan/vulcan" ]] || die "飞书 vulcan 不可执行。"
  file "$SOURCE_APP_ROOT/vulcan/vulcan" | grep -q 'ELF 64-bit' || \
    die "飞书 vulcan 不是 64 位 ELF。"
fi

mapfile -d '' icon_candidates < <(
  find "$SOURCE_APP_ROOT" -maxdepth 1 -type f -name 'product_logo_*.png' -print0
)
[[ ${#icon_candidates[@]} -gt 0 ]] || die "官方包中未找到 product_logo_*.png。"

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
file "$SOURCE_ICON" | grep -q 'PNG image data' || die "飞书官方图标不是 PNG。"

log "复制飞书官方完整运行目录"
cp -a "$SOURCE_APP_ROOT"/. "$APP_ROOT"/

# AppImage 挂载环境不能依赖系统安装包提供的 root-owned setuid sandbox。
# 只清除 AppImage 内官方 chrome-sandbox 的 setuid/setgid 位，不修改宿主系统。
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
  -e 's|^Exec=.*|Exec=bytedance-feishu %U|' \
  -e 's|^Icon=.*|Icon=bytedance-feishu|' \
  "$BUILD_DESKTOP"
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

APPDIR="${APPDIR:-$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)}"
APP_ROOT="$APPDIR/bin"

export SHARUN_EXTRA_LIBRARY_PATH="$APP_ROOT${SHARUN_EXTRA_LIBRARY_PATH:+:$SHARUN_EXTRA_LIBRARY_PATH}"
export SHARUN_WORKING_DIR="$APP_ROOT"

cd "$APP_ROOT"
exec "$APP_ROOT/bytedance-feishu" "$@"
APPRUN_EOF
chmod 0755 "$APPDIR/AppRun.sh"
bash -n "$APPDIR/AppRun.sh"

STARTUPWMCLASS="$(awk -F= '$1 == "StartupWMClass" {print $2; exit}' "$BUILD_DESKTOP")"
STARTUPWMCLASS="${STARTUPWMCLASS:-Feishu}"
readonly STARTUPWMCLASS

export ARCH=x86_64
export VERSION
export APPNAME=Feishu
export MAIN_BIN=bytedance-feishu
export STARTUPWMCLASS
export ICON="$BUILD_ICON"
export DESKTOP="$BUILD_DESKTOP"
export OUTPATH="$DIST_DIR"
export OUTNAME=feishu.AppImage
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export DEPLOY_PIPEWIRE=1
export NO_STRIP=1

# 保持飞书官方 Electron/Chromium 私有文件的相对布局，仅让 quick-sharun
# 处理主程序、可选 vulcan 和从所有 ELF 解析到的外部系统运行库。
mapfile -t app_library_dirs < <(
  find "$APP_ROOT" -type f -printf '%h\n' | sort -u
)
[[ ${#app_library_dirs[@]} -gt 0 ]] || die "飞书官方运行目录为空。"
BUILD_LIBRARY_PATH="$(IFS=:; printf '%s' "${app_library_dirs[*]}")"
BUILD_LIBRARY_PATH="$BUILD_LIBRARY_PATH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

elf_targets=()
while IFS= read -r -d '' target; do
  if readelf -h "$target" >/dev/null 2>&1; then
    elf_targets+=("$target")
  fi
done < <(find "$APP_ROOT" -type f -print0)
[[ ${#elf_targets[@]} -gt 0 ]] || die "飞书官方运行目录中未找到 ELF 文件。"
printf 'Feishu ELF files: %s\n' "${#elf_targets[@]}"

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
[[ "$missing_dependencies" -eq 0 ]] || die "飞书官方组件仍存在缺失或 ABI 不兼容动态库。"
[[ ${#system_library_targets[@]} -gt 0 ]] || die "未解析到飞书外部系统库。"
printf 'Feishu external libraries: %s\n' "${#system_library_targets[@]}"

shopt -s nullglob
extra_runtime_targets=(
  /usr/bin/hostname
  /usr/lib/libnss*.so*
  /usr/lib/libsoftokn3.so
  /usr/lib/libfreeblpriv3.so
  /usr/lib/pkcs11/*
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so
  /usr/lib/libappindicator3.so*
  /usr/lib/libdbusmenu-gtk3.so*
)
shopt -u nullglob

quick_sharun_targets=("$APP_ROOT/feishu")
if [[ -x "$APP_ROOT/vulcan/vulcan" ]]; then
  quick_sharun_targets+=("$APP_ROOT/vulcan/vulcan")
fi

LD_LIBRARY_PATH="$BUILD_LIBRARY_PATH" quick-sharun \
  "${quick_sharun_targets[@]}" \
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
[[ -x "$VERIFY_DIR/squashfs-root/bin/bytedance-feishu" ]] || \
  die "AppImage 提取后缺少飞书启动器。"
[[ -x "$VERIFY_DIR/squashfs-root/bin/feishu" ]] || \
  die "AppImage 提取后缺少飞书主程序。"
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
  timeout 30s dbus-run-session -- \
    xvfb-run -a "$OUTFILE" --no-sandbox --disable-gpu >"$SMOKE_LOG" 2>&1
smoke_status=$?
set -e

if [[ "$smoke_status" -ne 0 && "$smoke_status" -ne 124 ]]; then
  cat "$SMOKE_LOG" >&2
  die "飞书图形启动测试异常退出，状态码：$smoke_status"
fi
if grep -Eqi \
  'error while loading shared libraries|symbol lookup error|invalid ELF header|wrong ELF class|Exec format error|Trace/breakpoint trap|Segmentation fault|Aborted \(core dumped\)|Running as root without --no-sandbox|No usable sandbox' \
  "$SMOKE_LOG"; then
  cat "$SMOKE_LOG" >&2
  die "飞书启动日志包含致命运行时错误。"
fi

rm -rf "$SMOKE_HOME" "$SMOKE_RUNTIME"
rm -f "$SMOKE_LOG"

log "已生成：$OUTFILE"
