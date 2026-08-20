#!/usr/bin/env bash
set -Eeuo pipefail

trap 'rc=$?; echo "::error file=Keyviz/build_keyviz.sh,line=${LINENO}::命令失败（退出码 ${rc}）：${BASH_COMMAND}" >&2; exit "$rc"' ERR

# 目录结构：
#   仓库根目录/Keyviz/build_keyviz.sh -> 本文件，实际构建逻辑
#   仓库根目录/Keyviz/version.conf    -> 上游版本与 tao 固定版本
#   仓库根目录/Keyviz/patches/        -> 各项源码修补，彼此独立
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PATCH_DIR="$SCRIPT_DIR/patches"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/version.conf"

cd "$ROOT"

# 仅构建当前仓库统一使用的 x86_64 AppImage。
if [[ "$(uname -m)" != "x86_64" ]]; then
  echo "错误：Keyviz AppImage 当前只构建 x86_64。" >&2
  exit 1
fi

# 本脚本固定在 anylinux 的 Arch Linux 容器中运行，不使用 Tauri 自带 AppImage bundler。
if [[ ! -r /etc/os-release ]]; then
  echo "错误：无法识别构建系统。" >&2
  exit 1
fi
. /etc/os-release
if [[ "${ID:-}" != "arch" ]]; then
  echo "错误：Keyviz/build_keyviz.sh 必须在 Arch Linux anylinux 构建环境中运行。" >&2
  exit 1
fi

# quick-sharun 由 pkgforge anylinux-setup-action 提供；缺失时直接停止，避免退回其他打包方式。
command -v yay >/dev/null
command -v quick-sharun >/dev/null
command -v python >/dev/null

BUILD_DIR="$ROOT/.keyviz-build"
OUTDIR="$ROOT/dist"
OUTFILE="$OUTDIR/keyviz.AppImage"

# 清理本次 Keyviz 构建目录和旧产物，不影响仓库中的其他 AppImage。
rm -rf "$ROOT/AppDir" "$BUILD_DIR" "$ROOT/squashfs-root"
mkdir -p "$OUTDIR"
rm -f "$OUTFILE"

# 安装 quick-sharun、Tauri、WebKitGTK 4.1 与 Keyviz X11 后端需要的 Arch Linux 依赖。
yay -S --noconfirm --needed \
  base-devel \
  wget \
  binutils \
  patchelf \
  coreutils \
  appstream-glib \
  desktop-file-utils \
  util-linux \
  zsync \
  dwarfs-bin \
  git \
  nodejs-lts-jod \
  npm \
  rust \
  python \
  pkgconf \
  openssl \
  gtk3 \
  webkit2gtk-4.1 \
  libayatana-appindicator \
  libx11 \
  libxi \
  libxtst \
  xdg-utils

# 固定汉化版提交，避免构建时拉到未经检查的新代码。
git clone --filter=blob:none "$KEYVIZ_REPO" "$BUILD_DIR"
git -C "$BUILD_DIR" checkout --detach "$KEYVIZ_REF"
test "$(git -C "$BUILD_DIR" rev-parse HEAD)" = "$KEYVIZ_REF"

# 所有 anylinux 源码修补都独立存放在 patches/。
# 每个补丁都做严格上下文检查；以后升级上游时若源码变化，会在编译前明确停止。
for patch_script in \
  "$PATCH_DIR/01_key_event.py" \
  "$PATCH_DIR/02_app_state.py" \
  "$PATCH_DIR/03_window_title.py" \
  "$PATCH_DIR/04_linux_gtk.py" \
  "$PATCH_DIR/05_linux_overlay.py"
do
  python "$patch_script" "$BUILD_DIR"
done

KEY_EVENT_FILE="$BUILD_DIR/src/stores/key_event.ts"
APP_STATE_FILE="$BUILD_DIR/src-tauri/src/app/state.rs"
TAURI_CONFIG_FILE="$BUILD_DIR/src-tauri/tauri.conf.json"
WINDOW_FILE="$BUILD_DIR/src-tauri/src/app/window.rs"
CARGO_FILE="$BUILD_DIR/src-tauri/Cargo.toml"

# 对全部修补做一次集中静态核对，防止遗漏、重复或历史方案混入。
grep -Fq 'KEY_EVENT_STORE = "key_event_store_anylinux_v1"' "$KEY_EVENT_FILE"
grep -Fq 'filter: "none"' "$KEY_EVENT_FILE"
grep -Fq 'store.get("key_event_store_anylinux_v1")' "$APP_STATE_FILE"
grep -Fq '"title": "Keyviz Overlay"' "$TAURI_CONFIG_FILE"
grep -Fq '[target.'\''cfg(target_os = "linux")'\''.dependencies]' "$CARGO_FILE"
grep -Fq 'gtk = { version = "0.18", features = ["v3_24"] }' "$CARGO_FILE"
grep -Fq 'gdk_window.set_override_redirect(true);' "$WINDOW_FILE"
grep -Fq '.set_focusable(false)' "$WINDOW_FILE"
grep -Fq 'Failed to enable Linux click-through' "$WINDOW_FILE"

if grep -Fq 'set_pass_through' "$WINDOW_FILE"; then
  echo "错误：Keyviz Linux Overlay 不应继续使用旧的 GDK pass-through 方案。" >&2
  exit 1
fi
if grep -Fq 'i3-msg' "$WINDOW_FILE"; then
  echo "错误：Keyviz 源码中不应包含 i3-msg。" >&2
  exit 1
fi

# 使用汉化版锁文件安装完全一致的前端依赖。
cd "$BUILD_DIR"
npm ci

# 在进入完整 Rust 编译前先检查版本和 Linux/X11 构建配置。
ACTUAL_VERSION="$(node -p "require('./src-tauri/tauri.conf.json').version")"
test "$ACTUAL_VERSION" = "$KEYVIZ_VERSION"
grep -Fq 'target_os = "linux"' src-tauri/crates/rdev/Cargo.toml
grep -Fq 'x11 = ' src-tauri/crates/rdev/Cargo.toml

# 汉化版当前锁定 tao 0.34.5；固定升级到同一 0.34 系列的稳定基线。
cd "$BUILD_DIR/src-tauri"
cargo update -p tao --precise "$TAO_VERSION"

# Cargo.toml 新增 Linux gtk 直接依赖后，同步锁文件并再次用 --locked 校验。
cargo metadata --format-version 1 > "$BUILD_DIR/.cargo-metadata.json"
jq -e '.packages[] | select(.name == "gtk" and (.version | startswith("0.18.")))' "$BUILD_DIR/.cargo-metadata.json" >/dev/null
jq -e --arg tao "$TAO_VERSION" '.packages[] | select(.name == "tao" and .version == $tao)' "$BUILD_DIR/.cargo-metadata.json" >/dev/null
cargo metadata --locked --format-version 1 >/dev/null
rm -f "$BUILD_DIR/.cargo-metadata.json"

# Tauri 只负责编译 release 程序，不调用 Tauri/linuxdeploy 的 AppImage bundler。
cd "$BUILD_DIR"
npm run tauri -- build --no-bundle

KEYVIZ_BIN="$BUILD_DIR/src-tauri/target/release/keyviz"
test -x "$KEYVIZ_BIN"
file "$KEYVIZ_BIN" | grep -Fq 'ELF 64-bit'

# 按 quick-sharun 的稳定方式先安装到 /usr，再从系统安装路径部署到 AppDir。
install -Dm755 "$KEYVIZ_BIN" /usr/bin/keyviz
install -Dm644 "$BUILD_DIR/src-tauri/icons/128x128.png" /usr/share/pixmaps/keyviz.png
install -d /usr/share/applications

cat > /usr/share/applications/keyviz.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Keyviz
Comment=Visualize keyboard and mouse input
Exec=keyviz
Icon=keyviz
Terminal=false
Categories=Utility;
StartupWMClass=keyviz
EOF

desktop-file-validate /usr/share/applications/keyviz.desktop

cd "$ROOT"

ARCH="$(uname -m)"
export ARCH
export ICON=/usr/share/pixmaps/keyviz.png
export DESKTOP=/usr/share/applications/keyviz.desktop
export OUTPATH="$OUTDIR"
export OUTNAME="keyviz.AppImage"
export STARTUPWMCLASS=keyviz

# 复用仓库现有 Tauri/WebKitGTK quick-sharun 基线，完整带入 GTK、OpenGL 与 WebKitGTK 子进程目录。
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_WEBKIT2GTK=1
export WEBKIT2GTK_DIR=/usr/lib/webkit2gtk-4.1

# quick-sharun 收集 Keyviz、xdg-open 与 xdg-mime 依赖并生成 AppDir。
quick-sharun \
  /usr/bin/keyviz \
  /usr/bin/xdg-open \
  /usr/bin/xdg-mime

# 使用 anylinux/quick-sharun 生成最终固定名称 keyviz.AppImage。
quick-sharun --make-appimage

# 检查最终产物名称、ELF runtime、AppRun 和 Keyviz 主程序，防止发布不完整 AppImage。
test -s "$OUTFILE"
chmod +x "$OUTFILE"
file "$OUTFILE" | grep -Fq 'ELF 64-bit'
"$OUTFILE" --appimage-extract >/dev/null
test -x "$ROOT/squashfs-root/AppRun"
test -x "$ROOT/squashfs-root/bin/keyviz"
rm -rf "$ROOT/squashfs-root"

echo "Keyviz 汉化版 AppImage 构建完成：$OUTFILE"
