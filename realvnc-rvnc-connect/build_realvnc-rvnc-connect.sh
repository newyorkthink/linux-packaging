#!/usr/bin/env bash
# RealVNC Connect AppImage 构建脚本
# 已内置 Fcitx5 GTK3 输入支持、默认深色主题，并隔离外部浏览器的 AppImage 环境。
#
# 外层 Arch 容器只负责安装 RealVNC 官方程序；真正的依赖收集和 AppImage 生成
# 在 Ubuntu 22.04 容器中完成，避免 Arch 最新库引入 GLIBC_2.43，导致旧系统无法运行。
# RealVNC Flutter bundle 始终保持官方原始目录和原始 ELF 内容。
#
# 输出：dist/rvncconnect.AppImage
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log() {
    printf '[RealVNC Connect] %s\n' "$*"
}

die() {
    printf '错误：%s\n' "$*" >&2
    exit 1
}

readonly ARCH="$(uname -m)"
[[ "$ARCH" == "x86_64" ]] || die "当前仅支持 x86_64，检测到：$ARCH"

readonly WORK_DIR="$SCRIPT_DIR/.work-realvnc-connect"
readonly INPUT_DIR="$WORK_DIR/input"
readonly OUTDIR="$SCRIPT_DIR/dist"
readonly OUTFILE="$OUTDIR/rvncconnect.AppImage"
readonly PACKAGE_NAME=realvnc-rvnc-connect
readonly REALVNC_SOURCE=/usr/lib/rvncconnect
readonly SYSTEM_DESKTOP=/usr/share/applications/com.realvnc.rvncconnect.desktop

rm -rf "$WORK_DIR"
mkdir -p "$INPUT_DIR" "$OUTDIR"
rm -f "$OUTFILE" "$OUTFILE.zsync"

log "安装 RealVNC Connect 和 Docker CLI"
yay -S --needed --noconfirm \
    curl \
    docker \
    file \
    realvnc-rvnc-connect

command -v docker >/dev/null 2>&1 || die "找不到 docker 命令。"
docker info >/dev/null 2>&1 || die "无法连接 Docker daemon。"
pacman -Q "$PACKAGE_NAME" >/dev/null 2>&1 || die "未安装 $PACKAGE_NAME。"
[[ -x "$REALVNC_SOURCE/rvncconnect" ]] || die "未找到 $REALVNC_SOURCE/rvncconnect。"
[[ -f "$SYSTEM_DESKTOP" ]] || die "未找到 RealVNC desktop 文件。"

PACKAGE_VERSION="$(pacman -Q "$PACKAGE_NAME" | awk '{print $2}')"
log "检测到 RealVNC Connect：$PACKAGE_VERSION"

log "准备官方 Flutter bundle"
cp -a "$REALVNC_SOURCE" "$INPUT_DIR/rvncconnect"

ICON_SOURCE="$(find /usr/share/icons/hicolor -type f \
    \( -name 'com.realvnc.rvncconnect.png' -o -name 'com.realvnc.rvncconnect.svg' \) \
    -print | sort -V | tail -n 1)"
[[ -f "$ICON_SOURCE" ]] || die "未找到 RealVNC Connect 图标。"
ICON_EXT="${ICON_SOURCE##*.}"
cp -a "$ICON_SOURCE" "$INPUT_DIR/com.realvnc.rvncconnect.$ICON_EXT"

cat > "$INPUT_DIR/com.realvnc.rvncconnect.desktop" <<DESKTOP_EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=RealVNC Connect
Comment=Connect to and manage remote computers
Exec=rvncconnect %U
Icon=com.realvnc.rvncconnect
Terminal=false
Categories=Network;RemoteAccess;
StartupNotify=true
X-AppImage-Version=$PACKAGE_VERSION
DESKTOP_EOF

cat > "$WORK_DIR/ubuntu-build.sh" <<'UBUNTU_BUILD_EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
export ARCH=x86_64
export APPIMAGE_EXTRACT_AND_RUN=1
export DEPLOY_GTK_VERSION=3
export NO_STRIP=1

readonly WORK=/work
readonly INPUT="$WORK/input"
readonly APPDIR="$WORK/AppDir"
readonly DIST="$WORK/dist"
readonly VENDOR_SOURCE="$INPUT/rvncconnect"
readonly VENDOR_DEST="$APPDIR/usr/lib/rvncconnect"
readonly DESKTOP_FILE="$INPUT/com.realvnc.rvncconnect.desktop"
readonly MAX_GLIBC=2.35

log() {
    printf '[Ubuntu 22.04] %s\n' "$*"
}

die() {
    printf '错误：%s\n' "$*" >&2
    exit 1
}

log "安装 Ubuntu 22.04 构建、GTK3 和 Fcitx5 依赖"
apt-get update
apt-get install -y --no-install-recommends \
    binutils \
    ca-certificates \
    curl \
    desktop-file-utils \
    fcitx5-frontend-gtk3 \
    file \
    gobject-introspection \
    libasound2-dev \
    libatkmm-1.6-dev \
    libavahi-client-dev \
    libayatana-appindicator3-dev \
    libcairomm-1.0-dev \
    libcups2-dev \
    libcurl4-openssl-dev \
    libdbus-1-dev \
    libepoxy-dev \
    libgdk-pixbuf-2.0-dev \
    libgirepository1.0-dev \
    libglib2.0-dev \
    libglibmm-2.4-dev \
    libgtk-3-dev \
    libgtkmm-3.0-dev \
    libjson-glib-dev \
    liblcms2-dev \
    libnotify-dev \
    libnss3-dev \
    libpango1.0-dev \
    libpangomm-1.4-dev \
    libpulse-dev \
    librsvg2-dev \
    libsecret-1-dev \
    libsqlite3-dev \
    libsystemd-dev \
    libudev-dev \
    libx11-dev \
    libxdamage-dev \
    libxext-dev \
    libxfixes-dev \
    libxi-dev \
    libxkbcommon-dev \
    libxkbcommon-x11-dev \
    libxrandr-dev \
    libxtst-dev \
    patchelf \
    pkg-config \
    squashfs-tools \
    wget \
    zsync

rm -rf "$APPDIR" "$DIST"
mkdir -p "$APPDIR/usr/lib" "$DIST"
cp -a "$VENDOR_SOURCE" "$VENDOR_DEST"

[[ -x "$VENDOR_DEST/rvncconnect" ]] || die "缺少 rvncconnect 主程序。"
[[ -f "$VENDOR_DEST/data/icudtl.dat" ]] || die "缺少 Flutter icudtl.dat。"
[[ -d "$VENDOR_DEST/data/flutter_assets" ]] || die "缺少 Flutter assets。"

AOT_FILE="$(find "$VENDOR_DEST" -type f \
    \( -name 'libapp.so' -o -name 'app.so' \) -print -quit)"
[[ -n "$AOT_FILE" ]] || die "缺少 Flutter AOT 文件 libapp.so。"
head -c 4 "$AOT_FILE" | grep -q $'\x7fELF' || die "Flutter AOT 文件不是有效 ELF。"
desktop-file-validate "$DESKTOP_FILE"

log "下载 linuxdeploy、GTK 插件和原始 appimagetool"
curl -fL --retry 3 --retry-all-errors \
    https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage \
    -o "$WORK/linuxdeploy"
curl -fL --retry 3 --retry-all-errors \
    https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh \
    -o "$WORK/linuxdeploy-plugin-gtk.sh"
curl -fL --retry 3 --retry-all-errors \
    https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage \
    -o "$WORK/appimagetool"
curl -fL --retry 3 --retry-all-errors \
    https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-x86_64 \
    -o "$WORK/runtime-x86_64"
chmod +x \
    "$WORK/linuxdeploy" \
    "$WORK/linuxdeploy-plugin-gtk.sh" \
    "$WORK/appimagetool" \
    "$WORK/runtime-x86_64"
export PATH="$WORK:$PATH"

LINUXDEPLOY_ARGS=(
    --appdir "$APPDIR"
    --plugin gtk
)

# 扫描 RealVNC 的全部可执行文件、Flutter 引擎、AOT 和私有插件。
while IFS= read -r -d '' candidate; do
    file_info="$(file -Lb "$candidate")"
    case "$file_info" in
        *ELF*executable*)
            LINUXDEPLOY_ARGS+=(--executable "$candidate")
            ;;
        *ELF*shared\ object*)
            LINUXDEPLOY_ARGS+=(--library "$candidate")
            ;;
    esac
done < <(find "$VENDOR_SOURCE" -type f -print0 | sort -z)

VENDOR_LIBRARY_PATH="$(find "$VENDOR_SOURCE" -type d -print | sort | paste -sd: -)"
[[ -n "$VENDOR_LIBRARY_PATH" ]] || die "无法生成 RealVNC 私有库搜索路径。"

log "使用 Ubuntu 22.04 库收集运行依赖"
LD_LIBRARY_PATH="$VENDOR_LIBRARY_PATH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
NO_STRIP=1 \
    "$WORK/linuxdeploy" "${LINUXDEPLOY_ARGS[@]}"

# linuxdeploy 会修改扫描目标的 RPATH；重新覆盖官方 bundle，确保 Flutter 资源定位不变。
log "恢复未经修改的 RealVNC Flutter bundle"
rm -rf "$VENDOR_DEST"
cp -a "$VENDOR_SOURCE" "$VENDOR_DEST"

mkdir -p "$APPDIR/usr/bin"
cat > "$APPDIR/usr/bin/rvncconnect" <<'WRAPPER_EOF'
#!/usr/bin/env bash
set -e
APPDIR="$(cd -- "$(dirname -- "$(readlink -f -- "$0")")/../.." && pwd)"
exec "$APPDIR/usr/lib/rvncconnect/rvncconnect" "$@"
WRAPPER_EOF
chmod +x "$APPDIR/usr/bin/rvncconnect"

# RealVNC 打开帮助或登录网页时，清除自身 AppImage/GTK 环境后再调用宿主机 xdg-open。
# 该包装器不绑定具体浏览器，对 Chromium、Thorium、Firefox 及其他默认浏览器均有效。
cat > "$APPDIR/usr/bin/xdg-open" <<'XDG_OPEN_WRAPPER_EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

host_path="${RVNC_HOST_PATH:-/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}"
host_xdg_data_dirs="${RVNC_HOST_XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
host_ld_library_path="${RVNC_HOST_LD_LIBRARY_PATH:-}"
host_xdg_open="$(PATH="$host_path" command -v xdg-open || true)"

if [[ -z "$host_xdg_open" ]]; then
    printf '错误：宿主机 PATH 中找不到 xdg-open。\n' >&2
    exit 127
fi

env_args=(
    -u APPDIR
    -u APPIMAGE
    -u APPIMAGE_GTK_THEME
    -u APPIMAGE_SILENT_INSTALL
    -u ARGV0
    -u OWD
    -u LD_LIBRARY_PATH
    -u LD_PRELOAD
    -u GTK_DATA_PREFIX
    -u GTK_EXE_PREFIX
    -u GTK_PATH
    -u GTK_IM_MODULE_FILE
    -u GTK_THEME
    -u GTK_MODULES
    -u GTK3_MODULES
    -u GDK_BACKEND
    -u GDK_PIXBUF_MODULE_FILE
    -u GDK_PIXBUF_MODULEDIR
    -u GSETTINGS_SCHEMA_DIR
    -u GI_TYPELIB_PATH
    -u GIO_EXTRA_MODULES
    -u PANGO_RC_FILE
    -u PANGO_LIBDIR
    -u PANGO_SYSCONFDIR
    -u PYTHONHOME
    -u PYTHONPATH
    -u QT_PLUGIN_PATH
    -u QML2_IMPORT_PATH
    -u RVNC_HOST_PATH
    -u RVNC_HOST_XDG_DATA_DIRS
    -u RVNC_HOST_LD_LIBRARY_PATH
    PATH="$host_path"
    XDG_DATA_DIRS="$host_xdg_data_dirs"
)

if [[ -n "$host_ld_library_path" ]]; then
    env_args+=(LD_LIBRARY_PATH="$host_ld_library_path")
fi

exec env "${env_args[@]}" "$host_xdg_open" "$@"
XDG_OPEN_WRAPPER_EOF
chmod +x "$APPDIR/usr/bin/xdg-open"
bash -n "$APPDIR/usr/bin/xdg-open"

cat > "$APPDIR/AppRun" <<'APPRUN_EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

APPDIR="$(cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)"
export APPDIR

# 在加入 AppDir 路径和加载 GTK hook 前保存宿主机环境，供 xdg-open 包装器恢复。
export RVNC_HOST_PATH="${PATH:-/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}"
export RVNC_HOST_XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export RVNC_HOST_LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"

# i3wm 等桌面通常没有统一的深色外观门户，默认固定为 GTK 深色主题。
export APPIMAGE_GTK_THEME="${APPIMAGE_GTK_THEME:-Adwaita:dark}"

# 让 Flutter/GTK3 文本框使用宿主机正在运行的 Fcitx5。
export GTK_IM_MODULE="${GTK_IM_MODULE:-fcitx}"
export XMODIFIERS="${XMODIFIERS:-@im=fcitx}"

shopt -s nullglob
for hook in "$APPDIR"/apprun-hooks/*.sh; do
    source "$hook"
done
shopt -u nullglob

VENDOR_DIR="$APPDIR/usr/lib/rvncconnect"
mapfile -t vendor_library_dirs < <(
    find "$VENDOR_DIR" -type f -name '*.so*' -printf '%h\n' 2>/dev/null | sort -u
)

library_paths=(
    "$VENDOR_DIR"
    "${vendor_library_dirs[@]}"
    "$APPDIR/usr/lib"
    "$APPDIR/usr/lib/x86_64-linux-gnu"
)

joined_library_path=""
for library_dir in "${library_paths[@]}"; do
    [[ -d "$library_dir" ]] || continue
    case ":$joined_library_path:" in
        *":$library_dir:"*) continue ;;
    esac
    [[ -z "$joined_library_path" ]] || joined_library_path+=":"
    joined_library_path+="$library_dir"
done
[[ -z "${LD_LIBRARY_PATH:-}" ]] || joined_library_path+=":$LD_LIBRARY_PATH"

export LD_LIBRARY_PATH="$joined_library_path"
export PATH="$APPDIR/usr/bin:$RVNC_HOST_PATH"
export XDG_DATA_DIRS="$APPDIR/usr/share:$RVNC_HOST_XDG_DATA_DIRS"

# 必须直接执行 vendor 主程序，使 Flutter 从同级 data 和 lib 加载资源。
exec "$VENDOR_DIR/rvncconnect" "$@"
APPRUN_EOF
chmod +x "$APPDIR/AppRun"
bash -n "$APPDIR/AppRun"

# 不封装构建机 GPU 驱动和 glibc 本体；运行时使用宿主机对应组件。
find "$APPDIR/usr/lib" \( -type f -o -type l \) -print0 | \
while IFS= read -r -d '' item; do
    case "$(basename "$item")" in
        ld-linux*.so*|libc.so*|libm.so*|libpthread.so*|libdl.so*|librt.so*|\
        libresolv.so*|libnss_*.so*|libEGL.so*|libGL.so*|libGLX.so*|\
        libGLdispatch.so*|libOpenGL.so*|libgbm.so*|libdrm.so*|libvulkan.so*)
            rm -f "$item"
            ;;
    esac
done
find "$APPDIR/usr/lib" -type d \
    \( -name dri -o -path '*/glvnd/egl_vendor.d' -o -path '*/vulkan/icd.d' \) \
    -not -path "$VENDOR_DEST/*" -prune -exec rm -rf {} + 2>/dev/null || true

mkdir -p "$APPDIR/usr/share/applications"
cp -a "$DESKTOP_FILE" "$APPDIR/usr/share/applications/com.realvnc.rvncconnect.desktop"
cp -a "$DESKTOP_FILE" "$APPDIR/com.realvnc.rvncconnect.desktop"

ICON_FILE="$(find "$INPUT" -maxdepth 1 -type f \
    \( -name 'com.realvnc.rvncconnect.png' -o -name 'com.realvnc.rvncconnect.svg' \) \
    -print -quit)"
[[ -f "$ICON_FILE" ]] || die "输入目录缺少应用图标。"
case "$ICON_FILE" in
    *.svg)
        mkdir -p "$APPDIR/usr/share/icons/hicolor/scalable/apps"
        cp -a "$ICON_FILE" "$APPDIR/usr/share/icons/hicolor/scalable/apps/com.realvnc.rvncconnect.svg"
        cp -a "$ICON_FILE" "$APPDIR/com.realvnc.rvncconnect.svg"
        ln -sfn com.realvnc.rvncconnect.svg "$APPDIR/.DirIcon"
        ;;
    *)
        mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"
        cp -a "$ICON_FILE" "$APPDIR/usr/share/icons/hicolor/256x256/apps/com.realvnc.rvncconnect.png"
        cp -a "$ICON_FILE" "$APPDIR/com.realvnc.rvncconnect.png"
        ln -sfn com.realvnc.rvncconnect.png "$APPDIR/.DirIcon"
        ;;
esac

log "验证 AppDir 不依赖高于 GLIBC_$MAX_GLIBC 的符号"
BAD_ABI=""
while IFS= read -r -d '' candidate; do
    file -Lb "$candidate" | grep -q 'ELF' || continue
    while IFS= read -r requirement; do
        version="${requirement#GLIBC_}"
        if dpkg --compare-versions "$version" gt "$MAX_GLIBC"; then
            BAD_ABI+=$'\n'"$candidate -> $requirement"
        fi
    done < <(
        readelf --version-info "$candidate" 2>/dev/null \
            | grep -oE 'GLIBC_[0-9]+(\.[0-9]+)+' \
            | sort -Vu || true
    )
done < <(find "$APPDIR" -type f -print0)
[[ -z "$BAD_ABI" ]] || die "发现超出 Ubuntu 22.04 基线的 GLIBC 依赖：$BAD_ABI"

[[ -x "$VENDOR_DEST/rvncconnect" ]] || die "最终 AppDir 缺少 rvncconnect。"
[[ -f "$VENDOR_DEST/data/icudtl.dat" ]] || die "最终 AppDir 缺少 icudtl.dat。"
[[ -d "$VENDOR_DEST/data/flutter_assets" ]] || die "最终 AppDir 缺少 flutter_assets。"
AOT_FILE="$(find "$VENDOR_DEST" -type f \
    \( -name 'libapp.so' -o -name 'app.so' \) -print -quit)"
[[ -n "$AOT_FILE" ]] || die "最终 AppDir 缺少 libapp.so。"
head -c 4 "$AOT_FILE" | grep -q $'\x7fELF' || die "最终 Flutter AOT 文件无效。"

log "使用原始 appimagetool 生成 AppImage"
APPIMAGE_EXTRACT_AND_RUN=1 "$WORK/appimagetool" -n \
    --runtime-file "$WORK/runtime-x86_64" \
    "$APPDIR" \
    "$DIST/rvncconnect.AppImage"

[[ -s "$DIST/rvncconnect.AppImage" ]] || die "没有生成有效的 AppImage。"
sha256sum "$DIST/rvncconnect.AppImage"
UBUNTU_BUILD_EOF
chmod +x "$WORK_DIR/ubuntu-build.sh"

CONTAINER_ID=""
cleanup() {
    if [[ -n "$CONTAINER_ID" ]]; then
        docker rm -f "$CONTAINER_ID" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

log "启动 Ubuntu 22.04 兼容基线容器"
docker pull ubuntu:22.04
CONTAINER_ID="$(docker create ubuntu:22.04 sleep infinity)"
docker start "$CONTAINER_ID" >/dev/null

docker exec "$CONTAINER_ID" mkdir -p /work/input
docker cp "$INPUT_DIR/." "$CONTAINER_ID:/work/input/"
docker cp "$WORK_DIR/ubuntu-build.sh" "$CONTAINER_ID:/work/ubuntu-build.sh"
docker exec "$CONTAINER_ID" chmod +x /work/ubuntu-build.sh
docker exec "$CONTAINER_ID" /work/ubuntu-build.sh

docker cp "$CONTAINER_ID:/work/dist/rvncconnect.AppImage" "$OUTFILE"
[[ -s "$OUTFILE" ]] || die "没有从 Ubuntu 容器取得有效 AppImage。"

log "构建完成：$OUTFILE"
sha256sum "$OUTFILE"
