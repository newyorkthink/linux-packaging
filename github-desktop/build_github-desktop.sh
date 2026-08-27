#!/usr/bin/env bash
set -Eeuo pipefail

# GitHub Desktop Linux AppImage：使用 GitHub 官方 README 指向的 shiftkey/desktop Linux 社区发行版。
# 不再直接编译 desktop/desktop 官方源码，因为官方明确不支持 Linux，直接编译可能出现“进程存活但没有窗口”的假成功。

ARCH="$(uname -m)"
if [[ "$ARCH" != "x86_64" ]]; then
  echo "Error: this script currently supports x86_64 only." >&2
  exit 1
fi

ROOT_DIR="$PWD"
WORK_DIR="$ROOT_DIR/work"
DIST_DIR="$ROOT_DIR/dist"
RELEASE_JSON="$WORK_DIR/latest-release.json"

rm -rf "$WORK_DIR" "$DIST_DIR"
mkdir -p "$WORK_DIR" "$DIST_DIR"

# 安装下载、校验、Electron/Linux 运行库以及真实 GUI 窗口烟测所需工具。
yay -S --noconfirm --needed \
  curl python coreutils \
  alsa-lib at-spi2-core cairo cups dbus expat fontconfig gcc-libs glib2 glibc \
  gtk3 libdrm libsecret libx11 libxcb libxcomposite libxdamage libxext libxfixes \
  libxkbcommon libxrandr libxss libxtst mesa nspr nss pango \
  xorg-server-xvfb xorg-xauth xorg-xwininfo xdotool

# 读取 Linux 社区维护版最新正式 Release，并严格选择 x86_64 AppImage 与对应 SHA256。
curl -fL --retry 5 --retry-delay 2 \
  https://api.github.com/repos/shiftkey/desktop/releases/latest \
  -o "$RELEASE_JSON"

IFS=$'\t' read -r RELEASE_TAG APPIMAGE_NAME APPIMAGE_URL CHECKSUM_NAME CHECKSUM_URL < <(
  python - "$RELEASE_JSON" <<'PY'
import json
import re
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    release = json.load(handle)

tag = release.get("tag_name", "")
if not re.fullmatch(r"release-\d+\.\d+\.\d+-linux\d+", tag):
    raise SystemExit(f"Error: invalid shiftkey Linux release tag: {tag!r}")

assets = {item.get("name", ""): item.get("browser_download_url", "") for item in release.get("assets", [])}
appimage_names = [
    name for name in assets
    if re.fullmatch(r"GitHubDesktop-linux-x86_64-.*\.AppImage", name)
]
if len(appimage_names) != 1:
    raise SystemExit(f"Error: expected exactly one x86_64 AppImage, found: {appimage_names}")

appimage_name = appimage_names[0]
checksum_name = f"{appimage_name}.sha256"
if checksum_name not in assets:
    raise SystemExit(f"Error: checksum asset not found: {checksum_name}")

print("\t".join((tag, appimage_name, assets[appimage_name], checksum_name, assets[checksum_name])))
PY
)

if [[ -z "$RELEASE_TAG" || -z "$APPIMAGE_URL" || -z "$CHECKSUM_URL" ]]; then
  echo "Error: failed to resolve GitHub Desktop Linux release assets." >&2
  exit 1
fi

echo "GitHub Desktop Linux tag: $RELEASE_TAG"
echo "GitHub Desktop Linux asset: $APPIMAGE_NAME"

UPSTREAM_APPIMAGE="$WORK_DIR/$APPIMAGE_NAME"
UPSTREAM_CHECKSUM="$WORK_DIR/$CHECKSUM_NAME"

curl -fL --retry 5 --retry-delay 2 "$APPIMAGE_URL" -o "$UPSTREAM_APPIMAGE"
curl -fL --retry 5 --retry-delay 2 "$CHECKSUM_URL" -o "$UPSTREAM_CHECKSUM"

EXPECTED_SHA256="$(tr -d '[:space:]' < "$UPSTREAM_CHECKSUM")"
ACTUAL_SHA256="$(sha256sum "$UPSTREAM_APPIMAGE" | awk '{print $1}')"

if [[ ! "$EXPECTED_SHA256" =~ ^[0-9a-fA-F]{64}$ ]]; then
  echo "Error: invalid upstream SHA256 value." >&2
  exit 1
fi

if [[ "${ACTUAL_SHA256,,}" != "${EXPECTED_SHA256,,}" ]]; then
  echo "Error: GitHub Desktop AppImage SHA256 mismatch." >&2
  echo "Expected: $EXPECTED_SHA256" >&2
  echo "Actual:   $ACTUAL_SHA256" >&2
  exit 1
fi

cp -f "$UPSTREAM_APPIMAGE" "$DIST_DIR/github-desktop.AppImage"
chmod +x "$DIST_DIR/github-desktop.AppImage"

# 真实 GUI 烟测：必须在 Xvfb 中检测到可见 GitHub Desktop 窗口，不能再只检查进程是否存活。
SMOKE_LOG="$DIST_DIR/smoke-test.log"
WINDOW_LOG="$DIST_DIR/smoke-windows.log"
SMOKE_PROFILE="$WORK_DIR/smoke-profile"
mkdir -p "$SMOKE_PROFILE"

set +e
xvfb-run -a bash -c '
  set -u
  appimage="$1"
  profile="$2"
  smoke_log="$3"
  window_log="$4"

  APPIMAGE_EXTRACT_AND_RUN=1 "$appimage" \
    --no-sandbox \
    --disable-gpu \
    --user-data-dir="$profile" \
    >"$smoke_log" 2>&1 &
  app_pid=$!
  window_found=0

  for _ in $(seq 1 45); do
    if xdotool search --onlyvisible --name "GitHub Desktop" >/dev/null 2>&1; then
      window_found=1
      break
    fi

    if ! kill -0 "$app_pid" 2>/dev/null; then
      wait "$app_pid"
      exit $?
    fi

    sleep 1
  done

  xwininfo -root -tree >"$window_log" 2>&1 || true

  kill "$app_pid" 2>/dev/null || true
  wait "$app_pid" 2>/dev/null || true

  if [[ "$window_found" -ne 1 ]]; then
    exit 125
  fi
' bash \
  "$DIST_DIR/github-desktop.AppImage" \
  "$SMOKE_PROFILE" \
  "$SMOKE_LOG" \
  "$WINDOW_LOG"
SMOKE_RC=$?
set -e

if [[ "$SMOKE_RC" -ne 0 ]]; then
  echo "Error: GitHub Desktop GUI smoke test failed with exit code $SMOKE_RC." >&2
  echo "--- smoke-test.log ---" >&2
  tail -n 200 "$SMOKE_LOG" >&2 || true
  echo "--- smoke-windows.log ---" >&2
  tail -n 200 "$WINDOW_LOG" >&2 || true
  exit "$SMOKE_RC"
fi

sha256sum "$DIST_DIR/github-desktop.AppImage" > "$DIST_DIR/github-desktop.AppImage.sha256"
printf '%s\n' "$RELEASE_TAG" > "$DIST_DIR/upstream-tag.txt"
printf '%s\n' "$APPIMAGE_NAME" > "$DIST_DIR/upstream-asset.txt"

echo "Built: $DIST_DIR/github-desktop.AppImage"
