#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log() {
  printf '[Hermes Desktop] %s\n' "$*"
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

readonly HOST_ARCH="$(uname -m)"
[[ "$HOST_ARCH" == "x86_64" ]] || die "当前仅支持 x86_64。"

for command_name in curl git jq node npm python3 sudo; do
  command -v "$command_name" >/dev/null 2>&1 || die "构建环境缺少命令：$command_name"
done

readonly NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
[[ "$NODE_MAJOR" == "26" ]] || die "Hermes Desktop 当前构建基线要求 Node.js 26，实际为 $(node --version)。"

readonly UPSTREAM_DIR="$SCRIPT_DIR/upstream"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly OUTFILE="$DIST_DIR/hermes-desktop.AppImage"
readonly PATCH_SCRIPT="$SCRIPT_DIR/patch_hermes_desktop.py"

[[ -f "$PATCH_SCRIPT" ]] || die "缺少补丁脚本：$PATCH_SCRIPT"

# 只清理 Hermes Desktop 自己的构建目录和旧产物。
rm -rf "$UPSTREAM_DIR" "$DIST_DIR"
mkdir -p "$DIST_DIR"

log "安装 Linux 构建、打包和 smoke-test 依赖"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  build-essential \
  ca-certificates \
  curl \
  dbus-x11 \
  file \
  git \
  gnome-keyring \
  jq \
  libsecret-1-0 \
  libsecret-1-dev \
  patchelf \
  pkg-config \
  python3 \
  xauth \
  xvfb \
  binutils

log "读取 NousResearch/hermes-agent 最新稳定 Release"
release_json="$(curl -fsSL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  https://api.github.com/repos/NousResearch/hermes-agent/releases/latest)"

readonly UPSTREAM_TAG="$(jq -r '.tag_name // empty' <<<"$release_json")"
[[ "$UPSTREAM_TAG" =~ ^v[0-9]{4}\.[0-9]+\.[0-9]+$ ]] || \
  die "无法取得有效的 NousResearch/hermes-agent 稳定 Release tag：$UPSTREAM_TAG"

log "上游稳定版本：$UPSTREAM_TAG"

git clone \
  --depth=1 \
  --branch "$UPSTREAM_TAG" \
  https://github.com/NousResearch/hermes-agent.git \
  "$UPSTREAM_DIR"

log "使用源方案 npm 基线"
npm install --global npm@12
node --version
npm --version

log "安装上游锁定依赖"
(
  cd "$UPSTREAM_DIR"
  npm ci
)

log "内置 Chromium safeStorage 所需 libsecret runtime"
libsecret_path="$(ldconfig -p | awk '$1 == "libsecret-1.so.0" { print $NF; exit }')"
[[ -n "$libsecret_path" && -f "$libsecret_path" ]] || die "找不到 libsecret-1.so.0。"

install -Dm0644 "$(readlink -f "$libsecret_path")" \
  "$UPSTREAM_DIR/apps/desktop/build/linux-libs/libsecret-1.so.0"

file "$UPSTREAM_DIR/apps/desktop/build/linux-libs/libsecret-1.so.0"
ldd "$UPSTREAM_DIR/apps/desktop/build/linux-libs/libsecret-1.so.0" | tee /tmp/hermes-libsecret-ldd.log
if grep -Fq 'not found' /tmp/hermes-libsecret-ldd.log; then
  die "内置 libsecret 存在未解析依赖。"
fi

log "应用 standalone Linux AppImage 兼容补丁"
python3 "$PATCH_SCRIPT" "$UPSTREAM_DIR"

log "TypeScript 类型检查"
(
  cd "$UPSTREAM_DIR/apps/desktop"
  npm run typecheck
)

log "使用官方 Desktop electron-builder 链生成 AppImage"
(
  cd "$UPSTREAM_DIR/apps/desktop"
  export CSC_IDENTITY_AUTO_DISCOVERY=false
  npm run build
  npm run builder -- --linux AppImage --x64 --publish never
)

mapfile -t appimages < <(
  find "$UPSTREAM_DIR/apps/desktop/release" -maxdepth 1 -type f -name '*.AppImage' -print
)
[[ "${#appimages[@]}" -eq 1 ]] || die "预期得到 1 个 AppImage，实际得到 ${#appimages[@]} 个。"

install -m 0755 "${appimages[0]}" "$OUTFILE"
test -s "$OUTFILE" || die "AppImage 产物为空。"
file "$OUTFILE" | grep -q 'ELF 64-bit' || die "AppImage 不是 64 位 ELF。"

appimage_offset="$("$OUTFILE" --appimage-offset)"
[[ "$appimage_offset" =~ ^[0-9]+$ ]] || die "无法读取 AppImage offset。"
(( appimage_offset > 0 )) || die "AppImage offset 无效。"

extract_dir="$(mktemp -d)"
cleanup_extract() {
  rm -rf "$extract_dir"
}
trap cleanup_extract EXIT

outfile_abs="$(realpath "$OUTFILE")"
(
  cd "$extract_dir"
  "$outfile_abs" --appimage-extract >/dev/null
)

appdir="$extract_dir/squashfs-root"
test -f "$appdir/locales/zh-CN.pak" || die "AppImage 缺少 Electron zh-CN locale。"
test -f "$appdir/resources/linux-libs/libsecret-1.so.0" || die "AppImage 缺少内置 libsecret-1.so.0。"
readelf -d "$appdir/Hermes" | tee /tmp/hermes-electron-dynamic.log
grep -Fq '$ORIGIN/resources/linux-libs' /tmp/hermes-electron-dynamic.log || \
  die "Hermes Electron 主程序 RUNPATH 未包含内置 libsecret 目录。"

cleanup_extract
trap - EXIT

log "运行最终 AppImage safeStorage / 中文 locale smoke test"
smoke_home="$(mktemp -d)"
host_libsecret="$(ldconfig -p | awk '$1 == "libsecret-1.so.0" { print $NF; exit }')"
host_libsecret_disabled="${host_libsecret}.hermes-ci-disabled"
strict_host_libsecret_test=false

cleanup_smoke() {
  if [[ "$strict_host_libsecret_test" == true ]] && \
     [[ -e "$host_libsecret_disabled" || -L "$host_libsecret_disabled" ]]; then
    sudo mv "$host_libsecret_disabled" "$host_libsecret"
  fi
  rm -rf "$smoke_home"
}
trap cleanup_smoke EXIT

# GitHub Actions 中临时隐藏 Runner 系统 libsecret，确认 AppImage 实际使用自身内置副本。
# 本机手动构建不移动宿主库，避免对真实桌面会话产生额外影响。
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  [[ -n "$host_libsecret" && -e "$host_libsecret" ]] || die "无法定位 Runner 的 libsecret-1.so.0。"
  sudo mv "$host_libsecret" "$host_libsecret_disabled"
  strict_host_libsecret_test=true
fi

dbus-run-session -- bash -euo pipefail -c '
  export HOME="$1"
  export XDG_RUNTIME_DIR="${HOME}/runtime"
  mkdir -p "$XDG_RUNTIME_DIR"
  chmod 700 "$XDG_RUNTIME_DIR"

  eval "$(printf "%s\n" "hermes-ci-keyring" | gnome-keyring-daemon --unlock --components=secrets)"
  if [[ -n "${GNOME_KEYRING_CONTROL:-}" ]]; then
    export GNOME_KEYRING_CONTROL
  fi

  LANG=zh_CN.UTF-8 \
  HERMES_DESKTOP_SAFE_STORAGE_SMOKE_TEST=1 \
  xvfb-run -a "$2" --appimage-extract-and-run --no-sandbox
' bash "$smoke_home" "$outfile_abs" 2>&1 | tee /tmp/hermes-appimage-smoke.log

grep -Fq '[hermes] standalone AppImage detected password-store backend: gnome-libsecret' \
  /tmp/hermes-appimage-smoke.log || die "smoke test 未检测到 gnome-libsecret backend。"
grep -Fq '[hermes-smoke] safeStorage backend=gnome_libsecret encryptionAvailable=true' \
  /tmp/hermes-appimage-smoke.log || die "safeStorage 加密不可用。"
grep -Fq '[hermes-smoke] safeStorage roundTrip=true' \
  /tmp/hermes-appimage-smoke.log || die "safeStorage 加密/解密往返失败。"
grep -Eiq '\[hermes-smoke\] appLocale=zh([_-]|$)' \
  /tmp/hermes-appimage-smoke.log || die "中文 locale smoke test 失败。"

cleanup_smoke
trap - EXIT

sha256sum "$OUTFILE"
log "完成：$OUTFILE"
