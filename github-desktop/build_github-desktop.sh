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

# 安装官方源码编译、Linux 运行和 GUI 窗口烟测所需依赖。
yay -S --noconfirm --needed \
  base-devel git curl xz python pkgconf \
  libsecret gtk3 nss alsa-lib cups libxkbcommon libxrandr mesa \
  fontconfig xdg-utils xorg-server-xvfb xorg-xauth xorg-xwininfo xdotool

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
python - "$SOURCE_DIR/app/src/main-process/main.ts" <<'PY'
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
    # GitHub Actions 的 AnyLinux 容器以 root 运行，Electron root 模式只能在烟测时加 --no-sandbox。
    # 普通用户实际启动 AppImage 时不会自动添加该参数。
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

# 先验证官方源码生成的 Electron 目录本身能按官方机制关闭硬件加速后真实创建窗口，排除 AppImage 封装层干扰。
run_gui_smoke \
  "official source build" \
  "$ROOT_DIR/smoke-source-profile" \
  "$DIST_DIR/smoke-source.log" \
  "$DIST_DIR/smoke-source-windows.log" \
  env GITHUB_DESKTOP_DISABLE_HARDWARE_ACCELERATION=1 "$UPSTREAM_DIST/desktop"

# 手工构造最小 AppDir，完整保留官方 Electron 目录的相对布局，避免二次打包工具改写内部可执行入口。
mkdir -p "$APPDIR/usr/lib/github-desktop" "$APPDIR/usr/share/github-desktop"
cp -a "$UPSTREAM_DIST/." "$APPDIR/usr/lib/github-desktop/"
cp -f "$SOURCE_DIR/app/static/linux/icon-logo.png" "$APPDIR/github-desktop.png"
ln -s github-desktop.png "$APPDIR/.DirIcon"

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
# 某些滚动发行版/降级后的系统会出现“缓存由更高版本 Fontconfig 生成”的冲突，Electron 可能因此长时间卡在启动阶段。
# 这里仅复用宿主字体目录和规则，缓存写入用户自己的 GitHub Desktop 专用目录。
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

# GitHub Desktop 官方源码原生识别这个变量并调用 app.disableHardwareAcceleration()。
# Linux AppImage 默认启用它，避免 Electron GPU/renderer 初始化异常时主窗口永久停留在 show:false。
export GITHUB_DESKTOP_DISABLE_HARDWARE_ACCELERATION=1

# 隔离 Fontconfig 缓存：避免宿主系统残留的更高版本缓存导致 Electron 启动异常或长时间卡住。
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

exec "$APPDIR/usr/lib/github-desktop/desktop" "$@"
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

# 固定到 AppImage 官方最后一个有明确版本号和 SHA256 digest 的稳定 type2 runtime，
# 避免 appimagetool 自动跟随 continuous runtime 后把尚未验证的运行时回归带给最终用户。
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

# AnyLinux 构建容器里没有可靠的宿主 FUSE 条件，因此这里验证最终 AppImage 的“解包运行”路径；
# 真正的直接 ./github-desktop.AppImage 验证由 workflow 的 Ubuntu 宿主机独立 Job 完成，不能再用此步骤冒充真实直启测试。
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

echo "Built from official source: $GITHUB_DESKTOP_TAG"
echo "AppImage runtime: AppImage/type2-runtime $APPIMAGE_RUNTIME_TAG"
echo "Built: $DIST_DIR/github-desktop.AppImage"
