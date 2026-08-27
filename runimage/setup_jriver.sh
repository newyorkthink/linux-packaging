#!/bin/bash
set -e

# 1. 更新系统镜像源 (Arch Linux & BlackArch)
sudo tee /etc/pacman.d/mirrorlist > /dev/null << 'EOF'
Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch
Server = https://mirror.sjtu.edu.cn/archlinux/$repo/os/$arch
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch
EOF

sudo tee /etc/pacman.d/blackarch-mirrorlist > /dev/null << 'EOF'
Server = https://mirrors.ustc.edu.cn/blackarch/$repo/os/$arch
Server = https://mirror.sjtu.edu.cn/blackarch/$repo/os/$arch
Server = https://mirrors.tuna.tsinghua.edu.cn/blackarch/$repo/os/$arch
EOF

# 2. 设置中文语言环境
echo 'zh_CN.UTF-8 UTF-8' | sudo tee -a /etc/locale.gen
sudo locale-gen

# 3. 启用 DisableDownloadTimeout
if grep -q '^#DisableDownloadTimeout' /etc/pacman.conf; then
    sed -i 's/^#DisableDownloadTimeout/DisableDownloadTimeout/' /etc/pacman.conf
elif ! grep -q '^DisableDownloadTimeout' /etc/pacman.conf; then
    sed -i '/^\[options\]/a DisableDownloadTimeout' /etc/pacman.conf
fi

# 4. 安装基础工具和 yay
# 注意：在 runimage 环境中 pac 是 pacman 的别名
pac -Syu --noconfirm
pac -S --noconfirm yay


# 5. 安装 JRiver 环境和依赖
yay -S --noconfirm jriver-media-center gnome-themes-extra adwaita-icon-theme adwaita-cursors desktop-file-utils zlib tar nss nspr libva ibus gtk3 libsoup3 python libepoxy gst-libav \
  coreutils glibc libuvc libusb mesa ffmpeg base-devel polkit dbus webkit2gtk-4.1 vorbis-tools alsa-lib ca-certificates gcc-libs libx11 pango fribidi fontconfig gst-plugins-ugly \
  libxau libxcb libxdmcp libxext util-linux musepack-tools pulseaudio-alsa freetype2 harfbuzz xdg-utils lcms2 vulkan-icd-loader vulkan-intel gstreamer cairo libxss libxtst \
  libxcrypt-compat hicolor-icon-theme


# 6. 写入运行时持久化配置 (Run.rcfg)
mkdir -p /var/RunDir/config/
{
  echo 'RIM_NO_NVIDIA_CHECK=1'
  echo 'RIM_CACHEDIR=~/.cache/runimage'
  echo 'RIM_ENABLE_HOSTEXEC=1'
  echo 'RIM_HOST_XDG_OPEN=1'
  echo 'RIM_SHARE_FONTS=1'
  echo 'RIM_SHARE_THEMES=1'
  echo 'RIM_SHARE_ICONS=1'
  echo 'RIM_QUIET_MODE=1'
} >> /var/RunDir/config/Run.rcfg

# 7. 瘦身并打包
rim-shrink --all

# 注意：mediacenter36 中的 36 为版本号，后续版本更新时需同步检查并修改。
rim-build mediacenter36
