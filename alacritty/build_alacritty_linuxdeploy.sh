#!/usr/bin/env bash
set -e

# 切换到脚本所在目录。
cd "$(dirname "$0")"

# 安装 Alacritty 官方要求的编译依赖，以及 XKB/X11 运行时和下载源码所需工具。
sudo apt-get update
sudo apt-get install -y build-essential ca-certificates cmake curl git libfontconfig1-dev libx11-data libxcb-xfixes0-dev libxkbcommon-dev libxkbcommon-x11-0 pkg-config python3 xkb-data

# 安装 Rust 工具链。
curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal

# 加载 Rust 环境。
. "$HOME/.cargo/env"

# 获取 Alacritty 最新正式版标签。
TAG="$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/alacritty/alacritty/releases/latest)"
TAG="${TAG##*/}"

# 下载 Alacritty 最新正式版源码。
git clone --depth 1 --branch "$TAG" https://github.com/alacritty/alacritty.git alacritty-src

# X11 + i3 + fcitx5 输入稳定性修复：恢复 Alacritty 官方曾使用的“X11 运行期间不反复开关 IME”保护。
# winit 的 X11 set_ime_allowed() 会销毁并重建 XIC；反复切换 i3 工作区会触发 Focused(false/true)，可能导致后续键盘事件丢失。
git -C alacritty-src apply --check "$PWD/patches/0001-x11-keep-ime-enabled.patch"
git -C alacritty-src apply "$PWD/patches/0001-x11-keep-ime-enabled.patch"

# 进入 Alacritty 源码目录。
cd alacritty-src

# 直接编译 Alacritty。
cargo build --release

# 返回打包脚本目录。
cd ..

# 按 desktop 文件中的 Icon=Alacritty 准备对应名称的官方图标。
cp "$PWD/alacritty-src/extra/logo/alacritty-term.svg" "$PWD/Alacritty.svg"

# 下载 linuxdeploy。
curl -fL https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage -o linuxdeploy-x86_64.AppImage

# 赋予 linuxdeploy 执行权限。
chmod +x linuxdeploy-x86_64.AppImage

# 创建输出目录，并放入与包内 xkbcommon-x11 同一环境的 XKB/Compose 数据。
mkdir -p AppDir/usr/share/X11 dist
cp -a /usr/share/X11/xkb AppDir/usr/share/X11/
cp -a /usr/share/X11/locale AppDir/usr/share/X11/

# 使用预写的 AppRun，并补入 Alacritty 运行时动态加载的 xkbcommon-x11 后生成 AppImage。
APPIMAGE_EXTRACT_AND_RUN=1 ARCH=x86_64 LDAI_OUTPUT="$PWD/dist/alacritty.AppImage" ./linuxdeploy-x86_64.AppImage --appdir AppDir --executable "$PWD/alacritty-src/target/release/alacritty" --library /usr/lib/x86_64-linux-gnu/libxkbcommon-x11.so.0 --desktop-file "$PWD/alacritty-src/extra/linux/Alacritty.desktop" --icon-file "$PWD/Alacritty.svg" --custom-apprun "$PWD/AppRun" --output appimage
