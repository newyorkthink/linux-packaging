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
  libxcrypt-compat hicolor-icon-theme bash gvfs

# bash：保证打包和运行时都有 bash，避免瘦身后启动脚本找不到解释器。
# gvfs：提供 GTK/GIO 的最近使用、回收站等虚拟文件系统后端。


# 6. 写入运行时持久化配置 (Run.rcfg)
mkdir -p /var/RunDir/config/
{
  # 禁用 RunImage 的 NVIDIA 驱动版本检查；避免自动检测、匹配、生成或下载 NVIDIA 驱动镜像
  # 该参数只关闭 RunImage 的 NVIDIA 驱动处理机制，不等于禁用 NVIDIA 显卡或程序 GPU 加速
  echo 'RIM_NO_NVIDIA_CHECK=1'

  # 指定 RunImage 缓存目录，统一保存运行时缓存数据
  echo 'RIM_CACHEDIR=~/.cache/runimage'

  # 允许容器通过 hostexec 调用宿主机命令
  echo 'RIM_ENABLE_HOSTEXEC=1'

  # 外部链接和文件使用宿主机的 xdg-open 打开
  echo 'RIM_HOST_XDG_OPEN=1'

  # 将宿主机字体目录共享给 RunImage，保持字体显示一致
  echo 'RIM_SHARE_FONTS=1'

  # 将宿主机 GTK 等主题共享给 RunImage，保持界面主题一致
  echo 'RIM_SHARE_THEMES=1'

  # 将宿主机图标目录共享给 RunImage，避免程序图标或主题图标缺失
  echo 'RIM_SHARE_ICONS=1'

  # 关闭 RunImage 的普通信息输出，仅保留错误等必要信息，减少启动时终端输出
  echo 'RIM_QUIET_MODE=1'

  # 固定光标主题为 Adwaita，避免进入 JRiver 后指针左右镜像
  echo 'XCURSOR_THEME=Adwaita'

  # 固定光标大小为 24
  echo 'XCURSOR_SIZE=24'
} >> /var/RunDir/config/Run.rcfg

# 7. 瘦身并打包
rim-shrink --all

# 注意：mediacenter36 中的 36 为版本号，后续版本更新时需同步检查并修改。
rim-build mediacenter36
