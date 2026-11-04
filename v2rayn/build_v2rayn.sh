#!/usr/bin/env bash
set -Eeuo pipefail

# 当前项目目录与产物路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

APPDIR="$SCRIPT_DIR/AppDir"
DIST_DIR="$SCRIPT_DIR/dist"
SOURCE_DIR="$SCRIPT_DIR/source"
VERIFY_DIR="$SCRIPT_DIR/verify"
WORK_DIR="$SCRIPT_DIR/work"
ARCHIVE="$WORK_DIR/v2rayN-linux-64.deb"

fail() {
  echo "v2rayN build error: $*" >&2
  exit 1
}

# 只清理本项目的构建目录；AppDir 留给 quick-sharun 创建。
"$SCRIPT_DIR/../common/build/prepare_x86_64_workspace.sh" \
  "$SCRIPT_DIR" --skip-create AppDir dist source verify work
cd "$SCRIPT_DIR"

# 安装官方自包含 Avalonia 程序、短时图形检查及后续发布所需的精确依赖。
# 以前提前安装整套统一基础包会使图形检查出现 free(): invalid pointer。
"$SCRIPT_DIR/../common/arch/install_packages.sh" \
  bash curl jq github-cli dpkg file patchelf coreutils desktop-file-utils xdg-utils \
  glibc gcc-libs zlib fontconfig freetype2 \
  libx11 libxext libxrender libxrandr libxi libxcb libxfixes libxinerama \
  libxcomposite libxcursor libxdamage libxkbcommon dbus \
  xorg-server-xvfb xorg-xauth

# 固定名称的官方 DEB 提供程序、desktop 和图标；公共入口核对版本、SHA-256 与包身份。
VERSION="$("$SCRIPT_DIR/../common/github/download_latest_stable_named_asset.sh" \
  2dust/v2rayN v2rayN-linux-64.deb "$ARCHIVE" v2rayn amd64)"
"$SCRIPT_DIR/../common/archive/extract_archive.sh" "$ARCHIVE" "$SOURCE_DIR"
APP_ROOT="$SOURCE_DIR/opt/v2rayN"
MAIN_SOURCE="$APP_ROOT/v2rayN"
[[ -n "$MAIN_SOURCE" && -f "$MAIN_SOURCE" ]] || fail "v2rayN executable not found in official archive"
chmod +x "$MAIN_SOURCE"
MAIN_FILE_INFO="$(file -Lb "$MAIN_SOURCE")"
[[ "$MAIN_FILE_INFO" == *"ELF 64-bit"* && "$MAIN_FILE_INFO" == *"x86-64"* ]] || fail "unexpected v2rayN executable type: $MAIN_FILE_INFO"
[[ -d "$APP_ROOT/bin" ]] || fail "official runtime bin directory is missing"
PACKAGING_ICON="$SOURCE_DIR/usr/share/icons/hicolor/256x256/apps/v2rayn.png"
[[ -s "$PACKAGING_ICON" ]] || fail "official DEB icon is missing"

# 沿用上游 desktop；只把 DEB 专用启动器改为 AppImage 真实入口，并写入版本和窗口类。
DESKTOP_FILE="$WORK_DIR/v2rayn.desktop"
[[ -s "$SOURCE_DIR/usr/share/applications/v2rayn.desktop" ]] || fail "official DEB desktop is missing"
cp -a "$SOURCE_DIR/usr/share/applications/v2rayn.desktop" "$DESKTOP_FILE"
grep -Fxq 'Exec=v2rayn' "$DESKTOP_FILE" || fail "unexpected official DEB desktop entry"
sed -i 's/^Exec=v2rayn$/Exec=v2rayN/' "$DESKTOP_FILE"
if ! grep -q '^StartupWMClass=' "$DESKTOP_FILE"; then
  printf 'StartupWMClass=v2rayN\n' >> "$DESKTOP_FILE"
fi
printf 'X-AppImage-Version=%s\n' "$VERSION" >> "$DESKTOP_FILE"
desktop-file-validate "$DESKTOP_FILE"

# quick-sharun 使用这些变量生成桌面文件、图标关联及指定名称的最终 AppImage。
export ARCH=x86_64
export VERSION
export APPNAME="v2rayN"
export STARTUPWMCLASS="v2rayN"
export ICON="$PACKAGING_ICON"
export DESKTOP="$DESKTOP_FILE"
export OUTPATH="$DIST_DIR"
export OUTNAME="v2rayn.AppImage"

# 把真实图形主程序放在首位，避免 quick-sharun 误选其他 ELF 作为入口。
# 上游 DEB 也不扫描可选追踪库 libcoreclrtraceptprovider.so 的依赖；文件仍按原目录复制。
# 其余动态链接的 ELF 一起交给 quick-sharun 收集依赖。
ELF_INPUTS=("$MAIN_SOURCE")
while IFS= read -r -d '' candidate; do
  [[ "$candidate" == "$MAIN_SOURCE" ]] && continue
  [[ "$candidate" == "$APP_ROOT/libcoreclrtraceptprovider.so" ]] && continue
  description="$(file -Lb "$candidate")"
  if [[ "$description" == ELF* && ( "$description" == *"dynamically linked"* || "$description" == *"shared object"* ) ]]; then
    ELF_INPUTS+=("$candidate")
  fi
done < <(find "$APP_ROOT" -type f -print0)

quick-sharun "${ELF_INPUTS[@]}"

# 保留官方自包含目录的相对布局；真实文件进入 shared/bin。
# bin 也需要同一数据目录，因为 sharun 通过其中的硬链接启动主程序。
mkdir -p "$APPDIR/bin" "$APPDIR/shared/bin"
cp -an "$APP_ROOT"/. "$APPDIR/bin"/
cp -an "$APP_ROOT"/. "$APPDIR/shared/bin"/

# 官方 DEB 启动器先进入 /opt/v2rayN；AppImage 保持同等工作目录和 PATH。
touch "$APPDIR/.env"
if ! grep -Fxq 'SHARUN_WORKING_DIR=${SHARUN_DIR}/bin' "$APPDIR/.env"; then
  printf '%s\n' 'SHARUN_WORKING_DIR=${SHARUN_DIR}/bin' >> "$APPDIR/.env"
fi
if ! grep -Fxq 'PATH=${SHARUN_DIR}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' "$APPDIR/.env"; then
  printf '%s\n' 'PATH=${SHARUN_DIR}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' >> "$APPDIR/.env"
fi
printf '%s\n' 'v2rayN' > "$APPDIR/.app"

# 生成最终 AppImage；公共入口核对产物并写出发布用的 SHA-256 文件。
quick-sharun --make-appimage
APPIMAGE="$DIST_DIR/v2rayn.AppImage"
"$SCRIPT_DIR/../common/build/check_appimage_artifact.sh" \
  "$APPIMAGE" "$DIST_DIR/v2rayn.AppImage.sha256"

# 仅由需要的应用显式调用公共图形检查；保留原来的 20 秒、会话顺序与致命日志特征。
# 不检查窗口标题，成功条件仍是进程持续运行到 timeout 返回 124。
"$SCRIPT_DIR/../common/gui/check_appimage_gui.sh" \
  "$APPIMAGE" 20 "$VERIFY_DIR" timeout-dbus-xvfb timeout-only \
  'Unhandled exception|DllNotFoundException|error while loading shared libraries|cannot open shared object file|symbol lookup error|invalid ELF header|Segmentation fault|core dumped|Exec format error|wrong ELF class' \
  ''

# 检查完成后统一写入版本文件并输出原有成功提示。
"$SCRIPT_DIR/../common/build/finish_appimage_build.sh" \
  "$VERSION" "$DIST_DIR/version.txt" "v2rayN AppImage build and smoke test passed."
