#!/usr/bin/env bash
set -e

# 稳定基线说明：
# - 使用 Arch Linux Extra 官方 htop 软件包。
# - 使用 quick-sharun 打包，不使用 linuxdeploy。
# - 保留 Arch 官方 htop.desktop 和 htop.svg；只在构建副本中追加版本元数据。
# - 显式封装 htop 运行时动态加载的 libsensors、libnl。
# - 同时封装 Arch 官方列出的 lsof、strace 可选功能。

# 清理上一次构建生成的 AppDir 和 desktop 构建副本。
rm -rf AppDir || true
rm -f ./htop.desktop

# 获取当前系统架构。
ARCH="$(uname -m)"

# 导出 AppImage 架构。
export ARCH

# 使用 Arch 官方 htop SVG 图标。
export ICON=/usr/share/icons/hicolor/scalable/apps/htop.svg

# 使用 Arch 官方 htop desktop 的构建副本。
export DESKTOP=./htop.desktop

# 设置 AppImage 输出目录。
export OUTPATH=./dist

# 固定最终 AppImage 文件名。
export OUTNAME="htop.AppImage"

# 固定 AppImage 主程序为 htop。
export MAIN_BIN=htop

# 安装 quick-sharun 打包所需的基础依赖。
yay -S --noconfirm gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux zsync

# 安装 htop、运行依赖以及 Arch 官方列出的可选功能依赖。
yay -S --noconfirm htop ncurses libcap libnl lm_sensors lsof strace

VERSION="$(pacman -Q htop | awk '{print $2; exit}')"
if [[ -z "$VERSION" ]]; then
  echo "Error: failed to read htop package version." >&2
  exit 1
fi
cp -f /usr/share/applications/htop.desktop "$DESKTOP"
if grep -q '^X-AppImage-Version=' "$DESKTOP"; then
  sed -i "s|^X-AppImage-Version=.*|X-AppImage-Version=$VERSION|" "$DESKTOP"
else
  printf 'X-AppImage-Version=%s\n' "$VERSION" >> "$DESKTOP"
fi
printf '%s\n' "$VERSION" > ~/version

# 一次性封装 htop 主程序、Open Files/Trace 外部程序，以及运行时动态加载的 libsensors、libnl。
quick-sharun /usr/bin/htop /usr/bin/lsof /usr/bin/strace /usr/lib/libsensors.so* /usr/lib/libnl-3.so* /usr/lib/libnl-genl-3.so*

# 生成最终 htop AppImage。
quick-sharun --make-appimage

# 确认最终 AppImage 文件已经生成且不为空。
test -s ./dist/htop.AppImage

# 验证 AppImage 内的 htop 可以正常运行并读取版本。
./dist/htop.AppImage --version
