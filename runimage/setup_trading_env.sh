#!/bin/bash

# 任意命令执行失败时立即退出，避免在前置步骤失败后继续生成不完整的 RunImage
set -e

# 1. 设置 BlackArch 镜像源
# 使用 USTC、SJTU、TUNA 三个镜像，避免 RunImage 默认 BlackArch 镜像连接超时导致数据库同步失败
sudo tee /etc/pacman.d/blackarch-mirrorlist > /dev/null << 'EOF'
Server = https://mirrors.ustc.edu.cn/blackarch/$repo/os/$arch
Server = https://mirror.sjtu.edu.cn/blackarch/$repo/os/$arch
Server = https://mirrors.tuna.tsinghua.edu.cn/blackarch/$repo/os/$arch
EOF

# 2. 设置中文语言环境
# 将简体中文 UTF-8 locale 加入生成列表
echo 'zh_CN.UTF-8 UTF-8' | sudo tee -a /etc/locale.gen

# 生成系统 locale 数据
sudo locale-gen

# 写入 RunImage 内部默认语言环境配置
tee /etc/locale.conf > /dev/null << 'EOF'
LANG=zh_CN.utf8
LC_ALL=zh_CN.utf8
LANGUAGE=zh_CN:zh
EOF

# 3. 启用 DisableDownloadTimeout
# 如果 pacman.conf 中该选项仍为注释状态，则取消注释；如果不存在，则添加到 [options] 段
if grep -q '^#DisableDownloadTimeout' /etc/pacman.conf; then
    sed -i 's/^#DisableDownloadTimeout/DisableDownloadTimeout/' /etc/pacman.conf
elif ! grep -q '^DisableDownloadTimeout' /etc/pacman.conf; then
    sed -i '/^\[options\]/a DisableDownloadTimeout' /etc/pacman.conf
fi

# 4. 更新软件包数据库并安装 yay
# RunImage 环境中的 pac 为 pacman 的别名；先同步数据库并更新基础系统包
pac -Syu --noconfirm

# 安装 yay，用于后续同时安装 Arch 官方仓库和 AUR 软件包
pac -S --noconfirm yay

# 5. 安装交易环境和依赖
# 安装 Java、GTK/Qt、音视频、输入法、字体、桌面集成及交易软件运行所需的公共依赖
yay -S --noconfirm zulu-21-bin pulseaudio alsa-utils ibus gtk2 gtk3 gtk4 pulseaudio-alsa alsa-lib freetype2 wqy-microhei gnome-themes-extra adwaita-icon-theme dbus at-spi2-core pango \
  libappindicator-gtk3 fontconfig cmake git openssl base-devel mesa noto-fonts-emoji gdk-pixbuf2 libpulse libxcomposite libxcrypt-compat libxrandr openssl-1.1 libtorrent gcc \
  libxfixes libxi libxrender libxss libxtst xdg-utils gendesk qt6-quick3d qt6-webengine libglvnd unixodbc chrpath glib2 expat qt6ct qt5ct qt5-x11extras qt6-base qt5-base cmake clang \
  adwaita-qt6 adwaita-qt5 libayatana-appindicator libayatana-indicator ffmpeg gstreamer gst-plugins-base gst-plugins-good fcitx5 fcitx5-gtk fcitx5-qt vulkan-icd-loader qt5-wayland qt6-wayland \
  hicolor-icon-theme glibc-locales libnotify notification-daemon sound-theme-freedesktop ca-certificates xdg-desktop-portal xdg-desktop-portal-gtk opus glib2-devel libx11 pixman cairo \
  harfbuzz libxext libxinerama libxkbcommon libxkbcommon-x11 libdrm bluez cups bluez-cups cups-filters cups-pdf hplip libcups poppler poppler-glib avahi nss nss-mdns libxcb xcb-util \
  xcb-util-cursor xcb-util-image xcursor-themes xcb-util-keysyms xcb-util-renderutil xcb-util-wm xterm util-linux bluez-utils alsa-firmware wget curl dbus-glib nspr sqlite snappy \
  xdg-user-dirs xdg-utils-cxx libva libva-intel-driver libucontext xdotool xorg-font-util xorg-fonts-75dpi xorg-fonts-100dpi xorg-server xorg-server-common xorg-xwayland xorg-xinit \
  xorg-xinput sed libarchive findutils ttf-liberation ttf-dejavu libxxf86vm bash x265 x264 v4l-utils speex ladspa gnutls fribidi bzip2 xclip xsel desktop-file-utils xorg-xrdb polkit \
  qt5-tools qt6-charts qt6-multimedia libxau libxcursor libxdamage alsa-plugins shared-mime-info

# zulu-21-bin：为 thinkorswim 提供 Zulu OpenJDK 21 运行环境
# fcitx5-gtk：为 GTK3/GTK4 程序提供 fcitx5 输入法模块，与 GTK_IM_MODULE=fcitx 配套使用
# 以后新增任何软件包时，都必须在这里补充一行中文说明，明确新增原因和用途

# 6. 写入 RunImage 运行时持久化配置
# 确保 RunImage 配置目录存在
mkdir -p /var/RunDir/config/

# 将以下运行参数追加到 Run.rcfg，使重新打包后的 trading_env RunImage 默认使用这些设置
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

  # trading_env 不启用 RIM_RUN_IN_ONE 和 RIM_WAIT_RPIDS_EXIT
  # 多个交易程序共用同一个容器时，如果最先启动程序所在终端被 Ctrl-C 中断或关闭，后续同容器 GUI 程序可能出现 write EIO、卡死或异常退出
  # 因此 trading_env 保持每次启动使用独立容器，避免 IBKR、thinkorswim 等交易程序之间相互影响

  # 设置 RunImage 内部默认语言为简体中文 UTF-8
  echo 'LANG=zh_CN.utf8'

  # 设置语言优先级为简体中文
  echo 'LANGUAGE=zh_CN:zh'

  # GTK 程序使用 fcitx5 输入法模块
  echo 'GTK_IM_MODULE=fcitx'

  # Qt 程序使用 fcitx5 输入法模块
  echo 'QT_IM_MODULE=fcitx'

  # 为 X11 程序指定 fcitx5 输入法
  echo 'XMODIFIERS=@im=fcitx'

  # SDL 程序使用 fcitx5 输入法模块
  echo 'SDL_IM_MODULE=fcitx'
} >> /var/RunDir/config/Run.rcfg

# 7. 瘦身并生成最终 trading_env RunImage
# 删除打包后不需要的缓存、开发文件及其他可安全移除内容，缩小最终镜像体积
rim-shrink --all

# 将当前 RunImage 环境重新打包为 trading_env RunImage
rim-build trading_env
