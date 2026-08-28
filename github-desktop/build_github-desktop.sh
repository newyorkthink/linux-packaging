#!/usr/bin/env bash
set -Eeuo pipefail

# GitHub Desktop Linux AppImage：只使用 GitHub 官方 desktop/desktop 最新稳定源码构建。
# Linux 侧仅补官方源码缺失的协议参数处理、AppImage 启动入口和桌面协议注册，不引入第三方 GitHub Desktop 成品。

ARCH="$(uname -m)"
if [[ "$ARCH" != "x86_64" ]]; then
  echo "Error: this script currently supports x86_64 only." >&2
  exit 1
fi
export ARCH=x86_64

ROOT_DIR="$PWD"
SOURCE_DIR="$ROOT_DIR/source"
TOOLS_DIR="$ROOT_DIR/tools"
APPDIR="$ROOT_DIR/AppDir"
DIST_DIR="$ROOT_DIR/dist"

rm -rf "$SOURCE_DIR" "$TOOLS_DIR" "$APPDIR" "$DIST_DIR"
mkdir -p "$TOOLS_DIR" "$DIST_DIR"

# GitHub Actions 固定使用 Ubuntu 22.04 作为 Linux ABI 兼容基线。
# 保留 Arch 本地调试入口，但正式 workflow 不再使用 rolling Arch 构建 native module。
if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential git curl xz-utils python3 pkgconf patchelf file ca-certificates \
    libsecret-1-dev libgtk-3-0 libnss3 libasound2 libcups2 libxkbcommon0 libxrandr2 libgl1 \
    fontconfig xdg-utils xvfb xauth x11-utils xdotool
elif command -v yay >/dev/null 2>&1; then
  yay -S --noconfirm --needed \
    base-devel git curl xz python pkgconf patchelf \
    libsecret gtk3 nss alsa-lib cups libxkbcommon libxrandr mesa \
    fontconfig xdg-utils xorg-server-xvfb xorg-xauth xorg-xwininfo xdotool
else
  echo "Error: unsupported build environment; Ubuntu/Debian apt or Arch yay is required." >&2
  exit 1
fi

PYTHON_BIN="$(command -v python3 || command -v python)"

# 始终从 GitHub 官方 desktop/desktop 读取最新稳定 Release tag。
GITHUB_DESKTOP_TAG="$(gh api repos/desktop/desktop/releases/latest --jq .tag_name)"
if [[ ! "$GITHUB_DESKTOP_TAG" =~ ^release-[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: invalid GitHub Desktop stable tag: $GITHUB_DESKTOP_TAG" >&2
  exit 1
fi

echo "GitHub Desktop official tag: $GITHUB_DESKTOP_TAG"

# 只拉取该官方稳定 tag，并递归取得官方仓库声明的子模块。
git clone \
  --depth=1 \
  --branch "$GITHUB_DESKTOP_TAG" \
  --recurse-submodules \
  --shallow-submodules \
  https://github.com/desktop/desktop.git \
  "$SOURCE_DIR"

# 使用官方 tag 自己声明的 Node.js 版本，避免 native module ABI 漂移。
NODE_VERSION="$(tr -d '[:space:]' < "$SOURCE_DIR/.node-version")"
if [[ ! "$NODE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: invalid upstream Node version: $NODE_VERSION" >&2
  exit 1
fi

NODE_ARCHIVE="node-v${NODE_VERSION}-linux-x64.tar.xz"
curl -fL --retry 5 --retry-delay 2 \
  "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_ARCHIVE}" \
  -o "$TOOLS_DIR/$NODE_ARCHIVE"
tar -xJf "$TOOLS_DIR/$NODE_ARCHIVE" -C "$TOOLS_DIR"
export PATH="$TOOLS_DIR/node-v${NODE_VERSION}-linux-x64/bin:$PATH"

# 使用 Yarn Classic 驱动官方 yarn.lock；官方 post-install 会继续使用仓库自带 Yarn。
npm install --global --prefix "$TOOLS_DIR/yarn" yarn@1.22.22
export PATH="$TOOLS_DIR/yarn/bin:$PATH"

node --version
yarn --version

# 在修改前确认官方 Linux build 基线仍存在，避免上游结构变化时盲目打补丁。
test -s "$SOURCE_DIR/app/static/linux/icon-logo.png"
grep -A2 "process.platform === 'linux'" "$SOURCE_DIR/script/dist-info.ts" | grep -q "return 'desktop'"
grep -q "if (__WIN32__ && args\['protocol-launcher'\] === true)" "$SOURCE_DIR/app/src/main-process/main.ts"
# GitHub Desktop 官方源码本身提供此 Linux/Electron 启动兼容开关；若以后上游移除则停止构建而不是偷偷换第三方实现。
grep -q "GITHUB_DESKTOP_DISABLE_HARDWARE_ACCELERATION" "$SOURCE_DIR/app/src/main-process/main.ts"

# 官方主进程只在 Windows 读取协议 URL；Linux 冷启动和 second-instance 同样会通过 argv 收到 URL。
# 这里只补 Linux argv 协议处理，不改 GitHub Desktop 的业务逻辑。
"$PYTHON_BIN" - "$SOURCE_DIR/app/src/main-process/main.ts" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
anchor = """    return\n  }\n\n  if (typeof args['cli-open'] === 'string') {"""
replacement = """    return\n  }\n\n  if (__LINUX__) {\n    const prefixes = Array.from(possibleProtocols, p => `${p}://`)\n    const matchingUrl = argv.find(arg => prefixes.some(p => arg.startsWith(p)))\n\n    if (matchingUrl) {\n      try {\n        new URL(matchingUrl)\n        handleAppURL(matchingUrl)\n        return\n      } catch (e) {\n        log.error(`Unable to parse argument as URL: ${matchingUrl}`)\n      }\n    }\n  }\n\n  if (typeof args['cli-open'] === 'string') {"""
if text.count(anchor) != 1:
    raise SystemExit("Error: upstream command-line block changed; refusing an unsafe Linux patch.")
path.write_text(text.replace(anchor, replacement, 1), encoding="utf-8")
PY

grep -A16 "if (__LINUX__)" "$SOURCE_DIR/app/src/main-process/main.ts" | grep -q "handleAppURL(matchingUrl)"

# 官方 vendored printenvz 明确使用 -Werror + -D_FORTIFY_SOURCE=1。
# 新版 Ubuntu runner 的 GCC 已预定义 _FORTIFY_SOURCE；先 Undef 再按官方值定义，避免“宏重复定义”被 -Werror 误判为构建失败。
PRINTENV_GYP="$SOURCE_DIR/vendor/printenvz/binding.gyp"
test -s "$PRINTENV_GYP"
"$PYTHON_BIN" - "$PRINTENV_GYP" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
needle = "          '-D_FORTIFY_SOURCE=1',"
replacement = "          '-U_FORTIFY_SOURCE',\n" + needle
if text.count(needle) < 1:
    raise SystemExit("Error: upstream printenvz fortify flag changed; refusing an unsafe patch.")
text = text.replace(needle, replacement, 1)
path.write_text(text, encoding="utf-8")
PY
grep -A2 -- "'-U_FORTIFY_SOURCE'" "$PRINTENV_GYP" | grep -q -- "'-D_FORTIFY_SOURCE=1'"

# 官方 vendored desktop-trampoline 的 Linux cflags 同样启用 -Werror + -D_FORTIFY_SOURCE=1。
# 只在 Linux cflags 段先取消 runner 预定义值，再保留官方要求的 FORTIFY=1，避免宏重复定义触发 -Werror。
DESKTOP_TRAMPOLINE_GYP="$SOURCE_DIR/vendor/desktop-trampoline/binding.gyp"
test -s "$DESKTOP_TRAMPOLINE_GYP"
"$PYTHON_BIN" - "$DESKTOP_TRAMPOLINE_GYP" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
marker = "        'cflags': ["
needle = "          '-D_FORTIFY_SOURCE=1',"
replacement = "          '-U_FORTIFY_SOURCE',\n" + needle
start = text.find(marker)
if start < 0:
    raise SystemExit("Error: upstream desktop-trampoline Linux cflags block changed; refusing an unsafe patch.")
prefix = text[:start]
suffix = text[start:]
if suffix.count(needle) < 1:
    raise SystemExit("Error: upstream desktop-trampoline fortify flag changed; refusing an unsafe patch.")
suffix = suffix.replace(needle, replacement, 1)
path.write_text(prefix + suffix, encoding="utf-8")
PY
grep -A10 -- "'cflags': \[" "$DESKTOP_TRAMPOLINE_GYP" | grep -A1 -- "'-U_FORTIFY_SOURCE'" | grep -q -- "'-D_FORTIFY_SOURCE=1'"

# 安装官方锁定依赖并执行官方 production Electron build；官方 package.ts 没有 Linux 分支，因此不调用 yarn package。
cd "$SOURCE_DIR"
yarn install --frozen-lockfile --network-timeout 600000
NODE_ENV=production RELEASE_CHANNEL=production yarn build:prod
cd "$ROOT_DIR"

UPSTREAM_DIST="$SOURCE_DIR/dist/desktop-linux-x64"
test -x "$UPSTREAM_DIST/desktop"
test -d "$UPSTREAM_DIST/resources"
test -d "$UPSTREAM_DIST/locales"

APP_VERSION="$(node -p "require(process.argv[1]).version" "$SOURCE_DIR/app/package.json")"
if [[ -z "$APP_VERSION" ]]; then
  echo "Error: failed to read GitHub Desktop version." >&2
  exit 1
fi

echo "GitHub Desktop version: $APP_VERSION"

# GUI 烟测函数：必须真实创建可见 GitHub Desktop 窗口。
run_gui_smoke() {
  local label="$1"
  local profile="$2"
  local smoke_log="$3"
  local window_log="$4"
  shift 4

  rm -rf "$profile"
  mkdir -p "$profile"

  set +e
  xvfb-run -a bash -c '
    set -u
    profile="$1"
    smoke_log="$2"
    window_log="$3"
    shift 3

    sandbox_args=()
    if [[ "$(id -u)" -eq 0 ]]; then
      sandbox_args+=(--no-sandbox)
    fi

    ELECTRON_ENABLE_LOGGING=1 "$@" \
      "${sandbox_args[@]}" \
      --user-data-dir="$profile" \
      >"$smoke_log" 2>&1 &
    app_pid=$!
    window_found=0

    for _ in $(seq 1 45); do
      window_id="$(xdotool search --onlyvisible --name "^GitHub Desktop$" 2>/dev/null | head -n 1 || true)"
      if [[ -n "$window_id" ]] && xwininfo -id "$window_id" 2>/dev/null | grep -q "Map State: IsViewable"; then
        window_found=1
        break
      fi

      if ! kill -0 "$app_pid" 2>/dev/null; then
        wait "$app_pid"
        exit $?
      fi

      sleep 1
    done

    sleep 2
    xwininfo -root -tree >"$window_log" 2>&1 || true

    if ! kill -0 "$app_pid" 2>/dev/null; then
      wait "$app_pid"
      exit $?
    fi

    kill "$app_pid" 2>/dev/null || true
    wait "$app_pid" 2>/dev/null || true

    if [[ "$window_found" -ne 1 ]]; then
      exit 125
    fi
  ' bash "$profile" "$smoke_log" "$window_log" "$@"
  local smoke_rc=$?
  set -e

  if [[ "$smoke_rc" -ne 0 ]]; then
    echo "Error: $label GUI smoke test failed with exit code $smoke_rc." >&2
    echo "--- $smoke_log ---" >&2
    tail -n 200 "$smoke_log" >&2 || true
    echo "--- $window_log ---" >&2
    tail -n 200 "$window_log" >&2 || true
    exit "$smoke_rc"
  fi
}

# 先验证官方源码生成的 Electron 目录本身能真实创建窗口，排除 AppImage 封装层干扰。
run_gui_smoke \
  "official source build" \
  "$ROOT_DIR/smoke-source-profile" \
  "$DIST_DIR/smoke-source.log" \
  "$DIST_DIR/smoke-source-windows.log" \
  env GITHUB_DESKTOP_DISABLE_HARDWARE_ACCELERATION=1 "$UPSTREAM_DIST/desktop"

# 手工构造最小 AppDir，完整保留官方 Electron 目录的相对布局。
NATIVE_LIB_DIR="$APPDIR/usr/lib/github-desktop/lib"
mkdir -p "$APPDIR/usr/lib/github-desktop" "$NATIVE_LIB_DIR" "$APPDIR/usr/share/github-desktop"
cp -a "$UPSTREAM_DIST/." "$APPDIR/usr/lib/github-desktop/"
cp -f "$SOURCE_DIR/app/static/linux/icon-logo.png" "$APPDIR/github-desktop.png"
ln -s github-desktop.png "$APPDIR/.DirIcon"

# 官方 Linux build 中的 .node 原生模块可能依赖 libsecret 等系统动态库。
# 正式构建使用 Ubuntu 22.04：打包旧 ABI 的非基础依赖，但 GLib/GIO/GObject 必须始终使用宿主系统版本。
# Electron/GTK 会在加载 keytar 前先加载宿主 GLib；若再塞第二套同 SONAME GLib，动态加载器只会复用已加载版本，造成 ABI 混装。
NATIVE_ROOT="$APPDIR/usr/lib/github-desktop/resources/app"
mapfile -d '' -t NATIVE_MODULES < <(find "$NATIVE_ROOT" -type f -name '*.node' -print0)
if [[ ${#NATIVE_MODULES[@]} -eq 0 ]]; then
  echo "Error: no Linux native .node modules found in official build." >&2
  exit 1
fi

declare -A NATIVE_DEPS=()
for module in "${NATIVE_MODULES[@]}"; do
  echo "Native module: ${module#$APPDIR/}"
  while IFS= read -r dep; do
    [[ -n "$dep" && -f "$dep" ]] || continue
    NATIVE_DEPS["$dep"]=1
  done < <(
    ldd "$module" | awk '
      $2 == "=>" && $3 ~ /^\// { print $3 }
      $1 ~ /^\// { print $1 }
    '
  )
done

for dep in "${!NATIVE_DEPS[@]}"; do
  dep_name="$(basename "$dep")"

  # glibc/loader 与 GLib 家族必须由宿主提供；Ubuntu 22.04 编译保证只要求较老 ABI。
  case "$dep_name" in
    libc.so.6|libm.so.6|libpthread.so.0|libdl.so.2|librt.so.1|libresolv.so.2|libutil.so.1|ld-linux-x86-64.so.2|\
    libglib-2.0.so.0|libgio-2.0.so.0|libgobject-2.0.so.0|libgmodule-2.0.so.0)
      continue
      ;;
  esac

  cp -L "$dep" "$NATIVE_LIB_DIR/$dep_name"
done

# 每个 .node 只从自己的私有 lib 目录找打包的非基础依赖，不用全局 LD_LIBRARY_PATH 覆盖 Electron 系统库解析。
for module in "${NATIVE_MODULES[@]}"; do
  relative_lib="$(realpath --relative-to="$(dirname "$module")" "$NATIVE_LIB_DIR")"
  expected_rpath="\$ORIGIN/$relative_lib"
  patchelf --force-rpath --set-rpath "$expected_rpath" "$module"
  actual_rpath="$(patchelf --print-rpath "$module")"
  if [[ "$actual_rpath" != "$expected_rpath" ]]; then
    echo "Error: invalid native-module RPATH: ${module#$APPDIR/}: $actual_rpath" >&2
    exit 1
  fi
done

# 私有库之间优先从同目录解析；基础 GLib 家族未打包时自然回到宿主新版实现。
shopt -s nullglob
for bundled_lib in "$NATIVE_LIB_DIR"/*.so*; do
  if file "$bundled_lib" | grep -q 'ELF'; then
    patchelf --force-rpath --set-rpath '$ORIGIN' "$bundled_lib"
    actual_rpath="$(patchelf --print-rpath "$bundled_lib")"
    if [[ "$actual_rpath" != '$ORIGIN' ]]; then
      echo "Error: invalid bundled-library RPATH: $(basename "$bundled_lib"): $actual_rpath" >&2
      exit 1
    fi
  fi
done
shopt -u nullglob

# keytar 必须自带 libsecret，但绝不能把 GLib/GIO/GObject 本体一起带入。
test -s "$NATIVE_LIB_DIR/libsecret-1.so.0"
for host_glib in libglib-2.0.so.0 libgio-2.0.so.0 libgobject-2.0.so.0 libgmodule-2.0.so.0; do
  if [[ -e "$NATIVE_LIB_DIR/$host_glib" ]]; then
    echo "Error: host GLib library must not be bundled: $host_glib" >&2
    exit 1
  fi
done

echo "Bundled native runtime libraries:"
find "$NATIVE_LIB_DIR" -maxdepth 1 -type f -printf '  %f\n' | sort

cat > "$APPDIR/github-desktop.desktop" <<'EOF_DESKTOP'
[Desktop Entry]
Name=GitHub Desktop
Comment=Simple collaboration from your desktop
Exec=github-desktop %U
Icon=github-desktop
Type=Application
Categories=Development;RevisionControl;
Terminal=false
StartupWMClass=github-desktop
MimeType=x-scheme-handler/x-github-client;x-scheme-handler/x-github-desktop-auth;x-scheme-handler/x-github-desktop-dev-auth;
EOF_DESKTOP

# 不读取宿主系统的全局 fontconfig 缓存。
cat > "$APPDIR/usr/share/github-desktop/fonts.conf" <<'EOF_FONTCONFIG'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <dir>/usr/share/fonts</dir>
  <dir>/usr/local/share/fonts</dir>
  <dir prefix="xdg">fonts</dir>
  <dir>~/.fonts</dir>
  <cachedir prefix="xdg">github-desktop/fontconfig</cachedir>
  <include ignore_missing="yes">/etc/fonts/conf.d</include>
</fontconfig>
EOF_FONTCONFIG

# AppRun 使用官方构建出的 desktop 二进制；同时为 standalone AppImage 建立稳定的 XDG 协议处理入口。
cat > "$APPDIR/AppRun" <<'EOF_APPRUN'
#!/bin/sh
set -eu

APPDIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
export CHROME_DESKTOP=github-desktop.desktop
export GITHUB_DESKTOP_DISABLE_HARDWARE_ACCELERATION=1

# 隔离 Fontconfig 缓存，避免宿主残留的不同版本缓存影响 Electron 启动。
export FONTCONFIG_FILE="$APPDIR/usr/share/github-desktop/fonts.conf"
export FONTCONFIG_PATH="$APPDIR/usr/share/github-desktop"

if [ -n "${APPIMAGE:-}" ] && [ -n "${HOME:-}" ] && command -v xdg-mime >/dev/null 2>&1; then
  desktop_dir="$HOME/.local/share/applications"
  desktop_file="$desktop_dir/github-desktop.desktop"
  desktop_tmp="$desktop_file.tmp.$$"
  escaped_appimage="$(printf '%s' "$APPIMAGE" | sed 's/\\/\\\\/g; s/"/\\"/g')"

  mkdir -p "$desktop_dir"
  cat > "$desktop_tmp" <<EOF_USER_DESKTOP
[Desktop Entry]
Name=GitHub Desktop
Comment=Simple collaboration from your desktop
Exec="$escaped_appimage" %U
Icon=github-desktop
Type=Application
Categories=Development;RevisionControl;
Terminal=false
StartupWMClass=github-desktop
MimeType=x-scheme-handler/x-github-client;x-scheme-handler/x-github-desktop-auth;x-scheme-handler/x-github-desktop-dev-auth;
EOF_USER_DESKTOP
  mv -f "$desktop_tmp" "$desktop_file"

  xdg-mime default github-desktop.desktop x-scheme-handler/x-github-client >/dev/null 2>&1 || true
  xdg-mime default github-desktop.desktop x-scheme-handler/x-github-desktop-auth >/dev/null 2>&1 || true
  xdg-mime default github-desktop.desktop x-scheme-handler/x-github-desktop-dev-auth >/dev/null 2>&1 || true
fi

# AppImage 的 FUSE 挂载无法可靠保留 Electron chrome-sandbox 所要求的 root:4755 SUID 属性。
sandbox_arg=""
chrome_sandbox="$APPDIR/usr/lib/github-desktop/chrome-sandbox"
if [ "$(id -u)" = "0" ]; then
  sandbox_arg="--no-sandbox"
elif [ ! -e "$chrome_sandbox" ] || [ "$(stat -c '%u:%a' "$chrome_sandbox" 2>/dev/null || printf 'invalid')" != "0:4755" ]; then
  sandbox_arg="--disable-setuid-sandbox"

  if [ -r /proc/sys/kernel/unprivileged_userns_clone ] && [ "$(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null || printf '0')" != "1" ]; then
    sandbox_arg="--no-sandbox"
  elif [ -r /proc/sys/kernel/apparmor_restrict_unprivileged_userns ] && [ "$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns 2>/dev/null || printf '0')" = "1" ]; then
    sandbox_arg="--no-sandbox"
  fi
fi

if [ -n "$sandbox_arg" ]; then
  exec "$APPDIR/usr/lib/github-desktop/desktop" "$sandbox_arg" "$@"
else
  exec "$APPDIR/usr/lib/github-desktop/desktop" "$@"
fi
EOF_APPRUN
chmod +x "$APPDIR/AppRun"

# 使用 AppImage 官方 appimagetool 最新发布资产封装 AppDir，并校验 GitHub API 返回的 SHA256 digest。
IFS=$'\t' read -r APPIMAGETOOL_URL APPIMAGETOOL_DIGEST < <(
  gh api repos/AppImage/appimagetool/releases/latest \
    --jq '.assets[] | select(.name == "appimagetool-x86_64.AppImage") | [.browser_download_url, .digest] | @tsv'
)
APPIMAGETOOL="$TOOLS_DIR/appimagetool-x86_64.AppImage"

if [[ -z "$APPIMAGETOOL_URL" || ! "$APPIMAGETOOL_DIGEST" =~ ^sha256:[0-9a-fA-F]{64}$ ]]; then
  echo "Error: failed to resolve appimagetool x86_64 asset or digest." >&2
  exit 1
fi

curl -fL --retry 5 --retry-delay 2 "$APPIMAGETOOL_URL" -o "$APPIMAGETOOL"
chmod +x "$APPIMAGETOOL"
echo "${APPIMAGETOOL_DIGEST#sha256:}  $APPIMAGETOOL" | sha256sum -c -

# 固定到 AppImage 官方有明确版本号和 SHA256 的稳定 type2 runtime。
APPIMAGE_RUNTIME_TAG="20251108"
APPIMAGE_RUNTIME="$TOOLS_DIR/runtime-x86_64"
APPIMAGE_RUNTIME_URL="https://github.com/AppImage/type2-runtime/releases/download/${APPIMAGE_RUNTIME_TAG}/runtime-x86_64"
APPIMAGE_RUNTIME_SHA256="2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d"
curl -fL --retry 5 --retry-delay 2 "$APPIMAGE_RUNTIME_URL" -o "$APPIMAGE_RUNTIME"
echo "$APPIMAGE_RUNTIME_SHA256  $APPIMAGE_RUNTIME" | sha256sum -c -

VERSION="$APP_VERSION" ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 \
  "$APPIMAGETOOL" --runtime-file "$APPIMAGE_RUNTIME" "$APPDIR" "$DIST_DIR/github-desktop.AppImage"
chmod +x "$DIST_DIR/github-desktop.AppImage"
test -s "$DIST_DIR/github-desktop.AppImage"

# 构建机先验证解包路径；workflow 之后会在独立 Ubuntu 24.04 宿主直接执行 ./github-desktop.AppImage。
run_gui_smoke \
  "final AppImage extracted runtime" \
  "$ROOT_DIR/smoke-appimage-profile" \
  "$DIST_DIR/smoke-appimage.log" \
  "$DIST_DIR/smoke-appimage-windows.log" \
  env APPIMAGE_EXTRACT_AND_RUN=1 "$DIST_DIR/github-desktop.AppImage"

sha256sum "$DIST_DIR/github-desktop.AppImage" > "$DIST_DIR/github-desktop.AppImage.sha256"
printf '%s\n' "$GITHUB_DESKTOP_TAG" > "$DIST_DIR/upstream-tag.txt"
printf '%s\n' "$NODE_VERSION" > "$DIST_DIR/upstream-node-version.txt"
printf '%s\n' "$APPIMAGE_RUNTIME_TAG" > "$DIST_DIR/appimage-runtime-tag.txt"
printf '%s\n' "ubuntu-22.04" > "$DIST_DIR/linux-abi-baseline.txt"

echo "Built from official source: $GITHUB_DESKTOP_TAG"
echo "Linux ABI baseline: Ubuntu 22.04"
echo "AppImage runtime: AppImage/type2-runtime $APPIMAGE_RUNTIME_TAG"
echo "Built: $DIST_DIR/github-desktop.AppImage"
