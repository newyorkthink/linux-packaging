#!/usr/bin/env bash
set -Eeuo pipefail

# DeepSeek Harness 官方 Linux AppImage：仅封装官方 @deepseek-ai/dsh 与 Node 运行时。
# npm 仅用于 GitHub Actions 构建阶段；最终 AppImage 在用户机器上不需要 Node/npm。

ARCH="$(uname -m)"
if [[ "$ARCH" != "x86_64" ]]; then
  echo "Error: this script currently supports x86_64 only." >&2
  exit 1
fi
export ARCH

rm -rf AppDir dist deepseek-harness deepseek-harness.desktop deepseek-harness.svg quick-sharun
mkdir -p AppDir/opt/deepseek-harness dist

# 安装构建与 AnyLinux 打包依赖；Node 会一起封装进 AppImage。
yay -S --noconfirm --needed \
  base-devel binutils cmake curl file git nodejs npm patchelf pkgconf python wget zsync

# 自动跟随 DeepSeek 官方 npm 发布的最新 @deepseek-ai/dsh；也允许手动通过 DSH_VERSION 固定版本。
if [[ -z "${DSH_VERSION:-}" ]]; then
  DSH_VERSION="$(npm view @deepseek-ai/dsh version)"
fi
if [[ -z "$DSH_VERSION" ]]; then
  echo "Error: failed to resolve @deepseek-ai/dsh version." >&2
  exit 1
fi

echo "DeepSeek Harness version: $DSH_VERSION"
echo "Node version: $(node --version)"
echo "npm version: $(npm --version)"

RUNTIME_ROOT="$PWD/AppDir/opt/deepseek-harness"
cat > "$RUNTIME_ROOT/package.json" <<EOF_PACKAGE
{
  "name": "deepseek-harness-appimage-runtime",
  "private": true,
  "version": "0.0.0",
  "dependencies": {
    "@deepseek-ai/dsh": "$DSH_VERSION"
  },
  "allowScripts": {
    "@deepseek-ai/dsh-subprocess-local": true,
    "@google/genai": true,
    "koffi": true,
    "node-pty": true,
    "protobufjs": true
  }
}
EOF_PACKAGE

# npm 12 默认禁止依赖安装脚本；上面的 allowScripts 仅放行 DSH 当前正式依赖所需脚本。
# 所有 npm 操作都发生在构建机，用户侧无需 npm。
npm install \
  --prefix "$RUNTIME_ROOT" \
  --omit=dev \
  --include=optional \
  --no-audit \
  --no-fund

DSH_ENTRY="$RUNTIME_ROOT/node_modules/@deepseek-ai/dsh/lib/bin.js"
DSH_PACKAGE="$RUNTIME_ROOT/node_modules/@deepseek-ai/dsh/package.json"
test -f "$DSH_ENTRY"
test -f "$DSH_PACKAGE"

INSTALLED_VERSION="$(node -p "require(process.argv[1]).version" "$DSH_PACKAGE")"
if [[ "$INSTALLED_VERSION" != "$DSH_VERSION" ]]; then
  echo "Error: installed DSH version $INSTALLED_VERSION does not match requested $DSH_VERSION." >&2
  exit 1
fi

# AppImage 的主入口：无参数时启动官方 `dsh web --no-open`，避免冷启动阶段自动弹出浏览器；有参数时完整透传给官方 dsh CLI。
cat > ./deepseek-harness <<'EOF_LAUNCHER'
#!/bin/sh
set -eu

: "${APPDIR:?APPDIR is required}"
DSH_ENTRY="$APPDIR/opt/deepseek-harness/node_modules/@deepseek-ai/dsh/lib/bin.js"
if [ ! -f "$DSH_ENTRY" ]; then
  echo "DeepSeek Harness runtime is missing: $DSH_ENTRY" >&2
  exit 1
fi

# 配置、会话和凭据继续保存在用户自己的 ~/.dsh，升级 AppImage 不会覆盖。
export DSH_HOME="${DSH_HOME:-$HOME/.dsh}"

if [ "$#" -eq 0 ]; then
  set -- web --no-open
fi

exec "$APPDIR/bin/node" "$DSH_ENTRY" "$@"
EOF_LAUNCHER
chmod +x ./deepseek-harness

# 使用 DeepSeek Harness 官方仓库自带图标，不引入第三方桌面项目资源。
wget --retry-connrefused --tries=30 \
  https://raw.githubusercontent.com/deepseek-ai/deepseek-harness/master/apps/web/public/favicon.svg \
  -O ./deepseek-harness.svg
grep -q '<svg' ./deepseek-harness.svg

cat > ./deepseek-harness.desktop <<EOF_DESKTOP
[Desktop Entry]
Name=DeepSeek Harness
Comment=Official DeepSeek Harness local Web UI
Exec=deepseek-harness
Terminal=true
Type=Application
Icon=deepseek-harness
Categories=Development;
StartupNotify=false
X-AppImage-Version=$DSH_VERSION
EOF_DESKTOP

echo "$DSH_VERSION" > ~/version

export APPNAME="DeepSeek Harness"
export MAIN_BIN=deepseek-harness
export ICON="$PWD/deepseek-harness.svg"
export DESKTOP="$PWD/deepseek-harness.desktop"
export OUTPATH="$PWD/dist"
export OUTNAME="deepseek-harness.AppImage"
export DEPLOY_DATADIR=0
export STRACE_BINARY=node
export STRACE_FLAGS="$DSH_ENTRY --help"

# 让 quick-sharun 收集 Node 及 npm 运行时里所有当前 glibc 可执行 ELF 组件需要的动态库。
# 某些可选依赖同时携带 glibc 与动态 musl 版本；Arch CI 只应部署 glibc 版本。
DEPLOY_TARGETS=(/usr/bin/node ./deepseek-harness)
SKIPPED_MUSL=0
while IFS= read -r -d '' candidate; do
  if ! LC_ALL=C file -Lb "$candidate" | grep -q '^ELF '; then
    continue
  fi

  # 静态 musl 工具（例如 DeepSeek 官方 landlock-run）可以直接运行；这里只跳过依赖 musl loader/libc 的动态 ELF。
  if readelf -d "$candidate" 2>/dev/null | grep -Eq 'Shared library: \[(libc\.musl-|ld-musl)'; then
    echo "Skip dynamic musl ELF: $candidate"
    SKIPPED_MUSL=$((SKIPPED_MUSL + 1))
    continue
  fi

  DEPLOY_TARGETS+=("$candidate")
done < <(find "$RUNTIME_ROOT/node_modules" -type f \( -name '*.node' -o -name '*.so' -o -name '*.so.*' -o -perm -111 \) -print0)

echo "Native/ELF deployment targets: ${#DEPLOY_TARGETS[@]}"
echo "Skipped dynamic musl ELF targets: $SKIPPED_MUSL"
quick-sharun "${DEPLOY_TARGETS[@]}"
quick-sharun --make-appimage

test -s ./dist/deepseek-harness.AppImage
chmod +x ./dist/deepseek-harness.AppImage

# 只做 CLI 启动烟测，避免 CI 真正拉起长期 Web 服务。
APPIMAGE_EXTRACT_AND_RUN=1 timeout 30s \
  ./dist/deepseek-harness.AppImage --help \
  > ./dist/smoke-help.txt 2>&1

grep -Eqi 'dsh|deepseek|web' ./dist/smoke-help.txt
sha256sum ./dist/deepseek-harness.AppImage > ./dist/deepseek-harness.AppImage.sha256

echo "Built: $PWD/dist/deepseek-harness.AppImage"
