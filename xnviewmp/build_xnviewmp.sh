#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
cd "$SCRIPT_DIR"

log() {
  printf '[XnView MP] %s\n' "$*"
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

HOST_ARCH="$(uname -m)"
readonly HOST_ARCH
[[ "$HOST_ARCH" == x86_64 ]] || die "当前仅支持 x86_64。"
command -v yay >/dev/null 2>&1 || die "构建环境缺少命令：yay"

readonly BASE_URL="https://download.xnview.com/versions/XnView_MP"
readonly CHECKSUMS_URL="$BASE_URL/XnView_MP-CHECKSUMS.txt"
readonly SOURCE_DIR="$SCRIPT_DIR/source"
readonly CHECKSUMS_FILE="$SOURCE_DIR/XnView_MP-CHECKSUMS.txt"
readonly OFFICIAL_APPIMAGE="$SOURCE_DIR/XnView_MP-official.AppImage"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly OUTFILE="$DIST_DIR/xnviewmp.AppImage"
readonly VERIFY_DIR="$SCRIPT_DIR/verify"
readonly VERIFY_ROOT="$VERIFY_DIR/squashfs-root"
readonly SMOKE_HOME="$SCRIPT_DIR/smoke-home"
readonly SMOKE_CONFIG="$SCRIPT_DIR/smoke-config"
readonly SMOKE_CACHE="$SCRIPT_DIR/smoke-cache"
readonly SMOKE_RUNTIME="$SCRIPT_DIR/smoke-runtime"
readonly SMOKE_LOG="$SCRIPT_DIR/xnviewmp-smoke.log"

# 只清理 XnView MP 自己的构建、验证和隔离测试目录。
rm -rf \
  "$SOURCE_DIR" \
  "$DIST_DIR" \
  "$VERIFY_DIR" \
  "$SMOKE_HOME" \
  "$SMOKE_CONFIG" \
  "$SMOKE_CACHE" \
  "$SMOKE_RUNTIME"
rm -f "$SMOKE_LOG"
mkdir -p "$SOURCE_DIR" "$DIST_DIR" "$VERIFY_DIR"

# 安装下载、文件审计、desktop 校验、AUR 对齐的 Qt/XCB 运行依赖和 Xvfb 冒烟测试工具。
yay -S --noconfirm --needed \
  coreutils curl desktop-file-utils file findutils gawk grep python qt5-multimedia \
  xorg-server-xvfb xorg-xauth

for command_name in \
  awk cat chmod cp curl desktop-file-validate file find grep mkdir python3 sha256sum timeout xvfb-run; do
  command -v "$command_name" >/dev/null 2>&1 || \
    die "构建环境缺少命令：$command_name"
done

log "读取 XnView MP 官方校验文件并解析最新稳定 x86_64 AppImage"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  "$CHECKSUMS_URL" \
  -o "$CHECKSUMS_FILE"
[[ -s "$CHECKSUMS_FILE" ]] || die "官方校验文件为空。"

mapfile -t appimage_meta < <(
  python3 - "$CHECKSUMS_FILE" <<'PY'
import re
import sys

pattern = re.compile(
    r"^(?P<sha>[0-9a-f]{64})  "
    r"(?P<name>XnView_MP-(?P<version>[0-9]+(?:\.[0-9]+)+)\.glibc[0-9.]+-x86_64\.AppImage)$"
)

matches = []
with open(sys.argv[1], "r", encoding="utf-8") as fh:
    for raw in fh:
        match = pattern.fullmatch(raw.rstrip("\n"))
        if not match:
            continue
        version = match.group("version")
        matches.append((tuple(int(part) for part in version.split(".")), version, match.group("name"), match.group("sha")))

if not matches:
    raise SystemExit("官方校验文件中没有找到稳定的 x86_64 AppImage。")

_, version, name, sha256 = max(matches, key=lambda item: item[0])
print(version)
print(name)
print(sha256)
PY
)
[[ ${#appimage_meta[@]} -eq 3 ]] || die "无法完整解析官方 AppImage 元数据。"
readonly VERSION="${appimage_meta[0]}"
readonly APPIMAGE_NAME="${appimage_meta[1]}"
readonly EXPECTED_SHA256="${appimage_meta[2]}"
readonly APPIMAGE_URL="$BASE_URL/$APPIMAGE_NAME"

[[ "$VERSION" =~ ^[0-9]+(\.[0-9]+)+$ ]] || die "解析出的版本号异常：$VERSION"
[[ "$APPIMAGE_NAME" == "XnView_MP-$VERSION".glibc*-x86_64.AppImage ]] || \
  die "解析出的 AppImage 文件名异常：$APPIMAGE_NAME"
[[ "$EXPECTED_SHA256" =~ ^[0-9a-f]{64}$ ]] || die "解析出的 SHA-256 异常。"
[[ "$APPIMAGE_URL" == https://download.xnview.com/versions/XnView_MP/XnView_MP-*.AppImage ]] || \
  die "解析出的下载 URL 异常：$APPIMAGE_URL"
printf 'XnView MP version: %s\nXnView MP source: %s\n' "$VERSION" "$APPIMAGE_URL"

log "下载官方 AppImage"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  "$APPIMAGE_URL" \
  -o "$OFFICIAL_APPIMAGE"
[[ -s "$OFFICIAL_APPIMAGE" ]] || die "官方下载文件为空。"
chmod 0755 "$OFFICIAL_APPIMAGE"
file "$OFFICIAL_APPIMAGE" | grep -q 'ELF 64-bit' || \
  die "官方下载文件不是 64 位 AppImage ELF。"

log "校验官方 SHA-256"
ACTUAL_SHA256="$(sha256sum "$OFFICIAL_APPIMAGE" | awk '{print $1}')"
readonly ACTUAL_SHA256
[[ "$ACTUAL_SHA256" == "$EXPECTED_SHA256" ]] || die "官方 AppImage SHA-256 校验失败。"
printf 'XnView MP official SHA-256: %s\n' "$ACTUAL_SHA256"

# 不修改官方 AppImage 内容，只复制为仓库固定 Release 文件名。
cp -f "$OFFICIAL_APPIMAGE" "$OUTFILE"
chmod 0755 "$OUTFILE"
[[ -s "$OUTFILE" ]] || die "输出 AppImage 为空。"
[[ "$(sha256sum "$OUTFILE" | awk '{print $1}')" == "$EXPECTED_SHA256" ]] || \
  die "复制后的 AppImage 与官方 SHA-256 不一致。"

log "验证 AppImage 可提取并检查 desktop / AppRun"
(
  cd "$VERIFY_DIR"
  "$OUTFILE" --appimage-extract >/dev/null
)
[[ -d "$VERIFY_ROOT" ]] || die "AppImage 提取失败。"
[[ -x "$VERIFY_ROOT/AppRun" ]] || die "提取后的 AppImage 缺少可执行 AppRun。"

mapfile -d '' desktop_files < <(
  find "$VERIFY_ROOT" -maxdepth 1 -type f -name '*.desktop' -print0
)
[[ ${#desktop_files[@]} -ge 1 ]] || die "提取后的 AppImage 根目录没有 desktop 文件。"
for desktop_file in "${desktop_files[@]}"; do
  desktop-file-validate "$desktop_file"
done

log "在隔离 HOME / XDG 目录中执行 Xvfb 冒烟测试"
mkdir -p "$SMOKE_HOME" "$SMOKE_CONFIG" "$SMOKE_CACHE" "$SMOKE_RUNTIME"
chmod 0700 "$SMOKE_RUNTIME"

set +e
HOME="$SMOKE_HOME" \
XDG_CONFIG_HOME="$SMOKE_CONFIG" \
XDG_CACHE_HOME="$SMOKE_CACHE" \
XDG_RUNTIME_DIR="$SMOKE_RUNTIME" \
APPIMAGE_EXTRACT_AND_RUN=1 \
timeout 30s xvfb-run -a "$OUTFILE" >"$SMOKE_LOG" 2>&1
smoke_rc=$?
set -e

cat "$SMOKE_LOG"
printf 'XnView MP smoke exit code: %s\n' "$smoke_rc"

if grep -Eqi \
  'Segmentation fault|Aborted|error while loading shared libraries|Cannot mix incompatible Qt libraries|Could not load the Qt platform plugin|no Qt platform plugin could be initialized|GLIBC_[0-9.]+.*not found' \
  "$SMOKE_LOG"; then
  die "XnView MP 冒烟测试检测到致命运行时错误。"
fi

if [[ "$smoke_rc" -ne 0 && "$smoke_rc" -ne 124 ]]; then
  die "XnView MP 在冒烟测试期间异常退出：$smoke_rc"
fi

log "构建验证完成"
sha256sum "$OUTFILE"
