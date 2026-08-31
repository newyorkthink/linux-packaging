#!/usr/bin/env bash
# 从百度官方 Linux 客户端元数据动态获取当前版本，并从百度官方 pkg-ant 直链下载 x86_64 DEB。
# 保留官方 /opt/baidunetdisk 运行目录，不再让 quick-sharun / linuxdeploy 改写官方 ELF；仅在外层补充运行库并用官方 appimagetool 封装。
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log() {
  printf '[BaiduNetDisk] %s\n' "$*"
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

readonly CLIENT_API='https://pan.baidu.com/disk/cmsdata?do=client'
readonly APPIMAGETOOL_URL='https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage'
readonly SOURCE_DIR="$SCRIPT_DIR/source"
readonly PACKAGE_ROOT="$SOURCE_DIR/package"
readonly PACKAGE_FILE="$SOURCE_DIR/baidunetdisk.deb"
readonly DEB_EXTRACT_DIR="$SOURCE_DIR/deb"
readonly APPIMAGETOOL="$SOURCE_DIR/appimagetool-x86_64.AppImage"
readonly APPDIR="$SCRIPT_DIR/AppDir"
readonly APP_ROOT="$APPDIR/opt/baidunetdisk"
readonly RUNTIME_LIB="$APPDIR/usr/lib/baidunetdisk-runtime"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly OUTFILE="$DIST_DIR/baidunetdisk.AppImage"
readonly VERIFY_DIR="$SCRIPT_DIR/verify"
readonly SMOKE_HOME="$SCRIPT_DIR/smoke-home"
readonly SMOKE_RUNTIME="$SCRIPT_DIR/smoke-runtime"
readonly SMOKE_LOG_1="$SCRIPT_DIR/baidunetdisk-smoke-1.log"
readonly SMOKE_LOG_2="$SCRIPT_DIR/baidunetdisk-smoke-2.log"

# 每次只清理百度网盘自己的构建目录、临时元数据和旧产物。
rm -rf \
  "$SOURCE_DIR" \
  "$APPDIR" \
  "$DIST_DIR" \
  "$VERIFY_DIR" \
  "$SMOKE_HOME" \
  "$SMOKE_RUNTIME"
rm -f "$SMOKE_LOG_1" "$SMOKE_LOG_2"
mkdir -p "$SOURCE_DIR" "$PACKAGE_ROOT" "$APP_ROOT" "$RUNTIME_LIB" "$DIST_DIR"

# 这些软件包只安装到 GitHub Actions 临时 Arch 容器，用于构建、依赖解析和隔离启动测试。
yay -S --noconfirm --needed \
  base-devel binutils coreutils curl file findutils gawk grep python sed tar \
  appstream-glib desktop-file-utils util-linux \
  xorg-server xorg-server-common xorg-server-xvfb xorg-xauth \
  nss nspr alsa-lib at-spi2-core cups dbus glib2 gtk3 gtkmm \
  libnotify libsecret libxss libxtst xdg-utils shared-mime-info \
  hicolor-icon-theme adwaita-icon-theme fontconfig freetype2 cairo pango gdk-pixbuf2 librsvg \
  libx11 libxext libxi libxrender libxrandr libxcomposite libxdamage libxfixes \
  libxcb libxkbcommon libxkbcommon-x11 mesa libglvnd libva libvdpau vulkan-icd-loader \
  libpulse pipewire-audio ibus

for command_name in \
  ar awk chmod curl dbus-run-session desktop-file-validate file find grep \
  install ldd readelf readlink sed sha256sum sort stat tar timeout xvfb-run; do
  command -v "$command_name" >/dev/null 2>&1 || \
    die "构建环境缺少命令：$command_name"
done

#######################################################################
# 2. 获取百度官方 Linux 安装包
#######################################################################

log "读取百度官方 Linux 客户端版本"
CLIENT_JSON="$(
  curl -fsSL \
    --retry 5 \
    --retry-all-errors \
    --retry-delay 2 \
    --connect-timeout 20 \
    "$CLIENT_API"
)"
[[ -n "$CLIENT_JSON" ]] || die "百度官方客户端元数据为空。"

RAW_VERSION="$(
  printf '%s' "$CLIENT_JSON" | python3 -c '
import json, sys
payload = json.load(sys.stdin)
linux = payload.get("linux") or {}
print(linux.get("version") or "")
'
)"
if [[ "$RAW_VERSION" =~ ^(百度网盘Linux电脑客户端)?V?([0-9]+(\.[0-9]+)+)$ ]]; then
  VERSION="${BASH_REMATCH[2]}"
else
  die "百度官方元数据中的版本格式异常：$RAW_VERSION"
fi
readonly RAW_VERSION VERSION
readonly PACKAGE_URL="https://pkg-ant.baidu.com/issue/netdisk/LinuxGuanjia/$VERSION/baidunetdisk_${VERSION}_amd64.deb"

log "下载百度网盘官方 DEB：$VERSION"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  "$PACKAGE_URL" \
  -o "$PACKAGE_FILE"
[[ -s "$PACKAGE_FILE" ]] || die "百度官方下载文件为空。"
file "$PACKAGE_FILE" | grep -q 'Debian binary package' || \
  die "百度官方下载文件不是 Debian 软件包。"
sha256sum "$PACKAGE_FILE"

mkdir -p "$DEB_EXTRACT_DIR"
(
  cd "$DEB_EXTRACT_DIR"
  ar x "$PACKAGE_FILE"
)
shopt -s nullglob
data_archives=("$DEB_EXTRACT_DIR"/data.tar.*)
shopt -u nullglob
[[ ${#data_archives[@]} -eq 1 ]] || \
  die "官方 DEB 中应且只能有一个 data.tar.*。"
tar -xf "${data_archives[0]}" -C "$PACKAGE_ROOT"

readonly SOURCE_APP_ROOT="$PACKAGE_ROOT/opt/baidunetdisk"
[[ -d "$SOURCE_APP_ROOT" ]] || die "官方包缺少 /opt/baidunetdisk。"
[[ -x "$SOURCE_APP_ROOT/baidunetdisk" ]] || die "官方包缺少可执行主程序。"
file "$SOURCE_APP_ROOT/baidunetdisk" | grep -q 'ELF 64-bit' || \
  die "百度网盘主程序不是 64 位 ELF。"

#######################################################################
# 3. 原样保留官方运行目录与桌面资源
#######################################################################

if [[ -f "$PACKAGE_ROOT/usr/share/applications/baidunetdisk.desktop" ]]; then
  SOURCE_DESKTOP="$PACKAGE_ROOT/usr/share/applications/baidunetdisk.desktop"
else
  mapfile -d '' desktop_candidates < <(
    find "$PACKAGE_ROOT/usr/share/applications" \
      -maxdepth 1 -type f -iname '*baidu*netdisk*.desktop' -print0 2>/dev/null
  )
  [[ ${#desktop_candidates[@]} -eq 1 ]] || \
    die "官方包中无法唯一定位百度网盘 desktop 文件。"
  SOURCE_DESKTOP="${desktop_candidates[0]}"
fi
readonly SOURCE_DESKTOP

mapfile -d '' icon_candidates < <(
  find \
    "$PACKAGE_ROOT/usr/share/icons" \
    "$PACKAGE_ROOT/usr/share/pixmaps" \
    "$SOURCE_APP_ROOT" \
    -type f \
    \( -iname '*baidunetdisk*.png' -o -iname '*baidunetdisk*.svg' -o \
       -iname '*baidu*netdisk*.png' -o -iname '*baidu*netdisk*.svg' \) \
    -print0 2>/dev/null
)
[[ ${#icon_candidates[@]} -gt 0 ]] || die "官方包中未找到百度网盘图标。"

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
readonly ROOT_ICON="$APPDIR/baidunetdisk.$ICON_EXT"

log "原样复制官方 /opt/baidunetdisk"
cp -a "$SOURCE_APP_ROOT"/. "$APP_ROOT"/

# 对官方运行目录做内容、文件类型、权限位和符号链接目标校验。
verify_official_tree() {
  local expected_root="$1"
  local actual_root="$2"

  python3 - "$expected_root" "$actual_root" <<'PY'
import hashlib
import os
import stat
import sys

expected_root, actual_root = map(os.path.abspath, sys.argv[1:])

def snapshot(root):
    result = {}
    for current, dirs, files in os.walk(root, topdown=True, followlinks=False):
        names = list(dirs) + list(files)
        for name in names:
            path = os.path.join(current, name)
            rel = os.path.relpath(path, root)
            st = os.lstat(path)
            mode = stat.S_IMODE(st.st_mode)
            if stat.S_ISLNK(st.st_mode):
                result[rel] = ("link", mode, os.readlink(path))
                if name in dirs:
                    dirs.remove(name)
            elif stat.S_ISDIR(st.st_mode):
                result[rel] = ("dir", mode)
            elif stat.S_ISREG(st.st_mode):
                digest = hashlib.sha256()
                with open(path, "rb") as handle:
                    for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                        digest.update(chunk)
                result[rel] = ("file", mode, st.st_size, digest.hexdigest())
            else:
                result[rel] = ("other", mode, stat.S_IFMT(st.st_mode))
    return result

expected = snapshot(expected_root)
actual = snapshot(actual_root)
if expected != actual:
    expected_keys = set(expected)
    actual_keys = set(actual)
    for rel in sorted(expected_keys - actual_keys):
        print(f"missing: {rel}", file=sys.stderr)
    for rel in sorted(actual_keys - expected_keys):
        print(f"unexpected: {rel}", file=sys.stderr)
    for rel in sorted(expected_keys & actual_keys):
        if expected[rel] != actual[rel]:
            print(f"changed: {rel}", file=sys.stderr)
            print(f"  expected={expected[rel]}", file=sys.stderr)
            print(f"  actual={actual[rel]}", file=sys.stderr)
    raise SystemExit(1)
PY
}

verify_official_tree "$SOURCE_APP_ROOT" "$APP_ROOT"

install -Dm0644 "$SOURCE_DESKTOP" "$APPDIR/baidunetdisk.desktop"
install -Dm0644 "$SOURCE_DESKTOP" "$APPDIR/usr/share/applications/baidunetdisk.desktop"
install -Dm0644 "$SOURCE_ICON" "$ROOT_ICON"
if [[ "$ICON_EXT" == svg ]]; then
  install -Dm0644 "$SOURCE_ICON" \
    "$APPDIR/usr/share/icons/hicolor/scalable/apps/baidunetdisk.svg"
else
  install -Dm0644 "$SOURCE_ICON" \
    "$APPDIR/usr/share/icons/hicolor/256x256/apps/baidunetdisk.png"
fi

for desktop_file in \
  "$APPDIR/baidunetdisk.desktop" \
  "$APPDIR/usr/share/applications/baidunetdisk.desktop"; do
  [[ "$(grep -c '^Exec=' "$desktop_file")" -eq 1 ]] || \
    die "官方 desktop 的 Exec 字段数量异常：$desktop_file"
  [[ "$(grep -c '^Icon=' "$desktop_file")" -eq 1 ]] || \
    die "官方 desktop 的 Icon 字段数量异常：$desktop_file"
  sed -i \
    -e 's|^Exec=.*|Exec=baidunetdisk %U|' \
    -e 's|^Icon=.*|Icon=baidunetdisk|' \
    "$desktop_file"
  if ! grep -q '^StartupWMClass=' "$desktop_file"; then
    printf 'StartupWMClass=baidunetdisk\n' >> "$desktop_file"
  fi
  if ! grep -q '^X-AppImage-Version=' "$desktop_file"; then
    printf 'X-AppImage-Version=%s\n' "$VERSION" >> "$desktop_file"
  fi
  desktop-file-validate "$desktop_file"
done
ln -sfn "baidunetdisk.$ICON_EXT" "$APPDIR/.DirIcon"

#######################################################################
# 4. 只补充外部系统动态库，不改写官方 ELF
#######################################################################

is_excluded_runtime_library() {
  case "$1" in
    ld-linux*.so*|libc.so.*|libm.so.*|libpthread.so.*|libdl.so.*|librt.so.*|\
    libresolv.so.*|libutil.so.*|libnss_*.so.*|libanl.so.*|libthread_db.so.*|\
    libgcc_s.so.*|libstdc++.so.*|\
    libGL.so.*|libEGL.so.*|libGLX.so.*|libOpenGL.so.*|libvulkan.so.*|\
    libdrm.so.*|libgbm.so.*|\
    libcrypto.so.*|libssl.so.*|libsqlite3.so.*|libsqlcipher.so.*)
      return 0
      ;;
  esac
  return 1
}

copy_runtime_library() {
  local source="$1"
  local source_name real real_name existing_hash source_hash

  [[ -e "$source" ]] || return 0
  source_name="$(basename -- "$source")"
  is_excluded_runtime_library "$source_name" && return 0

  real="$(readlink -f -- "$source")"
  [[ -f "$real" ]] || return 0
  real_name="$(basename -- "$real")"
  is_excluded_runtime_library "$real_name" && return 0

  if [[ -e "$RUNTIME_LIB/$real_name" ]]; then
    existing_hash="$(sha256sum "$RUNTIME_LIB/$real_name" | awk '{print $1}')"
    source_hash="$(sha256sum "$real" | awk '{print $1}')"
    [[ "$existing_hash" == "$source_hash" ]] || \
      die "运行库 basename 冲突：$real_name"
  else
    cp -L "$real" "$RUNTIME_LIB/$real_name"
    chmod 0755 "$RUNTIME_LIB/$real_name"
  fi

  if [[ "$source_name" != "$real_name" ]]; then
    ln -sfn "$real_name" "$RUNTIME_LIB/$source_name"
  fi
}

collect_runtime_dependencies() {
  local target="$1"
  local target_library_path dependencies dependency_path

  readelf -h "$target" >/dev/null 2>&1 || return 0
  target_library_path="$(dirname -- "$target"):$APP_ROOT:$RUNTIME_LIB"
  dependencies="$(
    LD_LIBRARY_PATH="$target_library_path${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
      ldd "$target" 2>&1 || true
  )"

  if grep -Eq 'not found|version .* not found' <<<"$dependencies"; then
    printf '缺失/不兼容依赖文件：%s\n%s\n' "$target" "$dependencies" >&2
    return 1
  fi

  while IFS= read -r dependency_path; do
    dependency_path="$(readlink -f -- "$dependency_path")"
    [[ -f "$dependency_path" ]] || continue
    [[ "$dependency_path" != "$APP_ROOT/"* ]] || continue
    [[ "$dependency_path" != "$RUNTIME_LIB/"* ]] || continue
    copy_runtime_library "$dependency_path"
  done < <(
    awk '
      $2 == "=>" && $3 ~ /^\// {print $3; next}
      $1 ~ /^\// {print $1}
    ' <<<"$dependencies" | sort -u
  )
}

log "扫描官方 ELF 的外部依赖"
while IFS= read -r -d '' target; do
  collect_runtime_dependencies "$target" || \
    die "百度网盘官方组件仍存在缺失或 ABI 不兼容动态库。"
done < <(find "$APP_ROOT" -type f -print0)

# 再扫描复制进来的系统库，补齐递归依赖；循环到文件数量不再增长。
previous_count=-1
while true; do
  current_count="$(find "$RUNTIME_LIB" -type f -o -type l | wc -l)"
  [[ "$current_count" != "$previous_count" ]] || break
  previous_count="$current_count"

  while IFS= read -r -d '' target; do
    collect_runtime_dependencies "$target" || \
      die "百度网盘补充运行库仍存在缺失或 ABI 不兼容动态库。"
  done < <(find "$RUNTIME_LIB" -type f -print0)
done

# NSS/NSPR 的部分组件通过 dlopen 加载，补充主动态链接扫描无法发现的同版本组件。
shopt -s nullglob
for runtime_file in \
  /usr/lib/libfreebl3.so \
  /usr/lib/libfreeblpriv3.so \
  /usr/lib/libnspr4.so \
  /usr/lib/libnss3.so \
  /usr/lib/libnssckbi.so \
  /usr/lib/libnssdbm3.so \
  /usr/lib/libnssutil3.so \
  /usr/lib/libplc4.so \
  /usr/lib/libplds4.so \
  /usr/lib/libsmime3.so \
  /usr/lib/libsoftokn3.so \
  /usr/lib/libssl3.so; do
  copy_runtime_library "$runtime_file"
done
shopt -u nullglob

#######################################################################
# 5. 外层启动器与 AppImage 封装
#######################################################################

install -d "$APPDIR/usr/bin"
cat > "$APPDIR/usr/bin/baidunetdisk" <<'APPRUN_EOF'
#!/bin/sh
set -e

APPDIR="${APPDIR:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
APP_ROOT="$APPDIR/opt/baidunetdisk"
RUNTIME_LIB="$APPDIR/usr/lib/baidunetdisk-runtime"

export PATH="$APPDIR/usr/bin:${PATH:-/usr/bin:/bin}"
export LD_LIBRARY_PATH="$APP_ROOT:$RUNTIME_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

cd "$APP_ROOT"
exec "$APP_ROOT/baidunetdisk" --no-sandbox "$@"
APPRUN_EOF
chmod 0755 "$APPDIR/usr/bin/baidunetdisk"
ln -sfn usr/bin/baidunetdisk "$APPDIR/AppRun"
bash -n "$APPDIR/usr/bin/baidunetdisk"

# 最终封装前再次确认官方目录没有被依赖收集逻辑改写。
verify_official_tree "$SOURCE_APP_ROOT" "$APP_ROOT"

log "下载官方 appimagetool"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  "$APPIMAGETOOL_URL" \
  -o "$APPIMAGETOOL"
[[ -s "$APPIMAGETOOL" ]] || die "appimagetool 下载为空。"
chmod 0755 "$APPIMAGETOOL"
sha256sum "$APPIMAGETOOL"

log "使用官方 appimagetool 封装 AppDir"
ARCH=x86_64 \
VERSION="$VERSION" \
APPIMAGE_EXTRACT_AND_RUN=1 \
  "$APPIMAGETOOL" "$APPDIR" "$OUTFILE"

#######################################################################
# 6. AppImage 产物完整性验证
#######################################################################

[[ -s "$OUTFILE" ]] || die "未生成预期文件：$OUTFILE"
chmod 0755 "$OUTFILE"
file "$OUTFILE"
"$OUTFILE" --appimage-version >/dev/null
sha256sum "$OUTFILE" > "$OUTFILE.sha256"

log "验证 AppImage 可提取且官方目录仍保持原样"
mkdir -p "$VERIFY_DIR"
(
  cd "$VERIFY_DIR"
  "$OUTFILE" --appimage-extract >/dev/null
)
readonly VERIFY_ROOT="$VERIFY_DIR/squashfs-root"
[[ -x "$VERIFY_ROOT/AppRun" ]] || die "AppImage 提取后缺少 AppRun。"
[[ -x "$VERIFY_ROOT/opt/baidunetdisk/baidunetdisk" ]] || \
  die "AppImage 提取后缺少百度网盘主程序。"
verify_official_tree "$SOURCE_APP_ROOT" "$VERIFY_ROOT/opt/baidunetdisk"

verify_dependencies="$(
  LD_LIBRARY_PATH="$VERIFY_ROOT/opt/baidunetdisk:$VERIFY_ROOT/usr/lib/baidunetdisk-runtime" \
    ldd "$VERIFY_ROOT/opt/baidunetdisk/baidunetdisk" 2>&1 || true
)"
printf '%s\n' "$verify_dependencies"
if grep -Eq 'not found|version .* not found' <<<"$verify_dependencies"; then
  die "最终 AppImage 主程序仍存在缺失或 ABI 不兼容动态库。"
fi
rm -rf "$VERIFY_DIR"

#######################################################################
# 7. 同一数据目录连续两次隔离启动测试
#######################################################################

log "执行同一隔离 HOME 的连续两次 Xvfb 图形启动测试"
mkdir -p \
  "$SMOKE_HOME/.config" \
  "$SMOKE_HOME/.cache" \
  "$SMOKE_HOME/.local/share" \
  "$SMOKE_RUNTIME"
chmod 0700 "$SMOKE_RUNTIME"

run_smoke_test() {
  local pass="$1"
  local log_file="$2"
  local smoke_status

  set +e
  HOME="$SMOKE_HOME" \
  XDG_CONFIG_HOME="$SMOKE_HOME/.config" \
  XDG_CACHE_HOME="$SMOKE_HOME/.cache" \
  XDG_DATA_HOME="$SMOKE_HOME/.local/share" \
  XDG_RUNTIME_DIR="$SMOKE_RUNTIME" \
  APPIMAGE_EXTRACT_AND_RUN=1 \
    timeout 25s dbus-run-session -- \
      xvfb-run -a "$OUTFILE" --disable-gpu >"$log_file" 2>&1
  smoke_status=$?
  set -e

  printf 'BaiduNetDisk smoke pass %s exit code: %s\n' "$pass" "$smoke_status"

  if [[ "$smoke_status" -ne 0 && "$smoke_status" -ne 124 ]]; then
    cat "$log_file" >&2
    die "百度网盘第 $pass 次图形启动测试异常退出，状态码：$smoke_status"
  fi

  if grep -Eqi \
    'error while loading shared libraries|symbol lookup error|invalid ELF header|wrong ELF class|Exec format error|Trace/breakpoint trap|Segmentation fault|Aborted \(core dumped\)|sqlcipher_page_cipher: hmac check failed|sqlite3codec: error decrypting|sqlcipher_codec_ctx_set_error' \
    "$log_file"; then
    cat "$log_file" >&2
    die "百度网盘第 $pass 次启动日志包含致命运行时错误。"
  fi
}

run_smoke_test 1 "$SMOKE_LOG_1"
run_smoke_test 2 "$SMOKE_LOG_2"

rm -rf "$SMOKE_HOME" "$SMOKE_RUNTIME"
rm -f "$SMOKE_LOG_1" "$SMOKE_LOG_2"

log "已生成：$OUTFILE"
