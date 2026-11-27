#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装源码编译及运行依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" dwarfs-bin nodejs-lts-jod npm rust gtk3 webkit2gtk-4.1 libayatana-appindicator fcitx5-gtk libx11 libxi libxtst

# 清掉上次的打包目录。
"$SCRIPT_DIR/../common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir work dist

# 设置本次构建使用的源码目录。
SOURCE_DIR="$SCRIPT_DIR/work/source"

# 读取本次打包使用的版本。
KEYVIZ_TAG="$(
  bash "$SCRIPT_DIR/../common/github/download_latest_stable_release_source.sh" mulaRahul/keyviz "$SOURCE_DIR" --archive
)"
VERSION="${KEYVIZ_TAG#v}"

# 本程序专属处理：按顺序应用全部独立源码补丁，上游源码变化时在编译前主动停止。
python "$SCRIPT_DIR/patches/01_key_event.py" "$SOURCE_DIR"
python "$SCRIPT_DIR/patches/02_app_state.py" "$SOURCE_DIR"
python "$SCRIPT_DIR/patches/03_window_title.py" "$SOURCE_DIR"
python "$SCRIPT_DIR/patches/04_linux_gtk.py" "$SOURCE_DIR"
python "$SCRIPT_DIR/patches/05_linux_overlay.py" "$SOURCE_DIR"

# 本程序专属处理：集中核对全部补丁落地，防止遗漏或历史方案混入。
grep -Fq 'KEY_EVENT_STORE = "key_event_store_anylinux_v1"' "$SOURCE_DIR/src/stores/key_event.ts"
grep -Fq 'filter: "none"' "$SOURCE_DIR/src/stores/key_event.ts"
grep -Fq 'store.get("key_event_store_anylinux_v1")' "$SOURCE_DIR/src-tauri/src/app/state.rs"
grep -Fq '"title": "Keyviz Overlay"' "$SOURCE_DIR/src-tauri/tauri.conf.json"
grep -Fq '[target.'\''cfg(target_os = "linux")'\''.dependencies]' "$SOURCE_DIR/src-tauri/Cargo.toml"
grep -Fq 'gtk = { version = "0.18", features = ["v3_24"] }' "$SOURCE_DIR/src-tauri/Cargo.toml"
grep -Fq 'gdk_window.set_override_redirect(true);' "$SOURCE_DIR/src-tauri/src/app/window.rs"
grep -Fq '.set_focusable(false)' "$SOURCE_DIR/src-tauri/src/app/window.rs"
grep -Fq 'Failed to enable Linux click-through' "$SOURCE_DIR/src-tauri/src/app/window.rs"
if grep -Fq 'set_pass_through' "$SOURCE_DIR/src-tauri/src/app/window.rs"; then
  echo "错误：Keyviz Linux Overlay 不应继续使用旧的 GDK pass-through 方案。" >&2
  exit 1
fi
if grep -Fq 'i3-msg' "$SOURCE_DIR/src-tauri/src/app/window.rs"; then
  echo "错误：Keyviz 源码中不应包含 i3-msg。" >&2
  exit 1
fi

# 本程序专属处理：按锁文件安装前端依赖并核对 Linux X11 构建配置。
(
  cd "$SOURCE_DIR"
  npm ci
  grep -Fq 'target_os = "linux"' src-tauri/crates/rdev/Cargo.toml
  grep -Fq 'x11 = ' src-tauri/crates/rdev/Cargo.toml
)

# 本程序专属处理：Cargo.toml 新增 Linux gtk 直接依赖后同步锁文件，并校验 gtk 0.18 与 --locked 一致性。
(
  cd "$SOURCE_DIR/src-tauri"
  cargo metadata --format-version 1 > "$SCRIPT_DIR/work/cargo-metadata.json"
  jq -e '.packages[] | select(.name == "gtk" and (.version | startswith("0.18.")))' "$SCRIPT_DIR/work/cargo-metadata.json" >/dev/null
  cargo metadata --locked --format-version 1 >/dev/null
  rm -f "$SCRIPT_DIR/work/cargo-metadata.json"
)

# 本程序专属处理：仅通过 Tauri 编译 release 主程序，不调用 Tauri 自带的 AppImage bundler。
(
  cd "$SOURCE_DIR"
  npm run tauri -- build --no-bundle
)

# 本程序专属处理：安装编译产物、图标和桌面入口到系统路径，供 quick-sharun 收集。
KEYVIZ_BIN="$SOURCE_DIR/src-tauri/target/release/keyviz"
test -x "$KEYVIZ_BIN"
file "$KEYVIZ_BIN" | grep -Fq 'ELF 64-bit'
install -Dm755 "$KEYVIZ_BIN" /usr/bin/keyviz
install -Dm644 "$SOURCE_DIR/src-tauri/icons/128x128.png" /usr/share/pixmaps/keyviz.png
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

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 使用系统里装好的图标。
export ICON=/usr/share/pixmaps/keyviz.png
# 使用系统里装好的桌面入口文件。
export DESKTOP=/usr/share/applications/keyviz.desktop
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME=keyviz.AppImage
# 让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS=keyviz
# 这是 GTK 3 程序。输入模块由 quick-sharun 自己收集。
export DEPLOY_GTK=1
# 本程序专属处理：保留原有的 OpenGL 部署设置。
export DEPLOY_OPENGL=1
# 本程序专属处理：保留必需的 WebKitGTK 部署设置。
export DEPLOY_WEBKIT2GTK=1
# 本程序专属处理：使用构建系统提供的 WebKitGTK 运行目录。
export WEBKIT2GTK_DIR=/usr/lib/webkit2gtk-4.1

# 收集程序及其运行依赖。
quick-sharun /usr/bin/keyviz /usr/bin/xdg-open /usr/bin/xdg-mime

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
ENV

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" dist/keyviz.AppImage "$VERSION" dist/version.txt
