#!/usr/bin/env bash
set -Eeuo pipefail

# 只在当前项目目录内准备构建目录，避免清理命令误删其他路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

APPDIR="$SCRIPT_DIR/AppDir"
DIST_DIR="$SCRIPT_DIR/dist"
SOURCE_DIR="$SCRIPT_DIR/source"
VERIFY_DIR="$SCRIPT_DIR/verify"
WORK_DIR="$SCRIPT_DIR/work"
ARCHIVE="$WORK_DIR/v2rayN-linux-64.zip"
RELEASE_JSON="$WORK_DIR/release.json"

fail() {
  echo "v2rayN build error: $*" >&2
  exit 1
}

clean_project_dir() {
  local target="$1"
  case "$target" in
    "$SCRIPT_DIR"/*) rm -rf -- "$target" ;;
    *) fail "refusing to remove path outside project: $target" ;;
  esac
}

# 官方资产与打包目标均为 x86_64；构建前先拒绝其他架构。
[[ "$(uname -m)" == "x86_64" ]] || fail "only x86_64 is supported"

cd "$SCRIPT_DIR"
for target in "$APPDIR" "$DIST_DIR" "$SOURCE_DIR" "$VERIFY_DIR" "$WORK_DIR"; do
  clean_project_dir "$target"
done
mkdir -p "$DIST_DIR" "$SOURCE_DIR" "$VERIFY_DIR" "$WORK_DIR"

# 安装官方自包含 Avalonia 程序所需的构建与运行库，以及短时图形启动检查所需的虚拟显示组件。
# 统一基础包必须等图形检查结束后再安装，避免改变依赖收集和启动环境。
yay -S --noconfirm --needed \
  bash curl jq unzip file patchelf coreutils desktop-file-utils xdg-utils \
  glibc gcc-libs zlib fontconfig freetype2 \
  libx11 libxext libxrender libxrandr libxi libxcb libxfixes libxinerama \
  libxcomposite libxcursor libxdamage libxkbcommon dbus \
  xorg-server-xvfb xorg-xauth

# 读取官方最新稳定 Release，取得版本、资产地址和官方 SHA-256。
curl --fail --silent --show-error --location \
  --retry 3 --retry-delay 2 --connect-timeout 20 --max-time 120 \
  https://api.github.com/repos/2dust/v2rayN/releases/latest \
  -o "$RELEASE_JSON"

TAG="$(jq -er 'select(.draft == false and .prerelease == false) | .tag_name' "$RELEASE_JSON")"
# 只接受稳定版标签和指定的 Linux x64 资产，不固定目标应用版本。
[[ "$TAG" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z]+)*$ ]] || fail "unexpected stable release tag: $TAG"
VERSION="${TAG#v}"
ASSET_NAME="v2rayN-linux-64.zip"
ASSET_URL="$(jq -er --arg name "$ASSET_NAME" '.assets[] | select(.name == $name) | .browser_download_url' "$RELEASE_JSON")"
ASSET_ID="$(jq -er --arg name "$ASSET_NAME" '.assets[] | select(.name == $name) | .id' "$RELEASE_JSON")"
ASSET_DIGEST="$(jq -er --arg name "$ASSET_NAME" '.assets[] | select(.name == $name) | .digest' "$RELEASE_JSON")"

case "$ASSET_URL" in
  https://github.com/2dust/v2rayN/releases/download/*/v2rayN-linux-64.zip) ;;
  *) fail "unexpected release asset URL: $ASSET_URL" ;;
esac
[[ "$ASSET_DIGEST" =~ ^sha256:[0-9a-fA-F]{64}$ ]] || fail "missing or invalid GitHub release SHA-256 digest"

# 优先下载官方资产直链；遇到直链 403 等失败时，使用同一资产 ID 和 GH_TOKEN 回退。
if ! curl --fail --show-error --location \
  --retry 3 --retry-delay 2 --connect-timeout 20 --max-time 900 \
  "$ASSET_URL" -o "$ARCHIVE"; then
  rm -f "$ARCHIVE"
  [[ -n "${GH_TOKEN:-}" ]] || fail "official release asset download failed and GH_TOKEN is unavailable"
  curl --fail --show-error --location \
    --retry 3 --retry-delay 2 --connect-timeout 20 --max-time 900 \
    -H 'Accept: application/octet-stream' \
    -H "Authorization: Bearer $GH_TOKEN" \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    "https://api.github.com/repos/2dust/v2rayN/releases/assets/$ASSET_ID" \
    -o "$ARCHIVE"
fi

# 下载完成后必须核对官方摘要，不能把损坏或不匹配的归档用于打包。
EXPECTED_SHA256="${ASSET_DIGEST#sha256:}"
ACTUAL_SHA256="$(sha256sum "$ARCHIVE" | cut -d' ' -f1)"
[[ "${ACTUAL_SHA256,,}" == "${EXPECTED_SHA256,,}" ]] || fail "release archive SHA-256 mismatch"
printf 'v2rayN version: %s\nsource sha256: %s\n' "$VERSION" "$ACTUAL_SHA256"

# 解压官方自包含包，定位真实的 x86_64 图形程序及相邻运行目录。
unzip -q "$ARCHIVE" -d "$SOURCE_DIR"
MAIN_SOURCE="$(find "$SOURCE_DIR" -type f -name 'v2rayN' -print -quit)"
[[ -n "$MAIN_SOURCE" && -f "$MAIN_SOURCE" ]] || fail "v2rayN executable not found in official archive"
chmod +x "$MAIN_SOURCE"
APP_ROOT="$(dirname -- "$MAIN_SOURCE")"
MAIN_FILE_INFO="$(file -Lb "$MAIN_SOURCE")"
[[ "$MAIN_FILE_INFO" == *"ELF 64-bit"* && "$MAIN_FILE_INFO" == *"x86-64"* ]] || fail "unexpected v2rayN executable type: $MAIN_FILE_INFO"
[[ -d "$APP_ROOT/bin" ]] || fail "official runtime bin directory is missing"
ICON_SOURCE="$APP_ROOT/v2rayN.png"
[[ -s "$ICON_SOURCE" ]] || fail "official v2rayN.png icon is missing"

# 统一为 desktop 中的 Icon=v2rayn，避免大小写不一致导致菜单图标丢失。
PACKAGING_ICON="$WORK_DIR/v2rayn.png"
cp -a "$ICON_SOURCE" "$PACKAGING_ICON"

# 写入 AppImage 的桌面入口；版本与本次官方 Release 保持一致。
DESKTOP_FILE="$WORK_DIR/v2rayn.desktop"
cat > "$DESKTOP_FILE" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=v2rayN
Comment=v2rayN for Linux
Exec=v2rayN
Icon=v2rayn
Terminal=false
Categories=Network;
StartupWMClass=v2rayN
DESKTOP
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
# 其余动态链接的 ELF 一起交给 quick-sharun 收集依赖。
ELF_INPUTS=("$MAIN_SOURCE")
while IFS= read -r -d '' candidate; do
  [[ "$candidate" == "$MAIN_SOURCE" ]] && continue
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

# 官方 Debian 启动器先进入 /opt/v2rayN；在 AppImage 中保持同等工作目录和 PATH。
touch "$APPDIR/.env"
if ! grep -Fxq 'SHARUN_WORKING_DIR=${SHARUN_DIR}/bin' "$APPDIR/.env"; then
  printf '%s\n' 'SHARUN_WORKING_DIR=${SHARUN_DIR}/bin' >> "$APPDIR/.env"
fi
if ! grep -Fxq 'PATH=${SHARUN_DIR}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' "$APPDIR/.env"; then
  printf '%s\n' 'PATH=${SHARUN_DIR}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' >> "$APPDIR/.env"
fi
printf '%s\n' 'v2rayN' > "$APPDIR/.app"

# 生成最终 AppImage，只保留产物非空判断和发布所需的 SHA-256 文件。
quick-sharun --make-appimage
APPIMAGE="$DIST_DIR/v2rayn.AppImage"
[[ -x "$APPIMAGE" && -s "$APPIMAGE" ]] || fail "AppImage was not created"
sha256sum "$APPIMAGE" | tee "$DIST_DIR/v2rayn.AppImage.sha256"

# 仅由需要的应用显式调用公共图形检查；保留原来的 20 秒、会话顺序与致命日志特征。
# 不检查窗口标题，成功条件仍是进程持续运行到 timeout 返回 124。
"$SCRIPT_DIR/../common/gui/check_appimage_gui.sh" \
  "$APPIMAGE" 20 "$VERIFY_DIR" timeout-dbus-xvfb timeout-only \
  'Unhandled exception|DllNotFoundException|error while loading shared libraries|cannot open shared object file|symbol lookup error|invalid ELF header|Segmentation fault|core dumped|Exec format error|wrong ELF class' \
  ''

# 安装统一的 Arch AppImage 基础包，供后续发布步骤使用。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base

# 检查完成后统一写入版本文件并输出原有成功提示。
"$SCRIPT_DIR/../common/build/finish_appimage_build.sh" \
  "$VERSION" "$DIST_DIR/version.txt" "v2rayN AppImage build and smoke test passed."
