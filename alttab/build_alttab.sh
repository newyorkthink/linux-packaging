#!/usr/bin/env bash
set -euo pipefail

# 稳定基线说明：
# - 只使用 sagb/alttab 官方 v1.8.0 源码，不依赖 AUR 的 alttab/alttab-git 包。
# - 固定并校验官方源码归档 SHA-256，避免上游内容异常时继续构建。
# - 使用 Arch Linux 官方仓库提供的构建/运行依赖。
# - 使用 quick-sharun 生成 AppImage，并在 Xvfb 中执行 alttab -h 做运行时验证。

# 清理上一次构建生成的 AppDir。
rm -rf AppDir || true

# 创建最终输出目录。
mkdir -p dist

# 获取当前系统架构。
ARCH="$(uname -m)"

# 导出 AppImage 架构。
export ARCH

# 固定上游版本。
ALTTAB_VERSION="1.8.0"

# 固定官方源码下载地址。
ALTTAB_SOURCE_URL="https://codeload.github.com/sagb/alttab/tar.gz/v${ALTTAB_VERSION}"

# 固定官方 v1.8.0 源码归档 SHA-256。
ALTTAB_SOURCE_SHA256="bd2651a23cff51497101d869c12e0209e94f95160b4f40505ae34ef3d3a695b1"

# 创建本次构建使用的临时目录。
WORKDIR="$(mktemp -d)"

# 退出时删除本次构建的临时目录。
trap 'rm -rf "$WORKDIR"' EXIT

# 定义源码归档路径。
SOURCE_ARCHIVE="$WORKDIR/alttab-v${ALTTAB_VERSION}.tar.gz"

# 安装 quick-sharun 打包、源码编译和 Xvfb 验证所需的基础依赖。
yay -S --noconfirm gcc base-devel pkgconf wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux zsync xorg-server xorg-server-common xorg-server-xvfb

# 安装 alttab 官方声明的 X11、图形和 uthash 构建/运行依赖。
yay -S --noconfirm libx11 libxmu libxft libxrender libxrandr libpng libxpm uthash

# 下载固定版本的官方源码归档。
wget -O "$SOURCE_ARCHIVE" "$ALTTAB_SOURCE_URL"

# 校验官方源码归档 SHA-256。
printf '%s  %s\n' "$ALTTAB_SOURCE_SHA256" "$SOURCE_ARCHIVE" | sha256sum -c -

# 解压官方源码归档。
tar -xzf "$SOURCE_ARCHIVE" -C "$WORKDIR"

# 定义解压后的源码目录。
SOURCE_DIR="$WORKDIR/alttab-${ALTTAB_VERSION}"

# 确认关键源码、许可证和构建文件存在。
test -f "$SOURCE_DIR/configure"
test -f "$SOURCE_DIR/src/alttab.c"
test -f "$SOURCE_DIR/doc/alttab.svg"
test -f "$SOURCE_DIR/COPYING"

# 配置 alttab，保持标准 /usr 安装前缀。
(
  cd "$SOURCE_DIR"
  ./configure --prefix=/usr
)

# 编译 alttab。
make -C "$SOURCE_DIR" -j"$(nproc)"

# 确认编译后的主程序存在且可执行。
test -x "$SOURCE_DIR/src/alttab"

# 创建 AppImage 使用的 desktop 文件；alttab 是 X11 常驻窗口切换器。
cat > "$WORKDIR/alttab.desktop" <<'EOF_DESKTOP'
[Desktop Entry]
Type=Application
Name=AltTab
Comment=X11 window switcher for minimalistic window managers
Exec=alttab
Icon=alttab
Terminal=false
Categories=Utility;
StartupNotify=false
EOF_DESKTOP

# 校验 desktop 文件语法。
desktop-file-validate "$WORKDIR/alttab.desktop"

# 使用上游 SVG 图标。
export ICON="$SOURCE_DIR/doc/alttab.svg"

# 使用本次生成的 desktop 文件。
export DESKTOP="$WORKDIR/alttab.desktop"

# 设置 AppImage 输出目录。
export OUTPATH=./dist

# 固定最终 AppImage 文件名。
export OUTNAME="alttab.AppImage"

# 固定 AppImage 主程序为 alttab。
export MAIN_BIN=alttab

# 将刚刚从官方源码编译出的 alttab 及其动态依赖封装进 AppDir。
quick-sharun "$SOURCE_DIR/src/alttab"

# 将上游 GPL-3.0 许可证随 AppImage 一并保留。
mkdir -p AppDir/share/licenses/alttab
cp -a "$SOURCE_DIR/COPYING" AppDir/share/licenses/alttab/COPYING

# 生成最终 alttab AppImage。
quick-sharun --make-appimage

# 确认最终 AppImage 文件已经生成且不为空。
test -s ./dist/alttab.AppImage

# 在虚拟 X11 显示中执行帮助命令，验证 AppImage 主程序及动态链接依赖可以正常加载。
APPIMAGE_EXTRACT_AND_RUN=1 xvfb-run -a ./dist/alttab.AppImage -h >/dev/null
