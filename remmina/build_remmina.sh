#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v docker >/dev/null 2>&1; then
  if command -v yay >/dev/null 2>&1; then
    yay -S --needed --noconfirm docker
  else
    echo "错误：未找到 docker。" >&2
    exit 1
  fi
fi

if ! docker info >/dev/null 2>&1; then
  echo "错误：Docker daemon 不可用。" >&2
  exit 1
fi

if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
  DOCKER_MOUNT=(--volumes-from "$HOSTNAME")
  DOCKER_WORKDIR="$PWD"
else
  DOCKER_MOUNT=(-v "$PWD:/work")
  DOCKER_WORKDIR="/work"
fi

docker run --rm -i \
  "${DOCKER_MOUNT[@]}" \
  -w "$DOCKER_WORKDIR" \
  -e HOST_UID="$(id -u)" \
  -e HOST_GID="$(id -g)" \
  ubuntu:24.04 \
  bash -s <<'INNER_EOF'
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export APPIMAGE_EXTRACT_AND_RUN=1
export ARCH=x86_64
export DEPLOY_GTK_VERSION=3
export GSTREAMER_INCLUDE_BAD_PLUGINS=1

ROOT="$PWD"
APPDIR="$ROOT/AppDir"
OUTDIR="$ROOT/dist"
OUTFILE="$OUTDIR/remmina.AppImage"

# Ubuntu 24.04 当前更新/安全源已提供 Remmina 1.4.43 与 FreeRDP 3；直接使用官方仓库。
# 官方包主程序已包含 libssh + VTE，Local Terminal/SSH 属于 Remmina 内建协议，不需要独立插件包。
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  adwaita-icon-theme \
  bash \
  binutils \
  bubblewrap \
  coreutils \
  curl \
  dbus-x11 \
  desktop-file-utils \
  dpkg-dev \
  file \
  findutils \
  gnome-themes-extra \
  language-pack-gnome-zh-hans-base \
  gstreamer1.0-gl \
  gstreamer1.0-libav \
  gstreamer1.0-plugins-bad \
  gstreamer1.0-plugins-base \
  gstreamer1.0-plugins-good \
  gstreamer1.0-x \
  libgdk-pixbuf2.0-bin \
  libgdk-pixbuf-2.0-dev \
  libgirepository1.0-dev \
  libglib2.0-bin \
  libglib2.0-dev \
  libgtk-3-bin \
  libgtk-3-dev \
  libpango1.0-dev \
  librsvg2-dev \
  openssl \
  patchelf \
  pkg-config \
  python3 \
  remmina \
  remmina-common \
  shared-mime-info \
  squashfs-tools \
  xauth \
  xdg-dbus-proxy \
  xvfb

install_if_available() {
  local pkg
  for pkg in "$@"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
      apt-get install -y --no-install-recommends "$pkg"
    fi
  done
}

install_if_available \
  libwebkit2gtk-4.1-dev \
  remmina-plugin-rdp \
  remmina-plugin-vnc \
  remmina-plugin-exec \
  remmina-plugin-secret \
  remmina-plugin-www \
  remmina-plugin-spice

# 本 AppImage 的 RDP 基线固定为 FreeRDP 3；不再回退到 FreeRDP 2，避免 Remmina RDP 插件与运行库混用。
if ! apt-cache show freerdp3-x11 >/dev/null 2>&1; then
  echo "错误：Ubuntu 24.04 软件源中未找到 freerdp3-x11。" >&2
  exit 1
fi
apt-get install -y --no-install-recommends freerdp3-x11

RDP_PLUGIN="$(find /usr/lib -type f -name 'remmina-plugin-rdp.so' -print -quit)"
VNC_PLUGIN="$(find /usr/lib -type f -name 'remmina-plugin-vnc.so' -print -quit)"
EXEC_PLUGIN="$(find /usr/lib -type f -name 'remmina-plugin-exec.so' -print -quit)"
WWW_PLUGIN="$(find /usr/lib -type f -name 'remmina-plugin-www.so' -print -quit)"
DESKTOP_FILE="$(find /usr/share/applications -type f -name 'org.remmina.Remmina.desktop' -print -quit)"
ICON_FILE="$(find /usr/share/icons/hicolor -type f \
  \( -name 'org.remmina.Remmina.png' -o -name 'org.remmina.Remmina.svg' \) \
  -print | sort -r | head -n 1)"
OPENSSL_LEGACY_MODULE="$(find /usr/lib -type f -path '*/ossl-modules/legacy.so' -print -quit)"
OPENSSL_LIBCRYPTO="$(find /usr/lib/x86_64-linux-gnu -maxdepth 1 -type f -name 'libcrypto.so.3' -print -quit)"
OPENSSL_LIBSSL="$(find /usr/lib/x86_64-linux-gnu -maxdepth 1 -type f -name 'libssl.so.3' -print -quit)"
ZH_CN_MO=""
for locale_root in /usr/share/locale /usr/share/locale-langpack; do
  if [[ -f "$locale_root/zh_CN/LC_MESSAGES/remmina.mo" ]]; then
    ZH_CN_MO="$locale_root/zh_CN/LC_MESSAGES/remmina.mo"
    break
  fi
done

for required in "$RDP_PLUGIN" "$VNC_PLUGIN" "$EXEC_PLUGIN" "$WWW_PLUGIN" "$DESKTOP_FILE" "$ICON_FILE"; do
  if [[ -z "$required" ]]; then
    echo "错误：Remmina 必需文件或插件缺失。" >&2
    exit 1
  fi
done

for required in "$OPENSSL_LEGACY_MODULE" "$OPENSSL_LIBCRYPTO" "$OPENSSL_LIBSSL"; do
  if [[ -z "$required" ]]; then
    echo "错误：缺少 OpenSSL 3 legacy provider 或配套运行库，FreeRDP 的 NTLM/MD4 无法工作。" >&2
    exit 1
  fi
done

if [[ -z "$ZH_CN_MO" ]]; then
  echo "错误：缺少 Remmina 简体中文翻译文件。" >&2
  exit 1
fi

# Remmina 1.4.36 起提供 FreeRDP 3 auth filter；同时确认 RDP 插件实际链接 FreeRDP 3。
REMMINA_VERSION="$(dpkg-query -W -f='${Version}' remmina)"
if ! dpkg --compare-versions "$REMMINA_VERSION" ge '1.4.36'; then
  echo "错误：Remmina 版本过旧（$REMMINA_VERSION），必须 >= 1.4.36。" >&2
  exit 1
fi
if ! grep -Fq 'rdp_auth_filter' < <(strings "$RDP_PLUGIN"); then
  echo "错误：Remmina RDP 插件缺少 FreeRDP 3 auth-pkg-list 支持。" >&2
  exit 1
fi
if ! grep -Eq 'Shared library: \[libfreerdp3\.so' < <(readelf -d "$RDP_PLUGIN"); then
  echo "错误：Remmina RDP 插件没有链接 FreeRDP 3。" >&2
  exit 1
fi
if ! command -v xfreerdp3 >/dev/null 2>&1; then
  echo "错误：未安装 xfreerdp3。" >&2
  exit 1
fi

# Local Terminal/SSH 是 Remmina 主程序内建协议；只有同时编入 libssh 与 VTE 时相关代码才会存在。
if ! grep -Fq 'Local Terminal' < <(strings /usr/bin/remmina); then
  echo "错误：Remmina 主程序未包含 Local Terminal。" >&2
  exit 1
fi
if ! grep -Fq 'SSH - Secure Shell' < <(strings /usr/bin/remmina); then
  echo "错误：Remmina 主程序未包含 SSH 协议。" >&2
  exit 1
fi
if ! grep -Eq 'Shared library: \[libssh\.so' < <(readelf -d /usr/bin/remmina); then
  echo "错误：Remmina 主程序未链接 libssh，SSH/Local Terminal 无法注册。" >&2
  exit 1
fi
if ! grep -Eq 'Shared library: \[libvte-2\.91\.so' < <(readelf -d /usr/bin/remmina); then
  echo "错误：Remmina 主程序未链接 VTE，Local Terminal 无法工作。" >&2
  exit 1
fi

# 注意：--full-version 在 GApplication startup 之前执行，只能列出已预加载的外部插件，
# 不能用它判断内建 SSH/Local Terminal 是否注册；这里使用上面的二进制与依赖检查。
echo "Remmina 版本：$REMMINA_VERSION"

DEPLOY_DESKTOP_FILE="/tmp/org.remmina.Remmina.desktop"
cp -a "$DESKTOP_FILE" "$DEPLOY_DESKTOP_FILE"
sed -E -i 's|^Exec=remmina-file-wrapper(.*)$|Exec=remmina\1|' "$DEPLOY_DESKTOP_FILE"

curl -fL --retry 3 \
  https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage \
  -o /tmp/linuxdeploy
curl -fL --retry 3 \
  https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh \
  -o /tmp/linuxdeploy-plugin-gtk.sh
curl -fL --retry 3 \
  https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gstreamer/master/linuxdeploy-plugin-gstreamer.sh \
  -o /tmp/linuxdeploy-plugin-gstreamer.sh
curl -fL --retry 3 \
  https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage \
  -o /tmp/appimagetool
curl -fL --retry 3 \
  https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-x86_64 \
  -o /tmp/runtime-x86_64
chmod +x \
  /tmp/linuxdeploy \
  /tmp/linuxdeploy-plugin-gtk.sh \
  /tmp/linuxdeploy-plugin-gstreamer.sh \
  /tmp/appimagetool \
  /tmp/runtime-x86_64
export PATH="/tmp:$PATH"

rm -rf "$APPDIR"
mkdir -p "$OUTDIR"
rm -f "$OUTFILE"

LINUXDEPLOY_ARGS=(
  --appdir "$APPDIR"
  --executable /usr/bin/remmina
  --desktop-file "$DEPLOY_DESKTOP_FILE"
  --icon-file "$ICON_FILE"
  --plugin gtk
  --plugin gstreamer
)

if [[ -x /usr/bin/bwrap ]]; then
  LINUXDEPLOY_ARGS+=(--executable /usr/bin/bwrap)
fi
if [[ -x /usr/bin/xdg-dbus-proxy ]]; then
  LINUXDEPLOY_ARGS+=(--executable /usr/bin/xdg-dbus-proxy)
fi

while IFS= read -r plugin; do
  LINUXDEPLOY_ARGS+=(--library "$plugin")
done < <(find /usr/lib -type f -path '*/remmina/plugins/*.so' -print | sort)

while IFS= read -r webkit_exec; do
  LINUXDEPLOY_ARGS+=(--executable "$webkit_exec")
done < <(find /usr/lib -type f -path '*/webkit2gtk-4.1/WebKit*Process' -perm /111 -print | sort)
while IFS= read -r webkit_lib; do
  LINUXDEPLOY_ARGS+=(--library "$webkit_lib")
done < <(find /usr/lib -type f -path '*/webkit2gtk-4.1/*.so*' -print | sort)

NO_STRIP=1 /tmp/linuxdeploy "${LINUXDEPLOY_ARGS[@]}"

while IFS= read -r pkg; do
  while IFS= read -r item; do
    if [[ -f "$item" || -L "$item" ]]; then
      cp -a --parents "$item" "$APPDIR"
    fi
  done < <(dpkg -L "$pkg")
done < <(dpkg-query -W -f='${binary:Package}\n' 'remmina*' 2>/dev/null | sort -u)

# 明确补入简体中文翻译，避免 linuxdeploy 或包拆分变化导致界面回退为英文。
mkdir -p "$APPDIR/usr/share/locale/zh_CN/LC_MESSAGES"
cp -a "$ZH_CN_MO" "$APPDIR/usr/share/locale/zh_CN/LC_MESSAGES/remmina.mo"

while IFS= read -r webkit_dir; do
  webkit_parent="$(dirname "${webkit_dir#/}")"
  mkdir -p "$APPDIR/$webkit_parent"
  cp -a "$webkit_dir" "$APPDIR/$webkit_parent/"
done < <(find /usr/lib -type d -path '*/webkit2gtk-4.1' -print | sort -u)

while IFS= read -r freerdp_dir; do
  mkdir -p "$APPDIR/$(dirname "${freerdp_dir#/}")"
  cp -a "$freerdp_dir" "$APPDIR/$(dirname "${freerdp_dir#/}")/"
done < <(find /usr/lib -maxdepth 4 -type d -name 'freerdp[0-9]*' -print | sort -u)

# FreeRDP 3 在 OpenSSL 3 上会主动加载 legacy provider 以提供 NTLM 所需的 MD4/RC4。
# linuxdeploy 不会自动收集 provider 模块，因此把与 libcrypto/libssl 完全同源的运行库和 legacy.so 一起打包。
OPENSSL_APP_LIBDIR="$APPDIR/usr/lib/x86_64-linux-gnu"
mkdir -p "$OPENSSL_APP_LIBDIR/ossl-modules"
cp -aL "$OPENSSL_LIBCRYPTO" "$OPENSSL_APP_LIBDIR/libcrypto.so.3"
cp -aL "$OPENSSL_LIBSSL" "$OPENSSL_APP_LIBDIR/libssl.so.3"
cp -aL "$OPENSSL_LEGACY_MODULE" "$OPENSSL_APP_LIBDIR/ossl-modules/legacy.so"

# 在构建阶段直接使用 AppDir 内的 libcrypto 和 provider 验证 MD4，避免生成后才发现 NLA/NTLM 无法登录。
OPENSSL_MODULES="$OPENSSL_APP_LIBDIR/ossl-modules" \
LD_LIBRARY_PATH="$OPENSSL_APP_LIBDIR:$APPDIR/usr/lib" \
openssl dgst -provider legacy -provider default -md4 /dev/null >/dev/null

# Remmina 的插件路径在 Ubuntu 二进制中是绝对路径。把插件复制到 AppDir 根目录，
# 再将编译路径改为 /proc/self/cwd/plugins；AppRun 启动前会进入 AppDir。
PLUGIN_SOURCE_DIR="$(dirname "$RDP_PLUGIN")"
mkdir -p "$APPDIR/plugins"
cp -a "$PLUGIN_SOURCE_DIR"/. "$APPDIR/plugins/"
python3 - "$APPDIR/usr/bin/remmina" "$PLUGIN_SOURCE_DIR" <<'PY'
from pathlib import Path
import sys

binary = Path(sys.argv[1])
old = sys.argv[2].encode() + b"\0"
new = b"/proc/self/cwd/plugins\0"
data = binary.read_bytes()

if new in data:
    pass
elif data.count(old) == 1:
    if len(new) > len(old):
        raise SystemExit("runtime plugin path is longer than compiled plugin path")
    data = data.replace(old, new + b"\0" * (len(old) - len(new)), 1)
    binary.write_bytes(data)
else:
    raise SystemExit(f"cannot find unique compiled plugin path: {sys.argv[2]}")
PY

# Remmina 主程序和内建/外部插件会通过 REMMINA_RUNTIME_LOCALEDIR 绑定编译时的 /usr/share/locale。
# AppRun 会先进入 AppDir，因此将它改为等长以内的相对路径 usr/share/locale，确保使用包内中文翻译。
python3 - "$APPDIR/usr/bin/remmina" "$APPDIR/plugins" <<'PY'
from pathlib import Path
import sys

targets = [Path(sys.argv[1]), *sorted(Path(sys.argv[2]).glob("*.so"))]
old = b"/usr/share/locale\0"
new = b"usr/share/locale\0"

patched = 0
for target in targets:
    data = target.read_bytes()
    count = data.count(old)
    if count:
        data = data.replace(old, new + b"\0" * (len(old) - len(new)))
        target.write_bytes(data)
        patched += count

if patched == 0:
    raise SystemExit("cannot find compiled Remmina locale path")
PY

# 补入 GTK3 Adwaita 主题与图标。运行时优先使用宿主主题，包内资源作为回退。
mkdir -p "$APPDIR/usr/share/themes" "$APPDIR/usr/share/icons"
for theme in Adwaita Adwaita-dark HighContrast; do
  if [[ -d "/usr/share/themes/$theme" ]]; then
    rm -rf "$APPDIR/usr/share/themes/$theme"
    cp -a "/usr/share/themes/$theme" "$APPDIR/usr/share/themes/"
  fi
done
if [[ -d /usr/share/icons/Adwaita ]]; then
  rm -rf "$APPDIR/usr/share/icons/Adwaita"
  cp -a /usr/share/icons/Adwaita "$APPDIR/usr/share/icons/"
fi

if [[ ! -d "$APPDIR/usr/share/themes/Adwaita/gtk-3.0" ]]; then
  echo "错误：未打包 Adwaita GTK3 主题。" >&2
  exit 1
fi

# 删除构建容器中的图形驱动栈，运行时完全使用宿主 GPU 驱动。
find "$APPDIR" \( -type f -o -type l \) -print | while IFS= read -r item; do
  case "$(basename "$item")" in
    libEGL.so*|libGL.so*|libGLX.so*|libGLdispatch.so*|libOpenGL.so*|\
    libgbm.so*|libdrm.so*|libvulkan.so*)
      rm -f "$item"
      ;;
  esac
done
find "$APPDIR" -type d \
  \( -name dri -o -path '*/glvnd/egl_vendor.d' -o -path '*/vulkan/icd.d' \) \
  -prune -exec rm -rf {} + 2>/dev/null || true

rm -f \
  "$APPDIR/usr/bin/WebKitWebProcess" \
  "$APPDIR/usr/bin/WebKitNetworkProcess" \
  "$APPDIR/usr/bin/WebKitGPUProcess"

# Remmina Local Terminal 调用 $SHELL 时不会指定工作目录，会继承 Remmina 进程当前目录。
# Remmina 又必须进入 AppDir 才能加载 /proc/self/cwd/plugins，因此使用 shell wrapper 恢复 AppImage 启动目录。
cat > "$APPDIR/usr/bin/remmina-local-shell" <<'LOCAL_SHELL_EOF'
#!/bin/sh
set -e

host_shell="${REMMINA_HOST_SHELL:-/bin/sh}"
target_dir="${REMMINA_LAUNCH_CWD:-${HOME:-/}}"

if [ ! -d "$target_dir" ]; then
  target_dir="${HOME:-/}"
fi

cd "$target_dir"
export SHELL="$host_shell"
exec "$host_shell" "$@"
LOCAL_SHELL_EOF
chmod +x "$APPDIR/usr/bin/remmina-local-shell"

cat > "$APPDIR/AppRun" <<'APPRUN_EOF'
#!/usr/bin/env bash
set -e

APPDIR="$(dirname "$(readlink -f "$0")")"
export APPDIR

# 保存 AppImage 启动时的当前目录；Local Terminal 通过 wrapper 回到这里。
export REMMINA_LAUNCH_CWD="$PWD"

# 保存宿主原始 shell，随后把 SHELL 指向 Local Terminal wrapper。
if [[ -n "${SHELL:-}" && -x "$SHELL" ]]; then
  export REMMINA_HOST_SHELL="$SHELL"
elif [[ -x /bin/bash ]]; then
  export REMMINA_HOST_SHELL=/bin/bash
else
  export REMMINA_HOST_SHELL=/bin/sh
fi
export SHELL="$APPDIR/usr/bin/remmina-local-shell"

for hook in "$APPDIR"/apprun-hooks/*.sh; do
  [[ -f "$hook" ]] && . "$hook"
done

# linuxdeploy GTK hook 会强制 Adwaita:light；取消强制值，让应用跟随宿主主题。
unset GTK_DATA_PREFIX
unset GTK_THEME
unset APPIMAGE_GTK_THEME

LIBDIR="$APPDIR/usr/lib/x86_64-linux-gnu"
export PATH="$APPDIR/usr/bin:${PATH:-/usr/bin:/bin}"
export LD_LIBRARY_PATH="$LIBDIR:$APPDIR/usr/lib:${LD_LIBRARY_PATH:-}"
export XDG_DATA_DIRS="$APPDIR/usr/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export GSETTINGS_SCHEMA_DIR="$APPDIR/usr/share/glib-2.0/schemas"

# 默认使用 AppImage 内的简体中文翻译，不修改宿主系统 locale。
export LANGUAGE="zh_CN:zh"

# 固定使用 AppImage 内与 libcrypto.so.3 配套的 OpenSSL provider，保证 FreeRDP 能加载 legacy MD4/RC4。
export OPENSSL_MODULES="$LIBDIR/ossl-modules"

if [[ -d "$LIBDIR/gio/modules" ]]; then
  export GIO_MODULE_DIR="$LIBDIR/gio/modules"
fi
if [[ -d "$LIBDIR/girepository-1.0" ]]; then
  export GI_TYPELIB_PATH="$LIBDIR/girepository-1.0:${GI_TYPELIB_PATH:-}"
fi

WEBKIT_DIR="$(find "$APPDIR/usr/lib" -type d -path '*/webkit2gtk-4.1' -print -quit)"
if [[ -n "$WEBKIT_DIR" ]]; then
  export WEBKIT_EXEC_PATH="$WEBKIT_DIR"
fi

FREERDP_DIR="$(find "$APPDIR/usr/lib" -type d -name 'freerdp[0-9]*' -print -quit)"
if [[ -n "$FREERDP_DIR" ]]; then
  export FREERDP_PLUGIN_PATH="$FREERDP_DIR"
fi

export WEBKIT_DISABLE_DMABUF_RENDERER=1
export GDK_GL=disable

unset LIBGL_DRIVERS_PATH
unset LIBVA_DRIVERS_PATH
unset VDPAU_DRIVER_PATH
unset __EGL_VENDOR_LIBRARY_DIRS
unset __EGL_VENDOR_LIBRARY_FILENAMES
unset VK_DRIVER_FILES
unset VK_ICD_FILENAMES

cd "$APPDIR"
exec "$APPDIR/usr/bin/remmina" "$@"
APPRUN_EOF
chmod +x "$APPDIR/AppRun"

for plugin in rdp vnc exec www; do
  test -f "$APPDIR/plugins/remmina-plugin-$plugin.so"
done
grep -Fx '/proc/self/cwd/plugins' < <(strings "$APPDIR/usr/bin/remmina") >/dev/null
grep -Fq 'rdp_auth_filter' < <(strings "$APPDIR/plugins/remmina-plugin-rdp.so")
grep -Eq 'Shared library: \[libfreerdp3\.so' < <(readelf -d "$APPDIR/plugins/remmina-plugin-rdp.so")
grep -Fq 'Local Terminal' < <(strings "$APPDIR/usr/bin/remmina")
grep -Fq 'SSH - Secure Shell' < <(strings "$APPDIR/usr/bin/remmina")
grep -Eq 'Shared library: \[libssh\.so' < <(readelf -d "$APPDIR/usr/bin/remmina")
grep -Eq 'Shared library: \[libvte-2\.91\.so' < <(readelf -d "$APPDIR/usr/bin/remmina")
grep -Fq 'usr/share/locale' < <(strings "$APPDIR/usr/bin/remmina")
if grep -Fq '/usr/share/locale' < <(strings "$APPDIR/usr/bin/remmina"); then
  echo "错误：Remmina 主程序仍残留宿主绝对 locale 路径。" >&2
  exit 1
fi
test -f "$APPDIR/usr/share/locale/zh_CN/LC_MESSAGES/remmina.mo"
grep -Fq 'export LANGUAGE="zh_CN:zh"' "$APPDIR/AppRun"
test -x "$APPDIR/usr/bin/remmina-local-shell"
grep -Fq 'export REMMINA_LAUNCH_CWD="$PWD"' "$APPDIR/AppRun"
grep -Fq 'export SHELL="$APPDIR/usr/bin/remmina-local-shell"' "$APPDIR/AppRun"
test -f "$APPDIR/usr/lib/x86_64-linux-gnu/libcrypto.so.3"
test -f "$APPDIR/usr/lib/x86_64-linux-gnu/libssl.so.3"
test -f "$APPDIR/usr/lib/x86_64-linux-gnu/ossl-modules/legacy.so"
grep -Fq 'export OPENSSL_MODULES="$LIBDIR/ossl-modules"' "$APPDIR/AppRun"
test -d "$APPDIR/usr/share/themes/Adwaita/gtk-3.0"
test -d "$(find "$APPDIR/usr/lib" -type d -path '*/webkit2gtk-4.1' -print -quit)"

# 直接验证 Local Terminal wrapper 会回到启动目录，并恢复宿主 SHELL。
LOCAL_SHELL_TEST_DIR="/tmp/remmina-local-shell-cwd-test"
mkdir -p "$LOCAL_SHELL_TEST_DIR"
LOCAL_SHELL_TEST_OUTPUT="$(
  REMMINA_LAUNCH_CWD="$LOCAL_SHELL_TEST_DIR" \
  REMMINA_HOST_SHELL=/bin/sh \
  "$APPDIR/usr/bin/remmina-local-shell" -c 'printf "%s\n%s\n" "$PWD" "$SHELL"'
)"
LOCAL_SHELL_TEST_EXPECTED="$(printf '%s\n%s' "$LOCAL_SHELL_TEST_DIR" /bin/sh)"
if [[ "$LOCAL_SHELL_TEST_OUTPUT" != "$LOCAL_SHELL_TEST_EXPECTED" ]]; then
  echo "错误：Local Terminal wrapper 未正确恢复启动目录或宿主 SHELL。" >&2
  exit 1
fi
rmdir "$LOCAL_SHELL_TEST_DIR"

/tmp/appimagetool -n \
  --runtime-file /tmp/runtime-x86_64 \
  "$APPDIR" \
  "$OUTFILE"
chmod +x "$OUTFILE"

# --full-version 仅验证外部插件；SSH/Local Terminal 已在上面通过主程序编译内容与依赖静态检查。
VERSION_LOG="/tmp/remmina-full-version.txt"
APPIMAGE_EXTRACT_AND_RUN=1 xvfb-run -a "$OUTFILE" --full-version 2>&1 | tee "$VERSION_LOG"
grep -Eq '^[[:space:]]*RDP[[:space:]]+Protocol' "$VERSION_LOG"
grep -Eq '^[[:space:]]*VNC[[:space:]]+Protocol' "$VERSION_LOG"
grep -Eq '^[[:space:]]*EXEC[[:space:]]+Protocol' "$VERSION_LOG"
grep -Eq '^[[:space:]]*WWW[[:space:]]+Protocol' "$VERSION_LOG"

chown "$HOST_UID:$HOST_GID" "$OUTFILE" 2>/dev/null || true
echo "已生成并验证：$OUTFILE"
INNER_EOF