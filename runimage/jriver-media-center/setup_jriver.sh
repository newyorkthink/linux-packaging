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

# 只把空字符串替换为 Home；非空路径和 GTK 的原有返回值保持不变。
cat > /usr/local/lib/jriver/filechooser-empty-path.c << 'EOF'
#define _GNU_SOURCE
#include <dlfcn.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

/* GTK3 的 GtkFileChooser 不透明类型；gboolean 的 ABI 为 int。 */
typedef struct _GtkFileChooser GtkFileChooser;
typedef int (*SetCurrentFolder)(GtkFileChooser *, const char *);
static SetCurrentFolder real_set_current_folder;
static pthread_once_t gtk_once = PTHREAD_ONCE_INIT;

/* 主进程加载后恢复原环境，避免把本兼容库传给 JRWeb 或宿主 helper。 */
__attribute__((constructor))
static void restore_preload_environment(void)
{
    const char *saved = getenv("JRIVER_FILECHOOSER_SAVED_PRELOAD");
    if (saved == NULL)
        return;
    if ((*saved ? setenv("LD_PRELOAD", saved, 1) : unsetenv("LD_PRELOAD")) != 0 ||
        unsetenv("JRIVER_FILECHOOSER_SAVED_PRELOAD") != 0) {
        perror("JRiver: restore preload environment");
        _exit(127);
    }
}

static void resolve_gtk(void)
{
    /* JRiver 延迟加载 GTK；从已经加载的 GTK 获取真实函数，兼容 RTLD_LOCAL。 */
    void *gtk = dlopen("libgtk-3.so.0", RTLD_LAZY | RTLD_NOLOAD);
    if (gtk != NULL)
        real_set_current_folder = (SetCurrentFolder)dlsym(gtk, "gtk_file_chooser_set_current_folder");
    if (real_set_current_folder == NULL) {
        fputs("JRiver: cannot resolve GTK file chooser function\n", stderr);
        _exit(127);
    }
}

int gtk_file_chooser_set_current_folder(GtkFileChooser *chooser, const char *filename)
{
    pthread_once(&gtk_once, resolve_gtk);
    if (filename != NULL && filename[0] == '\0') {
        const char *home = getenv("HOME");
        filename = home != NULL && home[0] == '/' ? home : "/";
    }
    return real_set_current_folder(chooser, filename);
}
EOF

# 编译专用兼容库；只使用现有 base-devel 和 glibc，不增加运行依赖。
cc -shared -fPIC -O2 -Wall -Wextra -Werror \
  /usr/local/lib/jriver/filechooser-empty-path.c \
  -o /usr/local/lib/jriver/filechooser-empty-path.so -ldl -pthread

# 仅给 JRiver 主进程加载兼容库，保留上游可执行文件路径与全部启动参数。
cat > /usr/local/bin/jriver-filechooser-launch << 'EOF'
#!/bin/bash
set -e

# 保存原有预加载配置，兼容库加载后立即恢复，供后续子进程继承。
export JRIVER_FILECHOOSER_SAVED_PRELOAD="${LD_PRELOAD-}"

# 只在即将启动的 JRiver 主进程中加入空目录兼容库。
export LD_PRELOAD="/usr/local/lib/jriver/filechooser-empty-path.so${LD_PRELOAD:+:$LD_PRELOAD}"

# 启动未修改的上游 JRiver，完整传递文件名和其他参数。
exec /usr/bin/mediacenter36 "$@"
EOF

# 为容器内专用启动器添加执行权限。
chmod +x /usr/local/bin/jriver-filechooser-launch


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
