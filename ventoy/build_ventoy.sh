#!/usr/bin/env bash
set -Eeuo pipefail

###### 初始化与构建环境 ######

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ "$(uname -m)" != "x86_64" ]]; then
  echo "错误：当前构建脚本仅支持 x86_64。" >&2
  exit 1
fi

APPDIR="$SCRIPT_DIR/AppDir"
DIST_DIR="$SCRIPT_DIR/dist"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

rm -rf "$APPDIR" "$DIST_DIR"
mkdir -p "$APPDIR" "$DIST_DIR"

# 安装构建、校验和 GTK3 依赖。GTK3 用于验证 Ventoy 官方 x86_64 GUI 后端的动态链接依赖。
yay -S --noconfirm --needed \
  wget jq git tar gzip coreutils file desktop-file-utils gtk3 squashfs-tools

###### 下载与校验辅助函数 ######

# 读取 GitHub API JSON；存在 GH_TOKEN 时附带鉴权头，降低公开 API 限流影响。
fetch_json() {
  local url="$1"
  local output="$2"

  if [[ -n "${GH_TOKEN:-}" ]]; then
    wget --quiet \
      --tries=3 \
      --timeout=30 \
      --waitretry=5 \
      --retry-connrefused \
      --header="Authorization: Bearer ${GH_TOKEN}" \
      --header="Accept: application/vnd.github+json" \
      --header="X-GitHub-Api-Version: 2022-11-28" \
      -O "$output" \
      "$url"
  else
    wget --quiet \
      --tries=3 \
      --timeout=30 \
      --waitretry=5 \
      --retry-connrefused \
      --header="Accept: application/vnd.github+json" \
      --header="X-GitHub-Api-Version: 2022-11-28" \
      -O "$output" \
      "$url"
  fi
}

# 下载普通 Release 文件，并统一使用重试和超时参数。
download_file() {
  local url="$1"
  local output="$2"

  wget \
    --tries=3 \
    --timeout=60 \
    --waitretry=5 \
    --retry-connrefused \
    -O "$output" \
    "$url"
}

# 校验 GitHub Release API 提供的 SHA-256 digest，防止下载内容与 Release 元数据不一致。
verify_release_asset_digest() {
  local file="$1"
  local digest="$2"
  local label="$3"
  local expected
  local actual

  if [[ ! "$digest" =~ ^sha256:[0-9a-fA-F]{64}$ ]]; then
    echo "错误：${label} 缺少有效的 GitHub Release SHA-256 digest。" >&2
    exit 1
  fi

  expected="${digest#sha256:}"
  expected="${expected,,}"
  actual="$(sha256sum "$file" | awk '{print $1}')"

  if [[ "$actual" != "$expected" ]]; then
    echo "错误：${label} SHA-256 与 GitHub Release digest 不一致。" >&2
    echo "expected=$expected" >&2
    echo "actual=$actual" >&2
    exit 1
  fi
}

###### 下载 Ventoy 上游文件 ######

# 动态读取 Ventoy 最新稳定 Release，并解析 Linux 归档与官方校验文件。
VENTOY_RELEASE_JSON="$WORKDIR/ventoy-release.json"
VENTOY_RELEASE_API="https://api.github.com/repos/ventoy/Ventoy/releases/latest"
fetch_json "$VENTOY_RELEASE_API" "$VENTOY_RELEASE_JSON"

jq -e '.draft == false and .prerelease == false' "$VENTOY_RELEASE_JSON" >/dev/null
VENTOY_TAG="$(jq -er '.tag_name | strings | select(length > 0)' "$VENTOY_RELEASE_JSON")"

if [[ ! "$VENTOY_TAG" =~ ^v[0-9][0-9A-Za-z._+-]*$ ]]; then
  echo "错误：Ventoy Release tag 格式异常：$VENTOY_TAG" >&2
  exit 1
fi

VENTOY_VERSION="${VENTOY_TAG#v}"
LINUX_ASSET="ventoy-${VENTOY_VERSION}-linux.tar.gz"
CHECKSUM_ASSET="sha256.txt"

LINUX_URL="$(jq -er --arg name "$LINUX_ASSET" '.assets[] | select(.name == $name) | .browser_download_url' "$VENTOY_RELEASE_JSON")"
LINUX_DIGEST="$(jq -er --arg name "$LINUX_ASSET" '.assets[] | select(.name == $name) | .digest' "$VENTOY_RELEASE_JSON")"
CHECKSUM_URL="$(jq -er --arg name "$CHECKSUM_ASSET" '.assets[] | select(.name == $name) | .browser_download_url' "$VENTOY_RELEASE_JSON")"
CHECKSUM_DIGEST="$(jq -er --arg name "$CHECKSUM_ASSET" '.assets[] | select(.name == $name) | .digest' "$VENTOY_RELEASE_JSON")"

if [[ "$LINUX_URL" != "https://github.com/ventoy/Ventoy/releases/download/${VENTOY_TAG}/${LINUX_ASSET}" ]]; then
  echo "错误：Ventoy Linux Release 资产 URL 不符合预期：$LINUX_URL" >&2
  exit 1
fi

if [[ "$CHECKSUM_URL" != "https://github.com/ventoy/Ventoy/releases/download/${VENTOY_TAG}/${CHECKSUM_ASSET}" ]]; then
  echo "错误：Ventoy checksum Release 资产 URL 不符合预期：$CHECKSUM_URL" >&2
  exit 1
fi

LINUX_ARCHIVE="$WORKDIR/$LINUX_ASSET"
CHECKSUM_FILE="$WORKDIR/$CHECKSUM_ASSET"
download_file "$LINUX_URL" "$LINUX_ARCHIVE"
download_file "$CHECKSUM_URL" "$CHECKSUM_FILE"

###### 校验 Ventoy 上游文件 ######

# 先校验 GitHub Release digest，再用上游 sha256.txt 对 Linux 归档做第二层校验。
verify_release_asset_digest "$LINUX_ARCHIVE" "$LINUX_DIGEST" "$LINUX_ASSET"
verify_release_asset_digest "$CHECKSUM_FILE" "$CHECKSUM_DIGEST" "$CHECKSUM_ASSET"

UPSTREAM_SHA256="$(awk -v name="$LINUX_ASSET" '$2 == name || $2 == "*" name {print $1; exit}' "$CHECKSUM_FILE")"
UPSTREAM_SHA256="${UPSTREAM_SHA256,,}"
if [[ ! "$UPSTREAM_SHA256" =~ ^[0-9a-f]{64}$ ]]; then
  echo "错误：无法从 sha256.txt 解析 ${LINUX_ASSET} 的 SHA-256。" >&2
  exit 1
fi

ACTUAL_LINUX_SHA256="$(sha256sum "$LINUX_ARCHIVE" | awk '{print $1}')"
if [[ "$ACTUAL_LINUX_SHA256" != "$UPSTREAM_SHA256" ]]; then
  echo "错误：Ventoy Linux 归档与上游 sha256.txt 不一致。" >&2
  echo "expected=$UPSTREAM_SHA256" >&2
  echo "actual=$ACTUAL_LINUX_SHA256" >&2
  exit 1
fi

# 将动态 Release tag 解析到不可变 Git commit，后续图标直接从该 commit 获取。
REMOTE_REFS="$(git ls-remote https://github.com/ventoy/Ventoy.git \
  "refs/tags/${VENTOY_TAG}" \
  "refs/tags/${VENTOY_TAG}^{}")"
VENTOY_COMMIT="$(awk -v ref="refs/tags/${VENTOY_TAG}^{}" '$2 == ref {print $1; exit}' <<< "$REMOTE_REFS")"
if [[ -z "$VENTOY_COMMIT" ]]; then
  VENTOY_COMMIT="$(awk -v ref="refs/tags/${VENTOY_TAG}" '$2 == ref {print $1; exit}' <<< "$REMOTE_REFS")"
fi
if [[ ! "$VENTOY_COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
  echo "错误：无法把 Ventoy Release tag ${VENTOY_TAG} 解析到有效 commit。" >&2
  exit 1
fi

printf 'Ventoy release: %s\nVentoy commit: %s\nVentoy archive SHA-256: %s\n' \
  "$VENTOY_TAG" "$VENTOY_COMMIT" "$ACTUAL_LINUX_SHA256"

###### 解包并准备 AppDir ######

# 解包官方 Linux Release，并检查后续打包依赖的关键程序和资源是否完整。
SOURCE_PARENT="$WORKDIR/source"
mkdir -p "$SOURCE_PARENT"
tar -xzf "$LINUX_ARCHIVE" -C "$SOURCE_PARENT"
SOURCE_DIR="$SOURCE_PARENT/ventoy-${VENTOY_VERSION}"

test -d "$SOURCE_DIR"
test -x "$SOURCE_DIR/VentoyGUI.x86_64"
test -x "$SOURCE_DIR/tool/x86_64/Ventoy2Disk.gtk3"
test -f "$SOURCE_DIR/ventoy/version"
test -s "$SOURCE_DIR/boot/boot.img"

PACKAGED_VERSION="$(tr -d '[:space:]' < "$SOURCE_DIR/ventoy/version")"
if [[ "$PACKAGED_VERSION" != "$VENTOY_VERSION" ]]; then
  echo "错误：Release tag 版本与 Linux 包内 ventoy/version 不一致。" >&2
  echo "tag=$VENTOY_VERSION package=$PACKAGED_VERSION" >&2
  exit 1
fi

# 完整复制 Ventoy 官方 Linux 包，不重排或删减上游目录结构。
mkdir -p "$APPDIR/ventoy"
cp -a "$SOURCE_DIR/." "$APPDIR/ventoy/"

# 顶层 AppRun 只准备 Ventoy 官方 GUI 启动所需环境，不加入额外系统修改逻辑。
cat > "$APPDIR/AppRun" <<'EOF_APPRUN'
#!/usr/bin/env bash
set -Eeuo pipefail

HERE="$(dirname "$(readlink -f "${0}")")"
MAIN="$HERE/ventoy/VentoyGUI.x86_64"

export LD_LIBRARY_PATH="$HERE/ventoy/"
export PATH="$HERE/ventoy/:$PATH"
export NO_AT_BRIDGE=1

exec "$MAIN" "$@"
EOF_APPRUN
chmod +x "$APPDIR/AppRun"

###### 准备桌面文件与图标 ######

cat > "$APPDIR/ventoy.desktop" <<'EOF_DESKTOP'
[Desktop Entry]
Type=Application
Icon=ventoy
Name=Ventoy
Exec=ventoygui
Terminal=false
Hidden=false
Categories=Utility;
Comment=Ventoy2Disk GUI
EOF_DESKTOP

desktop-file-validate "$APPDIR/ventoy.desktop"

# 图标固定读取当前 Ventoy Release tag 对应的不可变 commit，避免跟随 main 漂移。
ICON_URL="https://raw.githubusercontent.com/ventoy/Ventoy/${VENTOY_COMMIT}/ICON/logo_72.png"
download_file "$ICON_URL" "$APPDIR/ventoy.png"
file "$APPDIR/ventoy.png" | grep -q 'PNG image data'
ln -s ventoy.png "$APPDIR/.DirIcon"

###### 校验 Ventoy GUI 依赖 ######

# 检查 x86_64 launcher 与 GTK3 后端的 ELF 类型，并拒绝存在缺失动态库的构建。
file "$APPDIR/ventoy/VentoyGUI.x86_64" | grep -q 'ELF 64-bit'
file "$APPDIR/ventoy/tool/x86_64/Ventoy2Disk.gtk3" | grep -q 'ELF 64-bit'
if ldd "$APPDIR/ventoy/tool/x86_64/Ventoy2Disk.gtk3" | grep -q 'not found'; then
  echo "错误：Ventoy GTK3 GUI 存在缺失动态库。" >&2
  ldd "$APPDIR/ventoy/tool/x86_64/Ventoy2Disk.gtk3" >&2
  exit 1
fi

###### 下载 AppImage 打包工具 ######

# 动态获取官方 appimagetool，并校验对应 Release digest。
APPIMAGETOOL_JSON="$WORKDIR/appimagetool-release.json"
fetch_json "https://api.github.com/repos/AppImage/appimagetool/releases/latest" "$APPIMAGETOOL_JSON"
jq -e '.draft == false and .prerelease == false' "$APPIMAGETOOL_JSON" >/dev/null
APPIMAGETOOL_URL="$(jq -er '.assets[] | select(.name == "appimagetool-x86_64.AppImage") | .browser_download_url' "$APPIMAGETOOL_JSON")"
APPIMAGETOOL_DIGEST="$(jq -er '.assets[] | select(.name == "appimagetool-x86_64.AppImage") | .digest' "$APPIMAGETOOL_JSON")"
APPIMAGETOOL="$WORKDIR/appimagetool-x86_64.AppImage"
download_file "$APPIMAGETOOL_URL" "$APPIMAGETOOL"
verify_release_asset_digest "$APPIMAGETOOL" "$APPIMAGETOOL_DIGEST" "appimagetool-x86_64.AppImage"
chmod +x "$APPIMAGETOOL"

# 动态获取官方 x86_64 type2 runtime，并在封装前校验 Release digest。
RUNTIME_JSON="$WORKDIR/type2-runtime-release.json"
fetch_json "https://api.github.com/repos/AppImage/type2-runtime/releases/latest" "$RUNTIME_JSON"
jq -e '.draft == false and .prerelease == false' "$RUNTIME_JSON" >/dev/null
RUNTIME_URL="$(jq -er '.assets[] | select(.name == "runtime-x86_64") | .browser_download_url' "$RUNTIME_JSON")"
RUNTIME_DIGEST="$(jq -er '.assets[] | select(.name == "runtime-x86_64") | .digest' "$RUNTIME_JSON")"
RUNTIME_FILE="$WORKDIR/runtime-x86_64"
download_file "$RUNTIME_URL" "$RUNTIME_FILE"
verify_release_asset_digest "$RUNTIME_FILE" "$RUNTIME_DIGEST" "runtime-x86_64"

###### 核心打包 ######

# 使用明确的 x86_64 type2 runtime 直接封装已经准备完整的 AppDir。
OUTPUT="$DIST_DIR/ventoy.AppImage"
ARCH=x86_64 \
VERSION="$VENTOY_VERSION" \
APPIMAGE_EXTRACT_AND_RUN=1 \
  "$APPIMAGETOOL" \
    --runtime-file "$RUNTIME_FILE" \
    "$APPDIR" \
    "$OUTPUT"

###### 测试与验证 ######

# 先检查最终产物基本类型，再提取 AppImage 对内部关键文件做一致性验证。
chmod +x "$OUTPUT"
test -s "$OUTPUT"
file "$OUTPUT" | grep -q 'ELF 64-bit'

VERIFY_DIR="$WORKDIR/verify"
mkdir -p "$VERIFY_DIR"
(
  cd "$VERIFY_DIR"
  "$OUTPUT" --appimage-extract >/dev/null
)

EXTRACTED="$VERIFY_DIR/squashfs-root"
test -x "$EXTRACTED/AppRun"
test -f "$EXTRACTED/ventoy.desktop"
test -f "$EXTRACTED/ventoy.png"
test -x "$EXTRACTED/ventoy/VentoyGUI.x86_64"
test -x "$EXTRACTED/ventoy/tool/x86_64/Ventoy2Disk.gtk3"
test "$(tr -d '[:space:]' < "$EXTRACTED/ventoy/ventoy/version")" = "$VENTOY_VERSION"
cmp -s "$APPDIR/AppRun" "$EXTRACTED/AppRun"
cmp -s "$APPDIR/ventoy.desktop" "$EXTRACTED/ventoy.desktop"

# 再次检查提取后 GTK3 后端的动态库，确认最终封装没有引入依赖缺失。
if ldd "$EXTRACTED/ventoy/tool/x86_64/Ventoy2Disk.gtk3" | grep -q 'not found'; then
  echo "错误：最终 AppImage 中的 Ventoy GTK3 GUI 存在缺失动态库。" >&2
  ldd "$EXTRACTED/ventoy/tool/x86_64/Ventoy2Disk.gtk3" >&2
  exit 1
fi

###### 整理产物 ######

# 输出最终 AppImage 的 SHA-256，供 Release 产物审计。
sha256sum "$OUTPUT"
