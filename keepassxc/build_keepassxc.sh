#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 安装统一的 Arch AppImage 基础包
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base

rm -rf AppDir || true

yay -S --noconfirm gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux glycin libheif zsync xorg-server xorg-server-common xorg-server-xvfb
yay -S --noconfirm keepassxc xclip fcitx5-qt libxcb xcb-util xcb-util-keysyms libxss \
  xcb-util-renderutil xcb-util-wm xcb-util-image xcb-util-cursor libxkbcommon libxkbcommon-x11 mesa libglvnd \
  qt6-base qt6-svg libxtst xdotool libvdpau libva lxqt-qtplugin \
  libx11 libxext libxfixes libxi libxinerama libxcb xcb-util adwaita-qt6 \
  libsm libice libxrandr libxrender libxcursor libxcomposite libxdamage

KEEPASSXC_PACKAGE_VERSION="$(pacman -Q keepassxc | awk '{print $2}')"
KEEPASSXC_VERSION="${KEEPASSXC_PACKAGE_VERSION#*:}"
KEEPASSXC_VERSION="${KEEPASSXC_VERSION%-*}"
if [ -z "$KEEPASSXC_VERSION" ]; then
  echo "Error: failed to determine KeePassXC version." >&2
  exit 1
fi

ARCH="$(uname -m)"
export ARCH

export ICON=/usr/share/icons/hicolor/scalable/apps/keepassxc.svg
export DESKTOP=/usr/share/applications/org.keepassxc.KeePassXC.desktop
export OUTPATH=./dist
export OUTNAME="keepassxc.AppImage"

quick-sharun \
  /usr/bin/keepassxc \
  /usr/bin/keepassxc-cli \
  /usr/bin/keepassxc-proxy \
  /usr/bin/xclip \
  /usr/bin/xclip-copyfile \
  /usr/bin/xclip-cutfile \
  /usr/bin/xclip-pastefile \
  /usr/bin/xdotool \
  /usr/lib/libXtst.so.6 \
  /usr/lib/libxcb-xtest.so.0

# 先改名保留原 sharun 硬链接，避免直接覆盖时破坏其他启动入口。
mv -- AppDir/bin/keepassxc-proxy AppDir/bin/keepassxc-proxy.real
# 保留原代理二进制，仍由 sharun 加载包内依赖。
mv -- AppDir/shared/bin/keepassxc-proxy AppDir/shared/bin/keepassxc-proxy.real

# 保留原 bin 调用入口，完整传递参数及标准输入输出。
cat > AppDir/bin/keepassxc-proxy <<'PROXY_BIN'
#!/bin/sh
# 通过原 sharun 启动器运行原代理程序。
exec "${0%/*}/keepassxc-proxy.real" "$@"
PROXY_BIN

# 让 Qt6 默认登记的 shared/bin 入口也经过包内 sharun 启动器。
cat > AppDir/shared/bin/keepassxc-proxy <<'PROXY_SHARED'
#!/bin/sh
# 从浏览器直接调用的位置转到包内 sharun 启动器。
exec "${0%/*}/../../bin/keepassxc-proxy.real" "$@"
PROXY_SHARED

# 两个代理入口均需能够被 AppRun 或浏览器直接执行。
chmod +x AppDir/bin/keepassxc-proxy AppDir/shared/bin/keepassxc-proxy

# Qt6 按 shared/bin 中的真实程序路径查找资源，复用顶层 share 中的翻译和数据。
ln -sfnT ../share AppDir/shared/share

# 在包内生成简体中文 locale，保留 quick-sharun 已写入的环境配置。
mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'EOF'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
EOF

quick-sharun --make-appimage

# 构建成功后输出统一的软件版本元数据。
printf '%s\n' "$KEEPASSXC_VERSION" > ./dist/version.txt
