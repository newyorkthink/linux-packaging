#!/usr/bin/env bash
# 从腾讯文档官方 latest Linux x64 DEB 提取完整 Electron 运行目录，并用 quick-sharun 重新封装为 AppImage。
# AUR tencent-docs-bin 仅作为官方来源、运行目录和依赖参考；不直接安装 AUR 包，避免 latest 下载与固定校验和不同步。
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log() {
  printf '[Tencent Docs] %s\n' "$*"
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

readonly PACKAGE_URL='https://docs.qq.com/api/package/get?channel_id=30001&version_id=latest&package_name=TencentDocs-x64.deb'
readonly SOURCE_DIR="$SCRIPT_DIR/source"
readonly PACKAGE_FILE="$SOURCE_DIR/TencentDocs-x64.deb"
readonly AR_DIR="$SOURCE_DIR/ar"
readonly PACKAGE_ROOT="$SOURCE_DIR/package"
readonly CONTROL_ROOT="$SOURCE_DIR/control"
readonly APPDIR="$SCRIPT_DIR/AppDir"
readonly APP_ROOT="$APPDIR/bin"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly OUTFILE="$DIST_DIR/tencent-docs.AppImage"
readonly VERIFY_DIR="$SCRIPT_DIR/verify"
readonly BUILD_DESKTOP="$SCRIPT_DIR/tencent-docs.desktop"
readonly BUILD_ICON="$SCRIPT_DIR/tencent-docs-build-icon"
readonly SMOKE_HOME="$SCRIPT_DIR/smoke-home"
readonly SMOKE_RUNTIME="$SCRIPT_DIR/smoke-runtime"
readonly SMOKE_LOG="$SCRIPT_DIR/tencent-docs-smoke.log"

# 每次只清理腾讯文档自己的构建目录、临时元数据和旧产物。
rm -rf \
  "$SOURCE_DIR" \
  "$APPDIR" \
  "$DIST_DIR" \
  "$VERIFY_DIR" \
  "$SMOKE_HOME" \
  "$SMOKE_RUNTIME"
rm -f "$BUILD_DESKTOP" "$SCRIPT_DIR"/tencent-docs-build-icon.* "$SMOKE_LOG"
mkdir -p "$SOURCE_DIR" "$AR_DIR" "$PACKAGE_ROOT" "$CONTROL_ROOT" "$APP_ROOT" "$DIST_DIR"

# 安装 DEB 提取、Electron 运行审计、桌面集成、Xvfb 冒烟测试以及图形/音频/输入法依赖。
yay -S --noconfirm --needed \
  base-devel binutils coreutils curl file findutils gawk grep inetutils patchelf sed \
  tar gzip xz zstd \
  appstream-glib desktop-file-utils util-linux zsync \
  xorg-server xorg-server-common xorg-server-xvfb xorg-xauth \
  nss nspr alsa-lib at-spi2-core cups dbus glib2 gtk3 pango cairo expat fontconfig freetype2 \
  libnotify libsecret shared-mime-info xdg-utils hicolor-icon-theme adwaita-icon-theme gdk-pixbuf2 librsvg \
  libx11 libxext libxi libxrender libxrandr libxcomposite libxdamage libxfixes libxss libxtst \
  libxcb libxkbcommon libxkbcommon-x11 libdrm mesa libglvnd libva libvdpau vulkan-icd-loader \
  libpulse pipewire pipewire-audio ibus python

for command_name in \
  ar awk bash chmod curl dbus-run-session desktop-file-validate file find grep hostname \
  install ldd quick-sharun readelf readlink sed sha256sum sort stat tar timeout xvfb-run python3; do
  command -v "$command_name" >/dev/null 2>&1 || \
    die "构建环境缺少命令：$command_name"
done

#######################################################################
# 2. 获取并解析腾讯官方 DEB
#######################################################################

log "下载腾讯文档官方 latest Linux x64 DEB"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  "$PACKAGE_URL" \
  -o "$PACKAGE_FILE"
[[ -s "$PACKAGE_FILE" ]] || die "腾讯官方下载文件为空。"
file "$PACKAGE_FILE" | grep -q 'Debian binary package' || \
  die "腾讯官方下载文件不是 Debian 软件包。"
sha256sum "$PACKAGE_FILE"

(
  cd "$AR_DIR"
  ar x "$PACKAGE_FILE"
)

shopt -s nullglob
control_archives=("$AR_DIR"/control.tar.*)
data_archives=("$AR_DIR"/data.tar.*)
shopt -u nullglob
[[ ${#control_archives[@]} -eq 1 ]] || die "官方 DEB 中应且只能有一个 control.tar.*。"
[[ ${#data_archives[@]} -eq 1 ]] || die "官方 DEB 中应且只能有一个 data.tar.*。"

tar -xf "${control_archives[0]}" -C "$CONTROL_ROOT"
tar -xf "${data_archives[0]}" -C "$PACKAGE_ROOT"

CONTROL_FILE="$CONTROL_ROOT/control"
[[ -f "$CONTROL_FILE" ]] || die "官方 DEB 缺少 control 元数据。"
VERSION="$(awk -F': ' '/^Version:/{print $2; exit}' "$CONTROL_FILE" | tr -d '\r')"
[[ -n "$VERSION" ]] || die "无法从官方 DEB 解析版本。"
readonly VERSION
printf 'Tencent Docs version: %s\n' "$VERSION"

readonly SOURCE_APP_ROOT="$PACKAGE_ROOT/opt/tencent/tencent-docs"
readonly MAIN_EXEC=tdappdesktop
readonly SOURCE_MAIN="$SOURCE_APP_ROOT/$MAIN_EXEC"
[[ -d "$SOURCE_APP_ROOT" ]] || die "官方包缺少 /opt/tencent/tencent-docs。"
[[ -x "$SOURCE_MAIN" ]] || die "官方包缺少可执行主程序：$SOURCE_MAIN"
file "$SOURCE_MAIN" | grep -q 'ELF 64-bit' || die "腾讯文档主程序不是 64 位 ELF。"
[[ -f "$SOURCE_APP_ROOT/resources/app.asar" || -d "$SOURCE_APP_ROOT/resources/app" ]] || \
  die "官方运行目录缺少 Electron 应用资源。"

#######################################################################
# 3. 保留官方运行目录与桌面资源
#######################################################################

# 优先使用官方 DEB 自带 desktop；若上游以后改名，只在官方包中回退查找唯一候选。
if [[ -f "$PACKAGE_ROOT/usr/share/applications/tencent-docs.desktop" ]]; then
  SOURCE_DESKTOP="$PACKAGE_ROOT/usr/share/applications/tencent-docs.desktop"
else
  mapfile -d '' desktop_candidates < <(
    find "$PACKAGE_ROOT/usr/share/applications" -maxdepth 1 -type f \
      \( -iname '*tencent*docs*.desktop' -o -iname '*tdappdesktop*.desktop' \) \
      -print0 2>/dev/null
  )
  if [[ ${#desktop_candidates[@]} -eq 1 ]]; then
    SOURCE_DESKTOP="${desktop_candidates[0]}"
  elif [[ ${#desktop_candidates[@]} -eq 0 ]]; then
    # AUR 当前单独提供 tencent-docs.desktop；若官方 DEB 本身没有 desktop，则生成等价的最小桌面入口。
    SOURCE_DESKTOP="$SOURCE_DIR/tencent-docs-upstream-fallback.desktop"
    cat > "$SOURCE_DESKTOP" <<'DESKTOP_EOF'
[Desktop Entry]
Name=Tencent Docs
Name[zh_CN]=腾讯文档
Comment=Tencent Docs
Exec=/opt/tencent/tencent-docs/tdappdesktop %U
Terminal=false
Type=Application
Icon=tencent-docs
Categories=Office;
DESKTOP_EOF
  else
    die "官方包中找到多个腾讯文档 desktop 候选，无法安全选择。"
  fi
fi
readonly SOURCE_DESKTOP

ICON_NAME="$(awk -F= '/^Icon=/{print $2; exit}' "$SOURCE_DESKTOP" | tr -d '\r')"
ICON_NAME="${ICON_NAME##*/}"
ICON_NAME="${ICON_NAME%.png}"
ICON_NAME="${ICON_NAME%.svg}"

icon_candidates=()
if [[ -n "$ICON_NAME" ]]; then
  while IFS= read -r -d '' icon_candidate; do
    icon_candidates+=("$icon_candidate")
  done < <(
    find \
      "$PACKAGE_ROOT/usr/share/icons" \
      "$PACKAGE_ROOT/usr/share/pixmaps" \
      "$SOURCE_APP_ROOT" \
      -type f \
      \( -iname "$ICON_NAME.png" -o -iname "$ICON_NAME.svg" \) \
      -print0 2>/dev/null
  )
fi
if [[ ${#icon_candidates[@]} -eq 0 ]]; then
  while IFS= read -r -d '' icon_candidate; do
    icon_candidates+=("$icon_candidate")
  done < <(
    find \
      "$PACKAGE_ROOT/usr/share/icons" \
      "$PACKAGE_ROOT/usr/share/pixmaps" \
      "$SOURCE_APP_ROOT" \
      -type f \
      \( -iname '*tencent*docs*.png' -o -iname '*tencent*docs*.svg' -o \
         -iname '*tdappdesktop*.png' -o -iname '*tdappdesktop*.svg' \) \
      -print0 2>/dev/null
  )
fi
[[ ${#icon_candidates[@]} -gt 0 ]] || die "官方包中未找到腾讯文档图标。"

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

case "${SOURCE_ICON,,}" in
  *.png) ICON_EXT=png ;;
  *.svg) ICON_EXT=svg ;;
  *) die "官方图标格式不是 PNG/SVG。" ;;
esac
readonly ICON_EXT
readonly BUILD_ICON_FILE="$BUILD_ICON.$ICON_EXT"

printf 'Tencent Docs runtime: %s\nTencent Docs desktop: %s\nTencent Docs icon: %s\n' \
  "${SOURCE_APP_ROOT#"$PACKAGE_ROOT"/}" \
  "${SOURCE_DESKTOP#"$PACKAGE_ROOT"/}" \
  "${SOURCE_ICON#"$PACKAGE_ROOT"/}"

# 保留官方 Electron 完整运行目录，不拆 app.asar，也不替换为宿主机 Electron。
cp -a "$SOURCE_APP_ROOT"/. "$APP_ROOT"/
[[ -x "$APP_ROOT/$MAIN_EXEC" ]] || die "复制后缺少腾讯文档主程序。"

# Node 原生模块由 Electron 运行时 dlopen；去掉执行位，避免 quick-sharun 把它们当独立入口包装。
find "$APP_ROOT" -type f -name '*.node' -exec chmod 0644 {} +

install -Dm0644 "$SOURCE_DESKTOP" "$BUILD_DESKTOP"
install -Dm0644 "$SOURCE_ICON" "$BUILD_ICON_FILE"
[[ "$(grep -c '^Exec=' "$BUILD_DESKTOP")" -eq 1 ]] || die "官方 desktop 的 Exec 字段数量异常。"
[[ "$(grep -c '^Icon=' "$BUILD_DESKTOP")" -eq 1 ]] || die "官方 desktop 的 Icon 字段数量异常。"

# 只把官方绝对启动路径改为 AppImage 内命令名；保留官方 Exec 行已有的其他参数和字段代码。
sed -E -i \
  -e "s|^Exec=[^[:space:]]+|Exec=$MAIN_EXEC|" \
  -e 's|^Icon=.*|Icon=tencent-docs|' \
  "$BUILD_DESKTOP"
if grep -q '^X-AppImage-Version=' "$BUILD_DESKTOP"; then
  sed -i "s|^X-AppImage-Version=.*|X-AppImage-Version=$VERSION|" "$BUILD_DESKTOP"
else
  printf 'X-AppImage-Version=%s\n' "$VERSION" >> "$BUILD_DESKTOP"
fi
desktop-file-validate "$BUILD_DESKTOP"

#######################################################################
# 4. quick-sharun 打包与运行依赖审计
#######################################################################

cat > "$APPDIR/AppRun.sh" <<APPRUN_EOF
#!/bin/sh
set -e
export SHARUN_EXTRA_LIBRARY_PATH="\$APPDIR/bin\${SHARUN_EXTRA_LIBRARY_PATH:+:\$SHARUN_EXTRA_LIBRARY_PATH}"
export SHARUN_WORKING_DIR="\$APPDIR/bin"
export GTK_IM_MODULE="\${GTK_IM_MODULE:-ibus}"
export XMODIFIERS="\${XMODIFIERS:-@im=ibus}"
cd "\$APPDIR/bin"
exec "\$APPDIR/bin/$MAIN_EXEC" "\$@"
APPRUN_EOF
chmod 0755 "$APPDIR/AppRun.sh"
bash -n "$APPDIR/AppRun.sh"

printf '%s\n' "$VERSION" > ~/version

export ARCH=x86_64
export VERSION
export APPNAME='Tencent Docs'
export MAIN_BIN="$MAIN_EXEC"
export ICON="$BUILD_ICON_FILE"
export DESKTOP="$BUILD_DESKTOP"
export OUTPATH="$DIST_DIR"
export OUTNAME=tencent-docs.AppImage
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export DEPLOY_PIPEWIRE=1
export STRACE_MODE=0
export NO_STRIP=1

elf_targets=()
while IFS= read -r -d '' target; do
  if readelf -h "$target" >/dev/null 2>&1; then
    elf_targets+=("$target")
  fi
done < <(find "$APP_ROOT" -type f -print0)
[[ ${#elf_targets[@]} -gt 0 ]] || die "官方腾讯文档运行目录中未找到 ELF 文件。"
printf 'Tencent Docs ELF files: %s\n' "${#elf_targets[@]}"

mapfile -t app_library_dirs < <(
  find "$APP_ROOT" -type f -printf '%h\n' | sort -u
)
[[ ${#app_library_dirs[@]} -gt 0 ]] || die "官方腾讯文档运行目录为空。"
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
[[ "$missing_dependencies" -eq 0 ]] || die "腾讯文档官方组件仍存在缺失或 ABI 不兼容动态库。"

shopt -s nullglob
runtime_targets=(
  /usr/bin/hostname
  /usr/lib/libnss*.so*
  /usr/lib/libsoftokn3.so
  /usr/lib/libfreeblpriv3.so
  /usr/lib/pkcs11/*
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so
)
shopt -u nullglob

LD_LIBRARY_PATH="$BUILD_LIBRARY_PATH" quick-sharun \
  "${elf_targets[@]}" \
  "${runtime_targets[@]}"

quick-sharun --make-appimage
[[ -s "$OUTFILE" ]] || die "未生成预期文件：$OUTFILE"
chmod 0755 "$OUTFILE"
sha256sum "$OUTFILE"

#######################################################################
# 5. 最终产物检查与隔离图形启动测试
#######################################################################

mkdir -p "$VERIFY_DIR"
(
  cd "$VERIFY_DIR"
  "$OUTFILE" --appimage-extract >/dev/null
)
readonly VERIFY_APPDIR="$VERIFY_DIR/squashfs-root"
[[ -x "$VERIFY_APPDIR/AppRun" ]] || die "最终 AppImage 缺少 AppRun。"
[[ -f "$VERIFY_APPDIR/tencent-docs.desktop" ]] || die "最终 AppImage 缺少 desktop 文件。"
find -H "$VERIFY_APPDIR" -type f -path '*/resources/app.asar' -print -quit | grep -q . || \
  find -H "$VERIFY_APPDIR" -type d -path '*/resources/app' -print -quit | grep -q . || \
  die "最终 AppImage 缺少 Electron 应用资源。"
find -H "$VERIFY_APPDIR" -type f -name "$MAIN_EXEC" -print -quit | grep -q . || \
  die "最终 AppImage 缺少腾讯文档主程序。"

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
printf 'Tencent Docs smoke test exit code: %s\n' "$smoke_rc"
if grep -Eqi \
  'error while loading shared libraries|cannot open shared object file|invalid ELF header|wrong ELF class|Exec format error|Trace/breakpoint trap|Segmentation fault' \
  "$SMOKE_LOG"; then
  die "腾讯文档冒烟测试检测到致命运行错误。"
fi
if [[ "$smoke_rc" -eq 124 ]]; then
  if grep -Eqi 'FATAL:' "$SMOKE_LOG"; then
    die "腾讯文档冒烟测试检测到致命运行错误。"
  fi
elif [[ "$smoke_rc" -ne 0 ]]; then
  die "腾讯文档在 Xvfb 冒烟测试中异常退出：$smoke_rc"
fi

cat > "$DIST_DIR/tencent-docs-version.txt" <<VERSION_EOF
package=tencent-docs
version=$VERSION
source=$PACKAGE_URL
method=official-deb-plus-quick-sharun
entry=opt/tencent/tencent-docs/tdappdesktop
output=$(basename "$OUTFILE")
VERSION_EOF

log "构建完成：$OUTFILE"
