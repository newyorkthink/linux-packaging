#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# JRiver Media Center AnyLinux AppImage 稳定运行基线版
# ==============================================================================
#
# 稳定策略：
# - 功能基线来自提交 57f94076a8050f1adb1b1e49696e7c9de8153b17，并由
#   be371a36b94e3d8d7b1b35aafbc6ba2bc1a40360 完整恢复；主程序、JRWeb、CEF、
#   视频、插件、音频和 AppRun/pathmap 运行链保持该基线，不再试验性修改。
# - 仅保留 JRiver 运行兼容必需的 CEF 版本/API hash 与 anylinux.c 环境清理基线。
# - Sharun、quick-sharun、appimagetool、uruntime、DWARFS、pathmap 均不在本脚本锁定版本，
#   使用构建环境和各自上游当前提供的版本。
# - JRiver/AUR 更新后若 CEF ABI 不兼容，构建必须直接失败，禁止发布表面成功但无法启动的产物。
# - AppImage 运行时不会修改宿主 /usr、/etc、shell 配置或全局环境；持久数据只写入
#   ~/.jriver/Media Center N。/tmp 挂载目录和 XDG_RUNTIME_DIR 输入法缓存均为临时数据。
#
# Sharun 版本兼容性起因记录：
# - 已知可用阶段使用 quick-sharun 当时默认的 Sharun 2.2.4。
# - AnyLinux-AppImages 于 2026-07-21 在提交 898fe0ffcdbd91e502c32eb5c9f796efc271abef
#   将默认 Sharun 从 2.2.4 升级到 2.2.5；后续兼容问题的出现时间与此次升级一致。
# - 因未做仅切换 Sharun 版本的单变量对照，当前将版本变化记录为高度疑似起因，不写成完全证实。
# - 本脚本不固定 Sharun 版本；上游发布后续版本时再依据 Kali 实机结果判断，未确认前不得
#   删除当前已验证的 glibc 隔离、CEF 注入和 AppRun/pathmap 运行修复。
#
# 当前基准状态（2026-08-08，Kali Linux 实测）：
# - 已修复跨发行版启动时的 glibc 混用问题：
#   AppImage 不再把包内 glibc 暴露给宿主 shell/工具，已消除
#   “libc.so.6: undefined symbol: __pointer_chk_guard, version GLIBC_PRIVATE” 错误。
# - JRiver 主界面能够正常启动，视频播放正常；这一点作为后续修改必须保留的稳定基线。
# - 已确认 libout_Main.so 的绝对插件路径报错消失；该插件路径修复继续保留。
# - 后续修复不得重新让 AppRun、JRWorker 或其他宿主 shell 工具
#   通过 AppImage shared/lib / lib 加载包内 glibc。
# - /tmp 清理方案曾导致主程序无法启动，已回退；本轮不修改 AppRun 的 exec/pathmap 启动链。
#
# 本轮 JRWeb / CEF 修复：
# - 已确认真正持续报错的是运行时生成到用户目录中的：
#   ~/.jriver/Media Center N/Plugins/linux_chromium64/JRWebChromium
#   该文件不属于 JRiver 安装包，因此构建机 /usr/lib/jriver 下不存在，不能在打包阶段收集。
# - 上一版错误地把 AppDir/lib 映射目录中的 JRWeb 构建结果替换成 shell 包装器，
#   破坏了已经验证可启动的主程序链；本版完整撤回该改动，映射目录中的 JRWeb 保持原样。
# - 新增 jriver-cef-env.so，并确保它排在 anylinux.so 之后加载：anylinux.so 先按原规则
#   清理外部进程环境，再由该库只对精确命名的 JRWeb / JRWebChromium 注入 CEF 路径。
# - 启动 JRWeb 时补充私有 CEF 路径，同时兼容 quick-sharun 生成的启动器或已处理 ELF；
#   不再用 shell 包装实际启动路径。
# - 启动用户目录 JRWebChromium 时只补充指向私有 cef-runtime 的 LD_LIBRARY_PATH；
#   不传入 shared/lib、AppImage lib、包内 glibc 或 anylinux.so。
# - 2026-08-13 Kali 实测确认：上一版把 JRWebChromium 的 ALSA_PLUGIN_DIR、
#   ALSA_CONFIG_PATH、ALSA_CONFIG_DIR 全部清除后，宿主 ALSA 会尝试从
#   /usr/lib/x86_64-linux-gnu/alsa-lib 加载 libasound_module_pcm_pulse.so；
#   宿主没有该额外插件时，网页视频正常显示但没有声音。
# - 本版只撤销这一处过度清理：JRWebChromium 继续继承 AppImage 已经打包好的
#   ALSA_PLUGIN_DIR，直接使用包内 libasound_module_pcm_pulse.so；ALSA_CONFIG_PATH 和
#   ALSA_CONFIG_DIR 仍然清除，让外部 Chromium 使用宿主正常 ALSA 配置。
# - 不新增 asound.conf、不强制 pcm.!default / ctl.!default、不增加 shared/lib 或 AppImage lib
#   到 JRWebChromium 的 LD_LIBRARY_PATH，因此不重复 0a98e42/c70c015 的启动卡住路径，
#   也不重新把包内 glibc 暴露给外部 Chromium；PULSE_SERVER 原样保留。
# - 注入同时覆盖 execve、execvpe、posix_spawn 和 posix_spawnp；其他子进程仍执行
#   anylinux.so 原有清理规则，环境不变。
# - CEF runtime 在 AppImage 内只保留一份，统一放到 Media Center N/cef-runtime；
#   不再同时复制 libcef.so 到 shared/lib 与 JRiver 根目录。
# - CEF 自带的 libEGL/libGLESv2/SwiftShader/Vulkan 仅放在私有 cef-runtime，
#   shared/lib 中现有 Mesa/GLVND 保持不动。
# - 本轮不修改已验证的 JRiver 主程序、映射目录 JRWeb、libout_Main.so、run-mc.sh、
#   AppRun、glibc 隔离和 pathmap exec 基线。
#
# 历史已完成修复（后续不要无故回退）：
# - 曾完成 JRWeb/JRWorker 内嵌浏览器使用宿主 Fcitx5 中文输入法的处理。
# - 曾修复 im-fcitx5.so 在 AppImage 内无法加载的问题，并生成绝对路径缓存。
# - 已补齐 WebKitGTK 子进程、JavaScriptCore、GSettings、Glycin、ALSA、PulseAudio、
#   GStreamer、GVFS 和 Mesa GBM 等运行文件。
# - 已移除会劫持 GTK/GLib 的 gtk-class-fix，仅保留 Glycin 禁用沙箱补丁。
# - 保留 JRiver 原始目录结构，通过 pathmap 映射系统路径，并自动识别 MC 主版本。
# - 2026-08-13 JRWebChromium 保留 AppImage 内 Pulse ALSA 插件目录，但不再继承包内 ALSA 配置；
#   不要求宿主额外安装 libasound2-plugins，也不恢复旧版全局 LD_LIBRARY_PATH。
#
# 当前已知问题（暂不继续修改，后续有条件时再逐项修复）：
# - JRiver 主界面右上角的原生搜索框不支持 Linux 中文输入法。
# - “打开文件夹”及部分导入操作仍可能导致 JRiver 闪退。
# - Ubuntu 虚拟机中可能在 AppImage 解压到 100% 后停住；Kali 主机此前可运行，
#   因此不强制启用软件渲染，避免影响主机硬件加速。
# - 终端可能出现 GTK、Chromium mutex 或 WebGL 警告；需要区分普通警告与实际加载失败。
# - JRWeb/CEF 退出阶段仍可能出现 “observer_list.h: observers_.empty()” 断言。
# - 0a98e42b694ba07eb3c30e9cb091be92fb6028ce 与
#   c70c015fce79c0d86963859923d91186fbefdd27 的网页音频注入均导致启动卡住，已明确排除。
# - 以上问题当前仅保留记录；后续确认根因和稳定修复条件后再处理，且不得破坏现有可启动基线。
#
# 发布状态：
# - 以 Kali Linux 当前实测结果作为基准。
# - 已确认：GLIBC_PRIVATE / __pointer_chk_guard 启动错误已消失，JRiver 主界面与视频播放正常。
# - 已确认：libout_Main.so 插件绝对路径报错消失。
# - 本轮构建检查：映射目录 JRWeb 必须继续是 ELF 且不得生成 JRWeb.real；CEF 环境注入必须
#   通过 exec 与 posix_spawn 测试，且无关外部进程不得继承 AppImage 库路径。
# - 已确认：JRWeb 内嵌浏览器页面能够正常显示并可播放网页视频。
# - 修改此脚本时，GitHub Actions 只构建 JRiver；纯备注整理应使用 [skip ci]，避免浪费额度。
#
# 1. 初始化构建环境
cd "$(dirname "$0")"

rm -rf AppDir dist pathmap-src cef-runtime cef-runtime.tar.bz2 || true

ARCH="$(uname -m)"
export ARCH

MC_VER="${MC_VER:-}"

# 固定已经检查过的 anylinux.so 源码版本，保证环境清理顺序不会随上游 main 变化。
export ANYLINUX_LIB_SOURCE='https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/40bada0cecfdce3eb4e4382f99cb531c9d352cb1/useful-tools/lib/anylinux.c'

export DEPLOY_GTK=1
export DEPLOY_GDK=1
export DEPLOY_GLYCIN=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export DEPLOY_GSTREAMER=1
export DEPLOY_PIPEWIRE=1
export DEPLOY_PULSE=1

# gtk-class-fix 会全局劫持 GTK/GLib 函数，JRiver 打开文件选择器时会崩溃。
# Glycin 的沙箱问题改用下面单独的 glycin-nosandbox.so 处理。
unset GTK_CLASS_FIX

# 2. 安装构建工具、JRiver 与运行依赖
# 安装基础打包工具
yay -S --needed --noconfirm gcc base-devel git make python wget curl tar gzip bzip2 binutils patchelf coreutils \
  appstream-glib desktop-file-utils util-linux zsync inetutils \
  xorg-server xorg-server-common xorg-server-xvfb

# 安装 JRiver Media Center
yay -S --needed --noconfirm jriver-media-center

# 3. 自动识别 JRiver 版本并设置 AppImage 元数据
# MC_VER 环境变量可用于手动覆盖。
detect_mc_version() {
  local path name candidate
  local -a versions=()

  for path in \
    /usr/lib/jriver/Media\ Center\ [0-9]* \
    /usr/lib/jriver/MC[0-9]* \
    /usr/bin/mediacenter[0-9]*; do
    [[ -e "$path" ]] || continue
    name="${path##*/}"

    case "$name" in
      'Media Center '*) candidate="${name#Media Center }" ;;
      MC*) candidate="${name#MC}" ;;
      mediacenter*) candidate="${name#mediacenter}" ;;
      *) continue ;;
    esac

    [[ "$candidate" =~ ^[0-9]+$ ]] && versions+=("$candidate")
  done

  [[ ${#versions[@]} -gt 0 ]] || return 1
  printf '%s\n' "${versions[@]}" | sort -n | tail -n1
}

if [[ -z "$MC_VER" ]]; then
  MC_VER="$(detect_mc_version || true)"
fi

if [[ ! "$MC_VER" =~ ^[0-9]+$ ]]; then
  echo '错误：无法识别 JRiver Media Center 主版本。' >&2
  echo '可手动指定，例如：MC_VER=38 ./build_jriver.sh' >&2
  exit 1
fi

if [[ ! -x "/usr/bin/mediacenter${MC_VER}" ]] || \
   [[ ! -d "/usr/lib/jriver/Media Center ${MC_VER}" ]]; then
  echo "错误：检测到 MC${MC_VER}，但程序目录不完整。" >&2
  exit 1
fi

echo "检测到 JRiver Media Center ${MC_VER}"

export MC_VER
export APPNAME="Media Center ${MC_VER}"
export STARTUPWMCLASS="Media_Center_${MC_VER}"
export ICON="/usr/lib/jriver/MC${MC_VER}/Data/Default Art/Logo.png"
export DESKTOP="/usr/share/applications/media_center_${MC_VER}.desktop"
export OUTPATH=./dist
export OUTNAME="mediacenter${MC_VER}.AppImage"

# 安装 JRiver 运行依赖
yay -S --needed --noconfirm \
  gnome-themes-extra adwaita-icon-theme adwaita-cursors hicolor-icon-theme \
  desktop-file-utils zlib tar nss nspr libva gtk3 ibus fcitx5 fcitx5-gtk libsoup3 webkit2gtk-4.1 \
  glib2 gdk-pixbuf2 glycin bubblewrap glib-networking gsettings-desktop-schemas gvfs libepoxy \
  gst-libav gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly gstreamer \
  coreutils glibc libusb mesa ffmpeg base-devel polkit dbus \
  vorbis-tools alsa-lib alsa-plugins libpulse ca-certificates gcc-libs libx11 pango fribidi fontconfig \
  libxau libxcb libxdmcp libxext util-linux musepack-tools \
  pipewire-audio \
  freetype2 harfbuzz xdg-utils lcms2 vulkan-icd-loader vulkan-intel \
  cairo libxss libxtst libxcrypt-compat libnotify libsecret at-spi2-core \
  libxcomposite libxdamage libxfixes libxi libxrandr libxinerama \
  libxkbcommon libxkbcommon-x11 libglvnd libvdpau shared-mime-info

# 4. 准备与 JRWeb ABI 完全匹配的 CEF runtime
# JRWeb 36.0.14 使用 CEF experimental Linux API hash：cf102dc...，
# 对应 CEF 136.1.6+g1ac1b14+chromium-136.0.7103.114。
CEF_VERSION='136.1.6+g1ac1b14+chromium-136.0.7103.114'
CEF_API_HASH='cf102dc1148d9d20a4692c0fb19586c42c96f7c3'
CEF_ARCHIVE_URL='https://cef-builds.spotifycdn.com/cef_binary_136.1.6%2Bg1ac1b14%2Bchromium-136.0.7103.114_linux64_minimal.tar.bz2'
CEF_ARCHIVE="$PWD/cef-runtime.tar.bz2"
CEF_WORKDIR="$PWD/cef-runtime"
JRWEB_SOURCE="/usr/lib/jriver/Media Center ${MC_VER}/JRWeb"

if [[ ! -x "$JRWEB_SOURCE" ]]; then
  echo "错误：JRWeb 不存在：$JRWEB_SOURCE" >&2
  exit 1
fi

# JRiver 更新后如果 JRWeb 的 CEF ABI 改变，禁止继续使用旧 CEF 造成随机崩溃。
if ! grep -aFq "$CEF_API_HASH" "$JRWEB_SOURCE"; then
  echo "错误：JRWeb 的 CEF API hash 已变化，当前固定的 CEF ${CEF_VERSION} 不再匹配。" >&2
  exit 1
fi

mkdir -p "$CEF_WORKDIR"
curl -fL --retry 3 --retry-delay 2 "$CEF_ARCHIVE_URL" -o "$CEF_ARCHIVE"
tar -xjf "$CEF_ARCHIVE" -C "$CEF_WORKDIR"
rm -f "$CEF_ARCHIVE"

CEF_ROOT="$(find "$CEF_WORKDIR" -mindepth 1 -maxdepth 1 -type d -name 'cef_binary_*_linux64_minimal' -print -quit)"
if [[ -z "$CEF_ROOT" ]] || [[ ! -f "$CEF_ROOT/Release/libcef.so" ]] || [[ ! -d "$CEF_ROOT/Resources" ]]; then
  echo '错误：CEF minimal runtime 解压结果不完整。' >&2
  exit 1
fi

# 下载到的 libcef.so 自身也必须包含完全相同的 API hash。
if ! grep -aFq "$CEF_API_HASH" "$CEF_ROOT/Release/libcef.so"; then
  echo "错误：下载的 libcef.so 与 JRWeb 所需 CEF API hash 不一致。" >&2
  exit 1
fi

# 只把 libcef.so 本体交给 quick-sharun，用来收集普通 ELF 依赖。
# 最终 libcef.so 只保留在 JRiver 私有 cef-runtime 中，不进入主程序 shared/lib。
CEF_LIB="$CEF_ROOT/Release/libcef.so"

# 5. 构建 pathmap，并由 quick-sharun 收集程序与依赖
# pathmap 用来模拟 appimage-builder 的 runtime.path_mappings。
git clone --depth=1 https://github.com/VHSgunzo/pathmap.git pathmap-src

if make -C pathmap-src pathmap-static; then
  PATHMAP_BIN="$PWD/pathmap-src/pathmap-static"
else
  make -C pathmap-src pathmap
  PATHMAP_BIN="$PWD/pathmap-src/pathmap"
fi

# 用 quick-sharun 收集程序和依赖；JRWebChromium 是运行时用户目录文件，不在这里收集。
quick-sharun \
  "/usr/bin/mediacenter${MC_VER}" \
  "/usr/bin/mc${MC_VER}" \
  "/usr/lib/jriver/Media Center ${MC_VER}/mc${MC_VER}" \
  "/usr/lib/jriver/Media Center ${MC_VER}" \
  "/usr/lib/jriver/MC${MC_VER}" \
  /usr/lib/webkit2gtk-4.1 \
  /usr/lib/libwebkit2gtk-4.1.so* \
  /usr/lib/libjavascriptcoregtk-4.1.so* \
  /usr/lib/alsa-lib \
  /usr/lib/libpulse.so* \
  /usr/lib/libpulse-simple.so* \
  /usr/lib/libpulse-mainloop-glib.so* \
  /usr/lib/pulseaudio/libpulsecommon-*.so \
  /usr/lib/gvfs/libgvfscommon.so* \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so \
  /usr/lib/libFcitx5GClient.so* \
  /usr/lib/libnss* \
  /usr/lib/libsoftokn3.so \
  /usr/lib/libfreeblpriv3.so \
  /usr/lib/pkcs11/* \
  "$CEF_LIB"

# 6. 应用运行时兼容修复
# 即使外部环境强制开启了 GTK_CLASS_FIX，也从最终包中彻底移除。
sed -i '/gtk-class-fix\.so/d' AppDir/.preload 2>/dev/null || true
sed -i \
  -e '/^GTK_WINDOW_CLASS=/d' \
  -e '/^GTK_IM_MODULE=/d' \
  -e '/^QT_IM_MODULE=/d' \
  -e '/^XMODIFIERS=/d' \
  -e '/^SDL_IM_MODULE=/d' \
  -e '/^LD_LIBRARY_PATH=/d' \
  AppDir/.env 2>/dev/null || true
rm -f AppDir/shared/lib/gtk-class-fix.so AppDir/lib/gtk-class-fix.so

# 只保留 Glycin 禁用沙箱的部分，不再劫持 GTK application id / prgname。
mkdir -p AppDir/shared/lib
cat > AppDir/.glycin-nosandbox.c <<'EOF_GLYCIN'
#define _GNU_SOURCE
#include <dlfcn.h>

#ifndef GLY_SANDBOX_SELECTOR_NOT_SANDBOXED
#define GLY_SANDBOX_SELECTOR_NOT_SANDBOXED 3
#endif

static void force_not_sandboxed(void *loader)
{
    void (*set_sandbox)(void *, int);

    if (!loader)
        return;

    set_sandbox = dlsym(RTLD_DEFAULT, "gly_loader_set_sandbox_selector");
    if (set_sandbox)
        set_sandbox(loader, GLY_SANDBOX_SELECTOR_NOT_SANDBOXED);
}

#define GLY_LOADER_WRAPPER(name) \
    void *gly_##name(void *arg) \
    { \
        static void *(*real)(void *) = 0; \
        void *loader; \
        if (!real) { \
            real = dlsym(RTLD_NEXT, "gly_" #name); \
            if (!real) \
                real = dlsym(RTLD_DEFAULT, "gly_" #name); \
        } \
        loader = real ? real(arg) : 0; \
        force_not_sandboxed(loader); \
        return loader; \
    }

GLY_LOADER_WRAPPER(loader_new)
GLY_LOADER_WRAPPER(loader_new_for_stream)
GLY_LOADER_WRAPPER(loader_new_for_bytes)
EOF_GLYCIN

cc -shared -fPIC -O2 AppDir/.glycin-nosandbox.c \
  -o AppDir/shared/lib/glycin-nosandbox.so -ldl
rm -f AppDir/.glycin-nosandbox.c

touch AppDir/.preload
grep -qxF 'glycin-nosandbox.so' AppDir/.preload || echo 'glycin-nosandbox.so' >> AppDir/.preload

# 只在 JRWeb/JRWebChromium 的 exec/spawn 边界注入私有 CEF 路径。
# JRWebChromium 保留 AppImage 私有 ALSA 插件目录，但清除包内 ALSA 配置覆盖。
# 此库必须排在 anylinux.so 后面：先执行原有外部环境清理，再加入唯一允许的 CEF 路径。
cat > AppDir/.jriver-cef-env.c <<'EOF_JRIVER_CEF_ENV'
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <dlfcn.h>
#include <errno.h>
#include <limits.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef int (*execve_fn_t)(const char *, char *const [], char *const []);
typedef int (*posix_spawn_fn_t)(pid_t *, const char *,
                               const posix_spawn_file_actions_t *,
                               const posix_spawnattr_t *, char *const [],
                               char *const []);

#define VISIBLE __attribute__((visibility("default")))

static char saved_appdir[PATH_MAX] = "";
static char saved_mc_version[32] = "";

__attribute__((constructor))
static void capture_jriver_paths(void)
{
    const char *value = getenv("APPDIR");

    if (value)
        snprintf(saved_appdir, sizeof(saved_appdir), "%s", value);

    value = getenv("MC_MAJOR_VERSION");
    if (value)
        snprintf(saved_mc_version, sizeof(saved_mc_version), "%s", value);
}

static const char *path_basename(const char *path)
{
    const char *slash;

    if (!path)
        return "";

    slash = strrchr(path, '/');
    return slash ? slash + 1 : path;
}

static int target_kind(const char *path, char *const argv[])
{
    const char *path_name = path_basename(path);
    const char *argv_name = argv && argv[0] ? path_basename(argv[0]) : "";

    if (strcmp(path_name, "JRWeb") == 0 || strcmp(argv_name, "JRWeb") == 0)
        return 1;
    if (strcmp(path_name, "JRWebChromium") == 0 ||
        strcmp(argv_name, "JRWebChromium") == 0)
        return 2;
    return 0;
}

static int valid_mc_version(const char *value)
{
    const unsigned char *cursor = (const unsigned char *)value;

    if (!cursor || !*cursor)
        return 0;

    for (; *cursor; cursor++) {
        if (*cursor < '0' || *cursor > '9')
            return 0;
    }
    return 1;
}

static void free_env(char **env)
{
    size_t index;

    if (!env)
        return;
    for (index = 0; env[index]; index++)
        free(env[index]);
    free(env);
}

static int is_appimage_alsa_config_env(const char *entry)
{
    return strncmp(entry, "ALSA_CONFIG_PATH=", 17) == 0 ||
           strncmp(entry, "ALSA_CONFIG_DIR=", 16) == 0;
}

static char **build_jriver_env(char *const original_env[], int kind)
{
    const char *appdir = getenv("APPDIR");
    const char *version = getenv("MC_MAJOR_VERSION");
    char cef_path[PATH_MAX];
    char mapped_path[PATH_MAX];
    char **new_env;
    size_t count = 0;
    size_t output = 0;
    size_t extra = kind == 1 ? 2 : 1;
    int length;

    if (!appdir || !*appdir)
        appdir = saved_appdir;
    if (!version || !*version)
        version = saved_mc_version;

    if (!*appdir || !valid_mc_version(version))
        return NULL;

    length = snprintf(cef_path, sizeof(cef_path),
                      "%s/usr/lib/jriver/Media Center %s/cef-runtime",
                      appdir, version);
    if (length < 0 || (size_t)length >= sizeof(cef_path))
        return NULL;

    length = snprintf(mapped_path, sizeof(mapped_path),
                      "%s/lib/jriver/Media Center %s", appdir, version);
    if (length < 0 || (size_t)length >= sizeof(mapped_path))
        return NULL;

    if (original_env) {
        while (original_env[count])
            count++;
    }

    new_env = calloc(count + extra + 1, sizeof(*new_env));
    if (!new_env)
        return NULL;

    for (size_t index = 0; index < count; index++) {
        if (strncmp(original_env[index], "LD_LIBRARY_PATH=", 16) == 0 ||
            strncmp(original_env[index], "SHARUN_EXTRA_LIBRARY_PATH=", 26) == 0)
            continue;

        if (kind == 2 && is_appimage_alsa_config_env(original_env[index]))
            continue;

        new_env[output] = strdup(original_env[index]);
        if (!new_env[output]) {
            free_env(new_env);
            return NULL;
        }
        output++;
    }

    if (asprintf(&new_env[output], "LD_LIBRARY_PATH=%s", cef_path) < 0) {
        new_env[output] = NULL;
        free_env(new_env);
        return NULL;
    }
    output++;

    if (kind == 1) {
        if (asprintf(&new_env[output], "SHARUN_EXTRA_LIBRARY_PATH=%s:%s",
                     cef_path, mapped_path) < 0) {
            new_env[output] = NULL;
            free_env(new_env);
            return NULL;
        }
        output++;
    }

    new_env[output] = NULL;
    return new_env;
}

static char *const *select_env(const char *path, char *const argv[],
                               char *const envp[], char ***allocated)
{
    int kind = target_kind(path, argv);

    *allocated = NULL;
    if (!kind)
        return envp;

    *allocated = build_jriver_env(envp, kind);
    return *allocated ? *allocated : envp;
}

VISIBLE int execve(const char *path, char *const argv[], char *const envp[])
{
    execve_fn_t real_execve = (execve_fn_t)dlsym(RTLD_NEXT, "execve");
    char **allocated;
    char *const *env;
    int result;

    if (!real_execve) {
        errno = ENOSYS;
        return -1;
    }

    env = select_env(path, argv, envp, &allocated);
    result = real_execve(path, argv, (char *const *)env);
    free_env(allocated);
    return result;
}

VISIBLE int execvpe(const char *file, char *const argv[], char *const envp[])
{
    execve_fn_t real_execvpe = (execve_fn_t)dlsym(RTLD_NEXT, "execvpe");
    char **allocated;
    char *const *env;
    int result;

    if (!real_execvpe) {
        errno = ENOSYS;
        return -1;
    }

    env = select_env(file, argv, envp, &allocated);
    result = real_execvpe(file, argv, (char *const *)env);
    free_env(allocated);
    return result;
}

static int spawn_with_env(const char *symbol, pid_t *pid, const char *path,
                          const posix_spawn_file_actions_t *actions,
                          const posix_spawnattr_t *attributes,
                          char *const argv[], char *const envp[])
{
    posix_spawn_fn_t real_spawn = (posix_spawn_fn_t)dlsym(RTLD_NEXT, symbol);
    char **allocated;
    char *const *env;
    int result;

    if (!real_spawn)
        return ENOSYS;

    env = select_env(path, argv, envp, &allocated);
    result = real_spawn(pid, path, actions, attributes, argv,
                        (char *const *)env);
    free_env(allocated);
    return result;
}

VISIBLE int posix_spawn(pid_t *pid, const char *path,
                        const posix_spawn_file_actions_t *actions,
                        const posix_spawnattr_t *attributes,
                        char *const argv[], char *const envp[])
{
    return spawn_with_env("posix_spawn", pid, path, actions, attributes,
                          argv, envp);
}

VISIBLE int posix_spawnp(pid_t *pid, const char *file,
                         const posix_spawn_file_actions_t *actions,
                         const posix_spawnattr_t *attributes,
                         char *const argv[], char *const envp[])
{
    return spawn_with_env("posix_spawnp", pid, file, actions, attributes,
                          argv, envp);
}
EOF_JRIVER_CEF_ENV

cc -shared -fPIC -O2 -Wall -Wextra -Werror AppDir/.jriver-cef-env.c \
  -o AppDir/lib/jriver-cef-env.so -ldl
rm -f AppDir/.jriver-cef-env.c

if ! grep -qxF 'anylinux.so' AppDir/.preload; then
  echo '错误：quick-sharun 未启用 anylinux.so，无法保证 JRWebChromium 环境清理顺序。' >&2
  exit 1
fi
sed -i '/^jriver-cef-env\.so$/d' AppDir/.preload
echo 'jriver-cef-env.so' >> AppDir/.preload

# 强制保留 JRiver 原始目录结构
mkdir -p AppDir/usr/lib/jriver
rm -rf "AppDir/usr/lib/jriver/Media Center ${MC_VER}" \
       "AppDir/usr/lib/jriver/MC${MC_VER}"
cp -a "/usr/lib/jriver/Media Center ${MC_VER}" "AppDir/usr/lib/jriver/"
ln -sfn "Media Center ${MC_VER}" "AppDir/usr/lib/jriver/MC${MC_VER}"

# 修复 JRiver 插件加载使用的硬编码安装根目录。
# quick-sharun 会生成 01-path-mapping-hardcoded.hook，并在运行时把 /tmp/<随机目录>
# 链接到 AppImage 的 lib 目录；这里复用同一个随机目录，避免新增 preload 或全局库路径。
HARDPATH_HOOK=""
for hook_candidate in \
  AppDir/bin/01-path-mapping-hardcoded.hook \
  AppDir/shared/bin/01-path-mapping-hardcoded.hook; do
  if [[ -f "$hook_candidate" ]]; then
    HARDPATH_HOOK="$hook_candidate"
    break
  fi
done

if [[ -z "$HARDPATH_HOOK" ]]; then
  echo '错误：quick-sharun 未生成 01-path-mapping-hardcoded.hook。' >&2
  exit 1
fi

SHARUN_TMP_LIB="$(grep -m1 '^_tmp_lib=' "$HARDPATH_HOOK" | cut -d= -f2-)"
SHARUN_TMP_LIB="${SHARUN_TMP_LIB//\'/}"
SHARUN_TMP_LIB="${SHARUN_TMP_LIB//\"/}"
SHARUN_TMP_LIB="${SHARUN_TMP_LIB//[[:space:]]/}"

if [[ ! "$SHARUN_TMP_LIB" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "错误：无法从 $HARDPATH_HOOK 解析 quick-sharun 的临时 lib 映射目录。" >&2
  exit 1
fi

if ! grep -Fq '"$APPDIR"/lib' "$HARDPATH_HOOK" || \
   ! grep -Fq '/tmp/"$_tmp_lib"' "$HARDPATH_HOOK"; then
  echo '错误：quick-sharun 的临时 lib 映射 hook 结构不符合预期。' >&2
  exit 1
fi

JRIVER_OLD_ROOT="/usr/lib/jriver/Media Center ${MC_VER}"
JRIVER_MAPPED_ROOT="/tmp/${SHARUN_TMP_LIB}/jriver/Media Center ${MC_VER}"

if [[ ${#JRIVER_OLD_ROOT} -ne ${#JRIVER_MAPPED_ROOT} ]]; then
  echo '错误：JRiver 硬编码路径替换前后长度不一致，拒绝修改 ELF。' >&2
  echo "旧路径：$JRIVER_OLD_ROOT" >&2
  echo "新路径：$JRIVER_MAPPED_ROOT" >&2
  exit 1
fi

python3 - \
  "$JRIVER_OLD_ROOT" \
  "$JRIVER_MAPPED_ROOT" \
  "$MC_VER" \
  "AppDir/lib/jriver/Media Center ${MC_VER}" \
  "AppDir/usr/lib/jriver/Media Center ${MC_VER}" <<'PY_JRIVER_PATH'
from pathlib import Path
import sys

old = sys.argv[1].encode()
new = sys.argv[2].encode()
mc_ver = sys.argv[3]
roots = [Path(value) for value in sys.argv[4:]]
excluded_names = {"JRWeb", "JRWeb.real", "JRWorker", "JRWorker.real", "PackageInstaller"}

if len(old) != len(new):
    raise SystemExit("JRiver path replacement length mismatch")

patched_files = 0
patched_occurrences = 0

for root in roots:
    if not root.is_dir():
        raise SystemExit(f"JRiver directory missing: {root}")

    for path in root.rglob("*"):
        if path.is_symlink() or not path.is_file() or path.name in excluded_names:
            continue

        data = path.read_bytes()
        if not data.startswith(b"\x7fELF") or old not in data:
            continue

        occurrences = data.count(old)
        path.write_bytes(data.replace(old, new))
        patched_files += 1
        patched_occurrences += occurrences

if patched_files == 0:
    raise SystemExit("No JRiver ELF contained the hardcoded install root")

required_relpaths = (
    f"mc{mc_ver}",
    "libJRTools.so",
    "Plugins/libout_Main.so",
)

for root in roots:
    for relpath in required_relpaths:
        path = root / relpath
        data = path.read_bytes()
        if not data.startswith(b"\x7fELF"):
            raise SystemExit(f"Required JRiver ELF invalid: {path}")
        if old in data:
            raise SystemExit(f"Old JRiver install root remains: {path}")
        if new not in data:
            raise SystemExit(f"Mapped JRiver install root missing: {path}")

for root in roots:
    for path in root.rglob("*"):
        if path.is_symlink() or not path.is_file() or path.name in excluded_names:
            continue
        data = path.read_bytes()
        if data.startswith(b"\x7fELF") and old in data:
            raise SystemExit(f"Old JRiver install root remains in ELF: {path}")

print(f"JRiver hardcoded path patched: files={patched_files}, replacements={patched_occurrences}")
PY_JRIVER_PATH

# 保留 WebKitGTK 的进程目录和主库，供 JRWeb 使用。
mkdir -p AppDir/usr/lib AppDir/shared/lib
rm -rf AppDir/usr/lib/webkit2gtk-4.1
cp -a /usr/lib/webkit2gtk-4.1 AppDir/usr/lib/
cp -a /usr/lib/libwebkit2gtk-4.1.so* AppDir/shared/lib/
cp -a /usr/lib/libjavascriptcoregtk-4.1.so* AppDir/shared/lib/

# 7. 配置 JRWeb/JRWorker 子进程及包内运行数据
# quick-sharun 处理后的 JRiver 目录被上面的原始目录覆盖，
# 因此为内部子程序重新建立独立运行时包装器。
wrap_jriver_child() {
  local target="$1"

  if [[ ! -x "$target" || -e "$target.real" ]]; then
    return
  fi

  mv "$target" "$target.real"

  cat > "$target" <<'EOF_CHILD'
#!/bin/sh
set -e

SELF="$(readlink -f "$0")"
HERE="$(dirname "$SELF")"
REAL="$SELF.real"
APPDIR="${APPDIR:-$(cd "$HERE/../../../.." && pwd)}"
SHARUN_DIR="$APPDIR"
export APPDIR SHARUN_DIR

# JRWeb/JRWorker 的包装脚本启动阶段保持宿主 shell 环境干净。
# 包内 glibc 只允许由 Sharun 启动器配合包内动态加载器使用。
unset LD_PRELOAD LD_LIBRARY_PATH

if [ -f "$APPDIR/.env" ]; then
  while IFS= read -r env_line || [ -n "$env_line" ]; do
    case "$env_line" in
      ''|'#'*) continue ;;
      *) eval "export $env_line" ;;
    esac
  done < "$APPDIR/.env"
fi

PATH="$APPDIR/bin:$APPDIR/shared/bin:$APPDIR/usr/bin:${PATH:-/usr/local/bin:/usr/bin:/bin}"
XDG_DATA_DIRS="$APPDIR/share:$APPDIR/usr/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export PATH XDG_DATA_DIRS

if [ -d "$APPDIR/share/glib-2.0/schemas" ]; then
  GSETTINGS_SCHEMA_DIR="$APPDIR/share/glib-2.0/schemas"
  export GSETTINGS_SCHEMA_DIR
fi

# JRWeb.real 不经过系统路径启动，显式指定包内 GTK3 输入法模块缓存。
GTK_BUNDLE_DIR="$APPDIR/shared/lib/gtk-3.0"
GTK_IM_MODULE_DIR="$GTK_BUNDLE_DIR/3.0.0/immodules"
GTK_IM_SOURCE_CACHE="$GTK_BUNDLE_DIR/3.0.0/immodules.cache"
if [ -f "$GTK_IM_SOURCE_CACHE" ] && [ -f "$GTK_IM_MODULE_DIR/im-fcitx5.so" ]; then
  GTK_IM_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
  GTK_IM_RUNTIME_CACHE="$GTK_IM_RUNTIME_DIR/jriver-gtk-immodules-$(id -u).cache"
  GTK_IM_RUNTIME_TMP="$GTK_IM_RUNTIME_CACHE.tmp.$$"
  umask 077
  sed "s|\"im-fcitx5.so\"|\"$GTK_IM_MODULE_DIR/im-fcitx5.so\"|g" \
    "$GTK_IM_SOURCE_CACHE" > "$GTK_IM_RUNTIME_TMP"
  mv -f "$GTK_IM_RUNTIME_TMP" "$GTK_IM_RUNTIME_CACHE"
  GTK_PATH="$GTK_BUNDLE_DIR"
  GTK_IM_MODULE_FILE="$GTK_IM_RUNTIME_CACHE"
  export GTK_PATH GTK_IM_MODULE_FILE
fi

if [ -d "$APPDIR/shared/lib/alsa-lib" ]; then
  ALSA_PLUGIN_DIR="$APPDIR/shared/lib/alsa-lib"
  export ALSA_PLUGIN_DIR
fi
if [ -f "$APPDIR/share/alsa/alsa.conf" ]; then
  ALSA_CONFIG_PATH="$APPDIR/share/alsa/alsa.conf"
  ALSA_CONFIG_DIR="$APPDIR/share/alsa"
  export ALSA_CONFIG_PATH ALSA_CONFIG_DIR
fi

if [ -d "$APPDIR/shared/lib/gbm" ]; then
  GBM_BACKENDS_PATH="$APPDIR/shared/lib/gbm"
  export GBM_BACKENDS_PATH
fi

# JRWeb/JRWorker 通过 GTK3 Fcitx5 模块连接宿主输入法。
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
export GTK_IM_MODULE QT_IM_MODULE XMODIFIERS SDL_IM_MODULE

WEBKIT_EXEC_PATH="$APPDIR/bin"
WEBKIT_INJECTED_BUNDLE_PATH="$APPDIR/usr/lib/webkit2gtk-4.1/injected-bundle"
export WEBKIT_EXEC_PATH WEBKIT_INJECTED_BUNDLE_PATH

CHILD_NAME="${SELF##*/}"
SHARUN_CHILD="$APPDIR/bin/$CHILD_NAME"
if [ "$CHILD_NAME" = "JRWeb" ] && [ -d "$HERE/cef-runtime" ]; then
  SHARUN_EXTRA_LIBRARY_PATH="$HERE/cef-runtime:$HERE"
else
  SHARUN_EXTRA_LIBRARY_PATH="$HERE"
fi
export SHARUN_EXTRA_LIBRARY_PATH

if [ ! -x "$SHARUN_CHILD" ]; then
  echo "Error: Sharun child launcher not found: $SHARUN_CHILD" >&2
  exit 1
fi

# 仅 JRWeb 在最后 exec 前导出私有 CEF 目录。
# 这里不包含 shared/lib 或 lib，因此不会重新暴露 AppImage 内 glibc；
# JRWeb 运行时创建并启动的 ~/.jriver/.../JRWebChromium 会继承该路径并找到 libcef.so。
if [ "$CHILD_NAME" = "JRWeb" ] && [ -d "$HERE/cef-runtime" ]; then
  LD_LIBRARY_PATH="$HERE/cef-runtime"
  export LD_LIBRARY_PATH
fi

exec "$SHARUN_CHILD" "$@"
EOF_CHILD

  chmod +x "$target"
}

JRIVER_MAPPED_APPDIR="AppDir/lib/jriver/Media Center ${MC_VER}"
JRIVER_APPDIR="AppDir/usr/lib/jriver/Media Center ${MC_VER}"
CEF_PRIVATE_DIR="$JRIVER_APPDIR/cef-runtime"

# CEF runtime 只保留一份：放在 JRiver 私有目录，避免重复打包巨大的 libcef.so。
rm -rf "$CEF_PRIVATE_DIR"
mkdir -p "$CEF_PRIVATE_DIR"
cp -a "$CEF_ROOT/Release/." "$CEF_PRIVATE_DIR/"
cp -a "$CEF_ROOT/Resources/." "$CEF_PRIVATE_DIR/"

# quick-sharun 可能已经收集过 libcef.so；这里删除其他副本，只保留私有 runtime 中这一份。
while IFS= read -r -d '' cef_copy; do
  if [[ "$cef_copy" != "$CEF_PRIVATE_DIR/libcef.so" ]]; then
    rm -f "$cef_copy"
  fi
done < <(find AppDir -type f -name 'libcef.so' -print0)
find AppDir -type l -name 'libcef.so' -delete

# JRWeb 最终通过 AppDir/bin/JRWeb 的 Sharun launcher 进入；核心资源在 bin 下只建相对软链接。
for cef_resource_name in \
  chrome_100_percent.pak \
  chrome_200_percent.pak \
  resources.pak \
  icudtl.dat \
  v8_context_snapshot.bin \
  snapshot_blob.bin \
  vk_swiftshader_icd.json \
  chrome-sandbox \
  locales; do
  if [[ -e "$CEF_PRIVATE_DIR/$cef_resource_name" ]]; then
    rm -rf "AppDir/bin/$cef_resource_name"
    ln -s "../usr/lib/jriver/Media Center ${MC_VER}/cef-runtime/$cef_resource_name" \
      "AppDir/bin/$cef_resource_name"
  fi
done

wrap_jriver_child "$JRIVER_APPDIR/JRWeb"
wrap_jriver_child "$JRIVER_APPDIR/JRWorker"

# ALSA 必须同时携带插件和配置；只有插件会出现 Unknown PCM pulse。
mkdir -p AppDir/shared/lib AppDir/share AppDir/etc
rm -rf AppDir/shared/lib/alsa-lib AppDir/share/alsa AppDir/etc/alsa
cp -a /usr/lib/alsa-lib AppDir/shared/lib/
cp -a /usr/share/alsa AppDir/share/
if [ -d /etc/alsa ]; then
  cp -a /etc/alsa AppDir/etc/
fi

# PulseAudio 私有库与 GVFS 公共库必须进入实际动态库搜索路径。
if [ -d /usr/lib/pulseaudio ]; then
  rm -rf AppDir/shared/lib/pulseaudio
  cp -a /usr/lib/pulseaudio AppDir/shared/lib/
fi
cp -a /usr/lib/gvfs/libgvfscommon.so* AppDir/shared/lib/

# JRWeb 的硬件加速需要 Mesa GBM 后端。
if [ -d /usr/lib/gbm ]; then
  rm -rf AppDir/shared/lib/gbm
  cp -a /usr/lib/gbm AppDir/shared/lib/
fi

# Glycin 配置。
if [ -d /usr/share/glycin-loaders ]; then
  rm -rf AppDir/share/glycin-loaders
  cp -a /usr/share/glycin-loaders AppDir/share/
fi

# 补齐 GSettings schemas。
if [ -d /usr/share/glib-2.0/schemas ]; then
  mkdir -p AppDir/share/glib-2.0
  rm -rf AppDir/share/glib-2.0/schemas
  cp -a /usr/share/glib-2.0/schemas AppDir/share/glib-2.0/
  glib-compile-schemas AppDir/share/glib-2.0/schemas
fi

# 放入 pathmap
install -Dm755 "$PATHMAP_BIN" AppDir/usr/bin/pathmap

# 8. 生成主程序启动器
# 只写当前用户的 JRiver 版本目录，不修改系统目录。
cat > AppDir/run-mc.sh <<EOF_RUN
#!/bin/sh
set -e

MC_MAJOR_VERSION="${MC_VER}"
JRIVER_HOME="\$HOME/.jriver/Media Center \$MC_MAJOR_VERSION"
JRIVER_APPDIR="\$APPDIR/usr/lib/jriver/Media Center \$MC_MAJOR_VERSION"

mkdir -p "\$JRIVER_HOME"
[ -d "\$JRIVER_APPDIR/Skins" ] && cp -a -n "\$JRIVER_APPDIR/Skins" "\$JRIVER_HOME/" 2>/dev/null || true
[ -d "\$JRIVER_APPDIR/Data" ] && cp -a -n "\$JRIVER_APPDIR/Data" "\$JRIVER_HOME/" 2>/dev/null || true
[ -d "\$JRIVER_APPDIR/Plugins" ] && cp -a -n "\$JRIVER_APPDIR/Plugins" "\$JRIVER_HOME/" 2>/dev/null || true
[ -d "\$JRIVER_APPDIR/Visualizations" ] && cp -a -n "\$JRIVER_APPDIR/Visualizations" "\$JRIVER_HOME/" 2>/dev/null || true

cd "\$JRIVER_APPDIR"

# 只通过 Sharun 启动器运行 JRiver，禁止直接执行 shared/bin 或原始 ELF。
if [ -x "\$APPDIR/bin/mediacenter\$MC_MAJOR_VERSION" ]; then
  exec "\$APPDIR/bin/mediacenter\$MC_MAJOR_VERSION" "\$@"
elif [ -x "\$APPDIR/bin/mc\$MC_MAJOR_VERSION" ]; then
  exec "\$APPDIR/bin/mc\$MC_MAJOR_VERSION" "\$@"
else
  echo "Error: Sharun launcher mediacenter\$MC_MAJOR_VERSION / mc\$MC_MAJOR_VERSION not found."
  exit 1
fi
EOF_RUN
chmod +x AppDir/run-mc.sh

# 保留 quick-sharun 生成的启动器供排查，自定义 AppRun 负责 pathmap。
mv AppDir/AppRun AppDir/AppRun.sharun

cat > AppDir/AppRun <<'EOF_APPRUN'
#!/bin/sh
set -e

APPDIR="${APPDIR:-$(dirname "$(readlink -f "$0")")}" 
SHARUN_DIR="$APPDIR"
export APPDIR SHARUN_DIR

# 自定义 AppRun 是宿主 shell 脚本，禁止让它及其调用的 id/sed/mv 等宿主工具
# 继承 AppImage 的 libc 或 preload。包内 .preload 由 Sharun 启动器处理。
unset LD_PRELOAD LD_LIBRARY_PATH

if [ -f "$APPDIR/.env" ]; then
  while IFS= read -r env_line || [ -n "$env_line" ]; do
    case "$env_line" in
      ''|'#'*) continue ;;
      *) eval "export $env_line" ;;
    esac
  done < "$APPDIR/.env"
fi

MC_MAJOR_VERSION=__MC_VER__
export MC_MAJOR_VERSION

PATH="$APPDIR/bin:$APPDIR/shared/bin:$APPDIR/usr/bin:${PATH:-/usr/local/bin:/usr/bin:/bin}"
export PATH

XDG_DATA_DIRS="$APPDIR/share:$APPDIR/usr/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export XDG_DATA_DIRS

if [ -d "$APPDIR/share/glib-2.0/schemas" ]; then
  GSETTINGS_SCHEMA_DIR="$APPDIR/share/glib-2.0/schemas"
  export GSETTINGS_SCHEMA_DIR
fi

GTK_BUNDLE_DIR="$APPDIR/shared/lib/gtk-3.0"
GTK_IM_MODULE_DIR="$GTK_BUNDLE_DIR/3.0.0/immodules"
GTK_IM_SOURCE_CACHE="$GTK_BUNDLE_DIR/3.0.0/immodules.cache"
if [ -f "$GTK_IM_SOURCE_CACHE" ] && [ -f "$GTK_IM_MODULE_DIR/im-fcitx5.so" ]; then
  GTK_IM_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
  GTK_IM_RUNTIME_CACHE="$GTK_IM_RUNTIME_DIR/jriver-gtk-immodules-$(id -u).cache"
  GTK_IM_RUNTIME_TMP="$GTK_IM_RUNTIME_CACHE.tmp.$$"
  umask 077
  sed "s|\"im-fcitx5.so\"|\"$GTK_IM_MODULE_DIR/im-fcitx5.so\"|g" \
    "$GTK_IM_SOURCE_CACHE" > "$GTK_IM_RUNTIME_TMP"
  mv -f "$GTK_IM_RUNTIME_TMP" "$GTK_IM_RUNTIME_CACHE"
  GTK_PATH="$GTK_BUNDLE_DIR"
  GTK_IM_MODULE_FILE="$GTK_IM_RUNTIME_CACHE"
  export GTK_PATH GTK_IM_MODULE_FILE
fi

# JRiver 只需要本地文件系统。禁用 GVFS/Portal 混用，避免文件选择器崩溃。
GIO_USE_VFS=local
GTK_USE_PORTAL=0
export GIO_USE_VFS GTK_USE_PORTAL

if [ -d "$APPDIR/shared/lib/alsa-lib" ]; then
  ALSA_PLUGIN_DIR="$APPDIR/shared/lib/alsa-lib"
  export ALSA_PLUGIN_DIR
fi
if [ -f "$APPDIR/share/alsa/alsa.conf" ]; then
  ALSA_CONFIG_PATH="$APPDIR/share/alsa/alsa.conf"
  ALSA_CONFIG_DIR="$APPDIR/share/alsa"
  export ALSA_CONFIG_PATH ALSA_CONFIG_DIR
fi

if [ -d "$APPDIR/shared/lib/gbm" ]; then
  GBM_BACKENDS_PATH="$APPDIR/shared/lib/gbm"
  export GBM_BACKENDS_PATH
fi

GST_PLUGIN_PATH="$APPDIR/usr/lib/gstreamer-1.0:$APPDIR/shared/lib/gstreamer-1.0:${GST_PLUGIN_PATH:-}"
GST_PLUGIN_SYSTEM_PATH="$GST_PLUGIN_PATH"
GST_PLUGIN_SYSTEM_PATH_1_0="$GST_PLUGIN_PATH"
export GST_PLUGIN_PATH GST_PLUGIN_SYSTEM_PATH GST_PLUGIN_SYSTEM_PATH_1_0

WEBKIT_EXEC_PATH="$APPDIR/bin"
WEBKIT_INJECTED_BUNDLE_PATH="$APPDIR/usr/lib/webkit2gtk-4.1/injected-bundle"
export WEBKIT_EXEC_PATH WEBKIT_INJECTED_BUNDLE_PATH

# CI 环境通常注入 ibus；JRiver 包内明确使用宿主 Fcitx5。
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
export GTK_IM_MODULE QT_IM_MODULE XMODIFIERS SDL_IM_MODULE

if [ -z "${XDG_RUNTIME_DIR:-}" ] && [ -d "/run/user/$(id -u)" ]; then
  XDG_RUNTIME_DIR="/run/user/$(id -u)"
  export XDG_RUNTIME_DIR
fi

if [ -z "${PULSE_SERVER:-}" ] && [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/pulse/native" ]; then
  PULSE_SERVER="unix:${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/pulse/native"
  export PULSE_SERVER
fi

PATHMAP="$APPDIR/usr/bin/pathmap"
if [ ! -x "$PATHMAP" ]; then
  echo "Error: pathmap not found: $PATHMAP"
  exit 1
fi

PATH_MAPPING="/usr/lib/jriver/Media Center __MC_VER__:$APPDIR/usr/lib/jriver/Media Center __MC_VER__,/usr/lib/jriver/MC__MC_VER__:$APPDIR/usr/lib/jriver/MC__MC_VER__,/usr/share/alsa:$APPDIR/share/alsa,/etc/alsa:$APPDIR/etc/alsa"
PATHMAP_RELSYMLINK=1
PATHMAP_REVERSE=0
export PATH_MAPPING PATHMAP_RELSYMLINK PATHMAP_REVERSE

exec "$PATHMAP" "$APPDIR/run-mc.sh" "$@"
EOF_APPRUN
sed -i "s/__MC_VER__/${MC_VER}/g" AppDir/AppRun
chmod +x AppDir/AppRun

# 9. 执行最终检查并生成 AppImage
# 构建后检查只用于诊断，不再因为单个路径缺失而终止打包。
check_path() {
  local mode="$1"
  local path="$2"

  if [[ "$mode" == "file" && -f "$path" ]] || \
     [[ "$mode" == "exists" && -e "$path" ]] || \
     [[ "$mode" == "dir" && -d "$path" ]] || \
     [[ "$mode" == "exec" && -x "$path" ]] || \
     [[ "$mode" == "nonempty" && -s "$path" ]]; then
    printf 'CHECK OK: %s\n' "$path"
  else
    printf 'CHECK MISSING: %s\n' "$path" >&2
  fi
}

check_path file AppDir/shared/lib/alsa-lib/libasound_module_pcm_pulse.so
check_path file AppDir/share/alsa/alsa.conf
check_path exists AppDir/etc/alsa/conf.d/50-pulseaudio.conf
check_path file AppDir/shared/lib/libgvfscommon.so
check_path file AppDir/shared/lib/libwebkit2gtk-4.1.so.0
check_path file AppDir/shared/lib/gtk-3.0/3.0.0/immodules.cache
check_path file AppDir/shared/lib/gbm/dri_gbm.so
check_path file AppDir/shared/lib/glycin-nosandbox.so
check_path file AppDir/lib/jriver-cef-env.so
check_path file "$CEF_PRIVATE_DIR/libcef.so"
check_path file "$CEF_PRIVATE_DIR/icudtl.dat"
check_path dir "$CEF_PRIVATE_DIR/locales"
check_path exists AppDir/bin/icudtl.dat
check_path exists AppDir/bin/locales
check_path file "AppDir/lib/jriver/Media Center ${MC_VER}/Plugins/libout_Main.so"
check_path file "$JRIVER_APPDIR/Plugins/libout_Main.so"
check_path dir AppDir/usr/lib/webkit2gtk-4.1
check_path exec "AppDir/bin/mediacenter${MC_VER}"
check_path exec "AppDir/bin/mc${MC_VER}"
check_path exec AppDir/bin/JRWeb
check_path exec AppDir/bin/JRWorker
check_path exec "$JRIVER_MAPPED_APPDIR/JRWeb"
check_path exec "$JRIVER_APPDIR/JRWeb"
check_path exec "$JRIVER_APPDIR/JRWeb.real"
check_path exec "$JRIVER_APPDIR/JRWorker"
check_path exec "$JRIVER_APPDIR/JRWorker.real"
check_path dir AppDir/share/glycin-loaders
check_path nonempty AppDir/.env

if find AppDir -type f -name 'im-fcitx5.so' -print -quit | grep -q .; then
  echo 'CHECK OK: bundled GTK3 Fcitx5 input module'
else
  echo 'CHECK MISSING: GTK3 Fcitx5 input module' >&2
fi

# AppRun 是宿主 shell 启动器，禁止设置 LD_LIBRARY_PATH，防止包内 glibc 暴露给宿主工具。
# JRWeb/JRWorker 共用同一包装器模板；其中的 LD_LIBRARY_PATH 赋值受 CHILD_NAME=JRWeb 条件限制。
if grep -q '^[[:space:]]*LD_LIBRARY_PATH=' AppDir/AppRun; then
  echo '错误：AppRun 仍在设置 LD_LIBRARY_PATH，可能导致宿主加载器与包内 glibc 混用。' >&2
  exit 1
fi

# 实际硬编码路径命中的 JRWeb 必须保持 quick-sharun 的 ELF 构建结果；
# quick-sharun 不保证它与 AppDir/bin/JRWeb 同 inode，因此这里只禁止 shell 包装器和 .real。
if [[ -e "$JRIVER_MAPPED_APPDIR/JRWeb.real" ]] || \
   ! readelf -h "$JRIVER_MAPPED_APPDIR/JRWeb" >/dev/null 2>&1; then
  echo '错误：映射目录中的 JRWeb 已被包装或不再是 ELF。' >&2
  exit 1
fi

# anylinux.so 必须先清理环境，jriver-cef-env.so 再精确补入 CEF 路径。
python3 - AppDir/.preload <<'PY_CEF_PRELOAD_ORDER'
from pathlib import Path
import sys

lines = [line.strip() for line in Path(sys.argv[1]).read_text().splitlines() if line.strip()]
if lines.count("anylinux.so") != 1:
    raise SystemExit("anylinux.so preload entry must appear exactly once")
if lines.count("jriver-cef-env.so") != 1:
    raise SystemExit("jriver-cef-env.so preload entry must appear exactly once")
if lines.index("anylinux.so") > lines.index("jriver-cef-env.so"):
    raise SystemExit("jriver-cef-env.so must load after anylinux.so")
PY_CEF_PRELOAD_ORDER

CEF_ENV_SYMBOLS="$(nm -D --defined-only AppDir/lib/jriver-cef-env.so | awk '{print $3}')"
for cef_env_symbol in execve execvpe posix_spawn posix_spawnp; do
  if ! grep -qxF "$cef_env_symbol" <<<"$CEF_ENV_SYMBOLS"; then
    echo "错误：jriver-cef-env.so 缺少拦截符号：$cef_env_symbol" >&2
    exit 1
  fi
done

# 同时验证 exec 与 posix_spawn：JRWeb 获得 Sharun+CEF 路径并保留 AppImage ALSA 覆盖；
# JRWebChromium 只获得 CEF 路径、保留 AppImage ALSA 插件目录、清除包内 ALSA 配置并保留 PULSE_SERVER；
# 无关外部进程继续由 anylinux.so 清理，不能继承任何 AppImage 库路径或 preload。
CEF_ENV_TEST_DIR="$(mktemp -d "$PWD/.jriver-cef-env-test.XXXXXX")"
cat > "$CEF_ENV_TEST_DIR/spawn-test.c" <<'EOF_CEF_SPAWN_TEST'
#include <spawn.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>

extern char **environ;

int main(int argc, char **argv)
{
    char *child_argv[2];
    pid_t pid;
    int result;
    int status;

    if (argc != 2)
        return 2;

    child_argv[0] = argv[1];
    child_argv[1] = NULL;
    result = posix_spawn(&pid, "/usr/bin/env", NULL, NULL, child_argv, environ);
    if (result != 0) {
        fprintf(stderr, "posix_spawn failed: %s\n", strerror(result));
        return 3;
    }
    if (waitpid(pid, &status, 0) < 0)
        return 4;
    return WIFEXITED(status) ? WEXITSTATUS(status) : 5;
}
EOF_CEF_SPAWN_TEST

cc -O2 -Wall -Wextra -Werror "$CEF_ENV_TEST_DIR/spawn-test.c" \
  -o "$CEF_ENV_TEST_DIR/spawn-test"

CEF_RUNTIME_ABS="$PWD/$CEF_PRIVATE_DIR"
JRIVER_MAPPED_ABS="$PWD/$JRIVER_MAPPED_APPDIR"
CEF_ENV_PRELOAD="$PWD/AppDir/lib/anylinux.so:$PWD/AppDir/lib/jriver-cef-env.so"
ALSA_PLUGIN_TEST="/tmp/jriver-alsa-plugin-test"
ALSA_CONFIG_TEST="/tmp/jriver-alsa-config-test"
ALSA_CONFIG_DIR_TEST="/tmp/jriver-alsa-config-dir-test"
PULSE_SERVER_TEST="unix:/tmp/jriver-pulse-test"

run_cef_exec_test() {
  local target_name="$1"

  env -i \
    PATH=/usr/bin:/bin \
    APPDIR="$PWD/AppDir" \
    MC_MAJOR_VERSION="$MC_VER" \
    ALSA_PLUGIN_DIR="$ALSA_PLUGIN_TEST" \
    ALSA_CONFIG_PATH="$ALSA_CONFIG_TEST" \
    ALSA_CONFIG_DIR="$ALSA_CONFIG_DIR_TEST" \
    PULSE_SERVER="$PULSE_SERVER_TEST" \
    LD_LIBRARY_PATH="$PWD/AppDir/cef-clean-test-marker" \
    LD_PRELOAD="$CEF_ENV_PRELOAD" \
    /bin/bash --noprofile --norc -c 'exec -a "$1" /usr/bin/env' _ "$target_name"
}

run_cef_spawn_test() {
  local target_name="$1"

  env -i \
    PATH=/usr/bin:/bin \
    APPDIR="$PWD/AppDir" \
    MC_MAJOR_VERSION="$MC_VER" \
    ALSA_PLUGIN_DIR="$ALSA_PLUGIN_TEST" \
    ALSA_CONFIG_PATH="$ALSA_CONFIG_TEST" \
    ALSA_CONFIG_DIR="$ALSA_CONFIG_DIR_TEST" \
    PULSE_SERVER="$PULSE_SERVER_TEST" \
    LD_LIBRARY_PATH="$PWD/AppDir/cef-clean-test-marker" \
    LD_PRELOAD="$CEF_ENV_PRELOAD" \
    "$CEF_ENV_TEST_DIR/spawn-test" "$target_name"
}

for cef_launch_mode in exec spawn; do
  if [[ "$cef_launch_mode" == exec ]]; then
    JRWEB_ENV_OUTPUT="$(run_cef_exec_test JRWeb)"
    CHROMIUM_ENV_OUTPUT="$(run_cef_exec_test JRWebChromium)"
    UNRELATED_ENV_OUTPUT="$(run_cef_exec_test UnrelatedChild)"
  else
    JRWEB_ENV_OUTPUT="$(run_cef_spawn_test JRWeb)"
    CHROMIUM_ENV_OUTPUT="$(run_cef_spawn_test JRWebChromium)"
    UNRELATED_ENV_OUTPUT="$(run_cef_spawn_test UnrelatedChild)"
  fi

  if ! grep -qxF "LD_LIBRARY_PATH=$CEF_RUNTIME_ABS" <<<"$JRWEB_ENV_OUTPUT" || \
     ! grep -qxF "SHARUN_EXTRA_LIBRARY_PATH=$CEF_RUNTIME_ABS:$JRIVER_MAPPED_ABS" \
       <<<"$JRWEB_ENV_OUTPUT" || \
     ! grep -qxF "ALSA_PLUGIN_DIR=$ALSA_PLUGIN_TEST" <<<"$JRWEB_ENV_OUTPUT" || \
     ! grep -qxF "ALSA_CONFIG_PATH=$ALSA_CONFIG_TEST" <<<"$JRWEB_ENV_OUTPUT" || \
     ! grep -qxF "ALSA_CONFIG_DIR=$ALSA_CONFIG_DIR_TEST" <<<"$JRWEB_ENV_OUTPUT" || \
     ! grep -qxF "PULSE_SERVER=$PULSE_SERVER_TEST" <<<"$JRWEB_ENV_OUTPUT" || \
     grep -q '^LD_PRELOAD=' <<<"$JRWEB_ENV_OUTPUT"; then
    echo "错误：$cef_launch_mode 未向 JRWeb 精确注入 Sharun/CEF 环境或错误清除了 JRWeb ALSA 环境。" >&2
    exit 1
  fi

  if ! grep -qxF "LD_LIBRARY_PATH=$CEF_RUNTIME_ABS" <<<"$CHROMIUM_ENV_OUTPUT" || \
     grep -q '^SHARUN_EXTRA_LIBRARY_PATH=' <<<"$CHROMIUM_ENV_OUTPUT" || \
     ! grep -qxF "ALSA_PLUGIN_DIR=$ALSA_PLUGIN_TEST" <<<"$CHROMIUM_ENV_OUTPUT" || \
     grep -Eq '^ALSA_(CONFIG_PATH|CONFIG_DIR)=' <<<"$CHROMIUM_ENV_OUTPUT" || \
     ! grep -qxF "PULSE_SERVER=$PULSE_SERVER_TEST" <<<"$CHROMIUM_ENV_OUTPUT" || \
     grep -q '^LD_PRELOAD=' <<<"$CHROMIUM_ENV_OUTPUT"; then
    echo "错误：$cef_launch_mode 未向 JRWebChromium 精确保留 ALSA 插件目录或未清除包内 ALSA 配置。" >&2
    exit 1
  fi

  if grep -q '^LD_LIBRARY_PATH=' <<<"$UNRELATED_ENV_OUTPUT" || \
     grep -q '^SHARUN_EXTRA_LIBRARY_PATH=' <<<"$UNRELATED_ENV_OUTPUT" || \
     grep -q '^LD_PRELOAD=' <<<"$UNRELATED_ENV_OUTPUT" || \
     ! grep -qxF "ALSA_PLUGIN_DIR=$ALSA_PLUGIN_TEST" <<<"$UNRELATED_ENV_OUTPUT" || \
     ! grep -qxF "ALSA_CONFIG_PATH=$ALSA_CONFIG_TEST" <<<"$UNRELATED_ENV_OUTPUT" || \
     ! grep -qxF "ALSA_CONFIG_DIR=$ALSA_CONFIG_DIR_TEST" <<<"$UNRELATED_ENV_OUTPUT" || \
     ! grep -qxF "PULSE_SERVER=$PULSE_SERVER_TEST" <<<"$UNRELATED_ENV_OUTPUT"; then
    echo "错误：$cef_launch_mode 改变了无关外部进程的环境清理结果。" >&2
    exit 1
  fi
done

rm -rf "$CEF_ENV_TEST_DIR"

# JRWeb 只允许在最终 exec 前设置唯一的私有 CEF 路径，不能包含 shared/lib 或 AppImage lib。
if ! grep -Fq 'LD_LIBRARY_PATH="$HERE/cef-runtime"' "$JRIVER_APPDIR/JRWeb"; then
  echo '错误：JRWeb 未设置私有 CEF LD_LIBRARY_PATH。' >&2
  exit 1
fi
if grep -E 'LD_LIBRARY_PATH=.*(shared/lib|\$APPDIR/lib|\$HERE:)' "$JRIVER_APPDIR/JRWeb"; then
  echo '错误：JRWeb LD_LIBRARY_PATH 超出私有 cef-runtime 范围。' >&2
  exit 1
fi

# CEF 只允许一份实体 libcef.so，并且必须位于 JRiver 私有 cef-runtime。
CEF_FILE_COUNT="$(find AppDir -type f -name 'libcef.so' | wc -l | tr -d '[:space:]')"
if [[ "$CEF_FILE_COUNT" != "1" ]] || \
   [[ ! -f "$CEF_PRIVATE_DIR/libcef.so" ]] || \
   [[ ! -f "$CEF_PRIVATE_DIR/icudtl.dat" ]] || \
   [[ ! -d "$CEF_PRIVATE_DIR/locales" ]]; then
  echo "错误：CEF runtime 布局异常，libcef.so 实体数量=$CEF_FILE_COUNT。" >&2
  exit 1
fi

if ! grep -aFq "$CEF_API_HASH" "$CEF_PRIVATE_DIR/libcef.so" || \
   ! grep -aFq "$CEF_API_HASH" "$JRIVER_APPDIR/JRWeb.real"; then
  echo '错误：最终 AppImage 中 JRWeb 与 libcef.so 的 CEF API hash 不一致。' >&2
  exit 1
fi

# CEF 自带的图形辅助库必须保留在私有 runtime；shared/lib 中原有系统 Mesa/GLVND 库保持不动。
for cef_private_lib in libEGL.so libGLESv2.so libvk_swiftshader.so libvulkan.so.1; do
  if [[ -f "$CEF_ROOT/Release/$cef_private_lib" ]] && [[ ! -f "$CEF_PRIVATE_DIR/$cef_private_lib" ]]; then
    echo "错误：JRWeb 私有 CEF 库缺失：$cef_private_lib" >&2
    exit 1
  fi
done

# 插件路径修复必须在最终 AppImage 中同时保留 quick-sharun 的临时 lib hook 和等长映射路径。
for mapped_file in \
  "AppDir/lib/jriver/Media Center ${MC_VER}/mc${MC_VER}" \
  "AppDir/lib/jriver/Media Center ${MC_VER}/libJRTools.so" \
  "AppDir/lib/jriver/Media Center ${MC_VER}/Plugins/libout_Main.so" \
  "$JRIVER_APPDIR/mc${MC_VER}" \
  "$JRIVER_APPDIR/libJRTools.so" \
  "$JRIVER_APPDIR/Plugins/libout_Main.so"; do
  if grep -aqF "$JRIVER_OLD_ROOT" "$mapped_file"; then
    echo "错误：JRiver ELF 仍残留旧安装根目录：$mapped_file" >&2
    exit 1
  fi
  if ! grep -aqF "$JRIVER_MAPPED_ROOT" "$mapped_file"; then
    echo "错误：JRiver ELF 缺少新的临时映射根目录：$mapped_file" >&2
    exit 1
  fi
done

if [[ ! -f "$HARDPATH_HOOK" ]]; then
  echo '错误：最终检查时 quick-sharun 临时 lib 映射 hook 已丢失。' >&2
  exit 1
fi

# 不改变已经验证可启动的 AppRun/pathmap exec 链；防止以后再次引入 /tmp 清理回归。
if ! grep -Fq 'exec "$PATHMAP" "$APPDIR/run-mc.sh" "$@"' AppDir/AppRun; then
  echo '错误：AppRun 已偏离当前验证可启动的 pathmap exec 基线。' >&2
  exit 1
fi

/bin/sh -n AppDir/AppRun
/bin/sh -n AppDir/run-mc.sh
/bin/sh -n "$JRIVER_APPDIR/JRWeb"
/bin/sh -n "$JRIVER_APPDIR/JRWorker"

echo "最终版检查完成，开始生成 ${OUTNAME}"
quick-sharun --make-appimage
