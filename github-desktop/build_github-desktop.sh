#!/usr/bin/env bash
set -Eeuo pipefail

# GitHub Desktop Linux AppImage：直接使用 GitHub 官方 desktop/desktop 最新稳定源码构建。
# 官方源码已经保留 Linux Electron build 路径；这里仅补 Linux 可执行文件名、图标与 AppImage 打包层。

ARCH="$(uname -m)"
if [[ "$ARCH" != "x86_64" ]]; then
  echo "Error: this script currently supports x86_64 only." >&2
  exit 1
fi
export ARCH=x86_64
export npm_config_arch=x64

ROOT_DIR="$PWD"
SOURCE_DIR="$ROOT_DIR/source"
TOOLS_DIR="$ROOT_DIR/tools"
DIST_DIR="$ROOT_DIR/dist"

rm -rf "$SOURCE_DIR" "$TOOLS_DIR" "$DIST_DIR"
mkdir -p "$TOOLS_DIR" "$DIST_DIR"

# 安装 GitHub Desktop 源码编译、Electron 运行烟测与 Linux 图标处理所需依赖。
yay -S --noconfirm --needed \
  base-devel git curl xz python pkgconf \
  libsecret gtk3 nss alsa-lib cups libxkbcommon libxrandr mesa \
  icoutils imagemagick \
  xorg-server-xvfb xorg-xauth

# 自动跟随 GitHub Desktop 官方最新稳定 Release；可用 GITHUB_DESKTOP_TAG 手动固定 tag。
if [[ -z "${GITHUB_DESKTOP_TAG:-}" ]]; then
  GITHUB_DESKTOP_TAG="$(gh api repos/desktop/desktop/releases/latest --jq .tag_name)"
fi
if [[ ! "$GITHUB_DESKTOP_TAG" =~ ^release-[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: invalid GitHub Desktop stable tag: $GITHUB_DESKTOP_TAG" >&2
  exit 1
fi

echo "GitHub Desktop tag: $GITHUB_DESKTOP_TAG"

# 只拉取指定稳定 tag，并递归取得官方仓库要求的 gemoji / gitignore / choosealicense 子模块。
git clone \
  --depth=1 \
  --branch "$GITHUB_DESKTOP_TAG" \
  --recurse-submodules \
  --shallow-submodules \
  https://github.com/desktop/desktop.git \
  "$SOURCE_DIR"

# 严格使用该稳定 tag 声明的 Node 版本，避免 CI 上系统 Node 漂移导致 native module ABI 不一致。
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

# 使用 Yarn Classic，与 GitHub Desktop 当前 yarn.lock / 构建脚本保持一致。
npm install --global --prefix "$TOOLS_DIR/yarn" yarn@1.22.22
export PATH="$TOOLS_DIR/yarn/bin:$PATH"

node --version
yarn --version

# 从官方 Windows ICO 提取 Linux PNG；同时给 electron-packager 和 electron-builder 使用。
mkdir -p "$TOOLS_DIR/icons" "$SOURCE_DIR/app/static/linux/logos"
icotool -x -o "$TOOLS_DIR/icons" "$SOURCE_DIR/app/static/logos/prod/icon-logo.ico"

BEST_ICON="$(find "$TOOLS_DIR/icons" -type f -name '*.png' -printf '%s %p\n' | sort -nr | head -n1 | cut -d' ' -f2-)"
if [[ -z "$BEST_ICON" || ! -s "$BEST_ICON" ]]; then
  echo "Error: failed to extract GitHub Desktop PNG icon." >&2
  exit 1
fi
cp -f "$BEST_ICON" "$SOURCE_DIR/app/static/logos/prod/icon-logo.png"

# 为 electron-builder 准备按像素尺寸命名的 Linux 图标目录。
while IFS= read -r icon; do
  size="$(magick identify -format '%wx%h' "$icon" 2>/dev/null || true)"
  if [[ "$size" =~ ^[0-9]+x[0-9]+$ ]]; then
    cp -f "$icon" "$SOURCE_DIR/app/static/linux/logos/${size}.png"
  fi
done < <(find "$TOOLS_DIR/icons" -type f -name '*.png' | sort)

test -s "$SOURCE_DIR/app/static/logos/prod/icon-logo.png"
test -n "$(find "$SOURCE_DIR/app/static/linux/logos" -maxdepth 1 -type f -name '*.png' -print -quit)"

# 官方源码在 Linux build 路径中仍把二进制暂命名为 desktop；仅改成 Linux 社区约定的 github-desktop。
python - "$SOURCE_DIR/script/dist-info.ts" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
old = """  } else if (process.platform === 'linux') {\n    return 'desktop'\n  } else {"""
new = """  } else if (process.platform === 'linux') {\n    return 'github-desktop'\n  } else {"""
if old not in text:
    raise SystemExit("Error: upstream Linux executable-name block changed; refusing an unsafe blind patch.")
path.write_text(text.replace(old, new, 1), encoding="utf-8")
PY

grep -A2 "process.platform === 'linux'" "$SOURCE_DIR/script/dist-info.ts" | grep -q "return 'github-desktop'"

# 安装官方锁定依赖并执行官方 production Electron build；不调用官方 package.ts，因为它没有 Linux 分支。
cd "$SOURCE_DIR"
yarn install --frozen-lockfile --network-timeout 600000
NODE_ENV=production RELEASE_CHANNEL=production yarn build:prod
cd "$ROOT_DIR"

UPSTREAM_DIST="$SOURCE_DIR/dist/github-desktop-linux-x64"
test -x "$UPSTREAM_DIST/github-desktop"
test -d "$UPSTREAM_DIST/resources"

APP_VERSION="$(node -p "require(process.argv[1]).version" "$SOURCE_DIR/app/package.json")"
if [[ -z "$APP_VERSION" ]]; then
  echo "Error: failed to read GitHub Desktop version." >&2
  exit 1
fi

echo "GitHub Desktop version: $APP_VERSION"

# 使用 electron-builder 的 --prepackaged 模式只做 Linux AppImage 封装，不重新编译或替换官方应用代码。
cat > "$TOOLS_DIR/electron-builder-linux.yml" <<'EOF_CONFIG'
artifactName: 'github-desktop.AppImage'
linux:
  category: 'Development;RevisionControl'
  icon: 'app/static/linux/logos'
  mimeTypes:
    - x-scheme-handler/x-github-client
    - x-scheme-handler/x-github-desktop-auth
    - x-scheme-handler/x-github-desktop-dev-auth
  target:
    - AppImage
EOF_CONFIG

cd "$SOURCE_DIR"
npx --yes electron-builder@26.0.12 \
  --prepackaged "$UPSTREAM_DIST" \
  --x64 \
  --config "$TOOLS_DIR/electron-builder-linux.yml"
cd "$ROOT_DIR"

BUILT_APPIMAGE="$(find "$SOURCE_DIR/dist" -maxdepth 1 -type f -name 'github-desktop.AppImage' -print -quit)"
if [[ -z "$BUILT_APPIMAGE" || ! -s "$BUILT_APPIMAGE" ]]; then
  echo "Error: electron-builder did not produce github-desktop.AppImage." >&2
  exit 1
fi

cp -f "$BUILT_APPIMAGE" "$DIST_DIR/github-desktop.AppImage"
chmod +x "$DIST_DIR/github-desktop.AppImage"

# 在 Xvfb 下做 30 秒启动烟测；124 表示 GUI 一直存活到 timeout，属于预期通过结果。
set +e
APPIMAGE_EXTRACT_AND_RUN=1 timeout 30s xvfb-run -a \
  "$DIST_DIR/github-desktop.AppImage" \
  --no-sandbox \
  --disable-gpu \
  --user-data-dir="$ROOT_DIR/smoke-profile" \
  > "$DIST_DIR/smoke-test.log" 2>&1
SMOKE_RC=$?
set -e

if [[ "$SMOKE_RC" -ne 0 && "$SMOKE_RC" -ne 124 ]]; then
  echo "Error: GitHub Desktop AppImage smoke test failed with exit code $SMOKE_RC." >&2
  tail -n 160 "$DIST_DIR/smoke-test.log" >&2 || true
  exit "$SMOKE_RC"
fi

sha256sum "$DIST_DIR/github-desktop.AppImage" > "$DIST_DIR/github-desktop.AppImage.sha256"
printf '%s\n' "$GITHUB_DESKTOP_TAG" > "$DIST_DIR/upstream-tag.txt"
printf '%s\n' "$NODE_VERSION" > "$DIST_DIR/upstream-node-version.txt"

echo "Built: $DIST_DIR/github-desktop.AppImage"
