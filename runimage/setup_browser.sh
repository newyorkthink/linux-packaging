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

# 5. 安装浏览器及运行依赖
# 浏览器包含 Firefox、Microsoft Edge、Google Chrome、Zen Browser、Brave、Vivaldi
# 同时安装 GTK/Qt、字体、音频、桌面集成、VA-API/Vulkan、证书及浏览器运行所需的公共依赖
yay -S --noconfirm firefox gnome-themes-extra adwaita-icon-theme hicolor-icon-theme shared-mime-info gdk-pixbuf2 librsvg desktop-file-utils fcitx5 fcitx5-gtk fcitx5-qt alsa-lib gtk3 pipewire-alsa noto-fonts-emoji dbus at-spi2-core wqy-microhei \
  xdg-desktop-portal xdg-desktop-portal-gtk ca-certificates libva libva-mesa-driver intel-media-driver vulkan-intel vulkan-icd-loader vulkan-mesa-layers nss nspr openssl base-devel \
  microsoft-edge-stable-bin libcups libdrm libxml2-legacy libxtst mesa imagemagick xdg-utils ttf-liberation pipewire google-chrome libpipewire gtk4 zlib alsa-utils libnotify speech-dispatcher \
  zen-browser-bin brave-bin vivaldi vivaldi-ffmpeg-codecs libsecret

# libsecret：为 Chromium 系浏览器提供 Secret Service 客户端库，用于访问 KeePassXC、GNOME Keyring 等密码与凭据存储后端
# 以后新增任何软件包时，都必须在这里补充一行中文说明，明确新增原因和用途

# 6. 写入 RunImage 运行时持久化配置
# 确保 RunImage 配置目录存在
mkdir -p /var/RunDir/config/

# 将以下运行参数追加到 Run.rcfg，使重新打包后的 browser RunImage 默认使用这些设置
{
  # 禁用 RunImage 的 NVIDIA 驱动版本检查；避免自动检测、匹配、生成或下载 NVIDIA 驱动镜像
  # 该参数只关闭 RunImage 的 NVIDIA 驱动处理机制，不等于禁用 NVIDIA 显卡或浏览器 GPU 加速
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

  # 同一个 browser RunImage 后续启动的程序共用同一个容器，避免同时启动多个浏览器时重复创建独立容器和挂载环境
  echo 'RIM_RUN_IN_ONE=1'

  # 等待共享容器内所有浏览器全部退出后再关闭 RunImage 容器
  # 避免关闭最先启动的浏览器时，同时结束后续启动的其他浏览器
  echo 'RIM_WAIT_RPIDS_EXIT=1'

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

# 7. 瘦身并生成最终 browser RunImage
# 删除打包后不需要的缓存、开发文件及其他可安全移除内容，缩小最终镜像体积
rim-shrink --all

# 将当前 RunImage 环境重新打包为 browser RunImage
rim-build browser
