#!/bin/bash
set -e

# 定位当前 JRiver 构建目录，确保独立兼容代码从固定位置读取。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

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
  libxcrypt-compat hicolor-icon-theme gvfs

# gvfs：提供 GTK/GIO 的 Recent、Trash 等虚拟文件系统后端。

# 让 GTK3 文件选择器默认从当前工作目录启动，避免每次打开时自动进入 recent://。
cat > /usr/share/glib-2.0/schemas/99-jriver-filechooser.gschema.override << 'EOF'
[org.gtk.Settings.FileChooser]
startup-mode='cwd'
EOF

# 重新编译 GSettings schema，使 JRiver RunImage 内的文件选择器默认设置生效。
glib-compile-schemas /usr/share/glib-2.0/schemas

# 创建 JRiver RunImage 内的 GTK3 配置目录。
mkdir -p /etc/gtk-3.0

# 禁用 GTK3 Recent 列表，避免 JRiver 文件选择器继续进入不可用的 Recent 位置。
cat > /etc/gtk-3.0/settings.ini << 'EOF'
[Settings]
gtk-recent-files-enabled=false
EOF

# 为 JRiver 的空初始目录调用准备专用兼容库，不修改 GTK/GIO 系统库。
mkdir -p /usr/local/lib/jriver /usr/local/bin

# 将独立的空目录兼容源码安装到 RunImage 内，源码逻辑保持与已验证版本一致。
install -m 0644 "$SCRIPT_DIR/filechooser-empty-path.c" /usr/local/lib/jriver/filechooser-empty-path.c

# 编译专用兼容库；只使用现有 base-devel 和 glibc，不增加运行依赖。
cc -shared -fPIC -O2 -Wall -Wextra -Werror \
  /usr/local/lib/jriver/filechooser-empty-path.c \
  -o /usr/local/lib/jriver/filechooser-empty-path.so -ldl -pthread

# 安装独立启动器，仅负责给 JRiver 主进程加载兼容库并完整传递参数。
install -m 0755 "$SCRIPT_DIR/jriver-filechooser-launch.sh" /usr/local/bin/jriver-filechooser-launch


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
  echo 'GIO_USE_VOLUME_MONITOR=unix'
  # 保留已生效的独立 session D-Bus，在同一会话内经专用启动器加载空目录兼容库。
  echo 'RIM_AUTORUN=("dbus-run-session" "--" "/usr/local/bin/jriver-filechooser-launch")'
  echo 'RIM_QUIET_MODE=1'
} >> /var/RunDir/config/Run.rcfg

# GIO_USE_VOLUME_MONITOR=unix：避免共享宿主会话 D-Bus 时请求容器内的 UDisks2 GVFS 卷监视器服务。

# 7. 瘦身并打包
rim-shrink --all

# 注意：mediacenter36 中的 36 为版本号，后续版本更新时需同步检查并修改。
rim-build mediacenter36
