#!/usr/bin/env bash
# ToDesk AppImage：从 AUR todesk-bin 元数据解析当前稳定版本与校验值，再用 quick-sharun 封装为单一多入口 AppImage。
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log() {
    printf '[ToDesk] %s\n' "$*"
}

die() {
    printf '错误：%s\n' "$*" >&2
    exit 1
}

readonly ARCH="$(uname -m)"
[[ "$ARCH" == "x86_64" ]] || die "当前仅支持 x86_64，检测到：$ARCH"

readonly APPDIR="$SCRIPT_DIR/AppDir"
readonly DIST="$SCRIPT_DIR/dist"
readonly WORKDIR="$SCRIPT_DIR/.build"
readonly AUR_METADATA="$WORKDIR/aur-source.env"
readonly AUR_DEPENDENCIES_FILE="$WORKDIR/aur-dependencies.txt"
readonly DEB_ROOT="$WORKDIR/deb-root"
readonly DEB_FILE="$WORKDIR/todesk.deb"
readonly SOURCE_ROOT="$DEB_ROOT/opt/todesk"
readonly APP_ROOT="$APPDIR/shared/bin/todesk"
readonly OUTFILE="$DIST/todesk.AppImage"
readonly AUR_RESOLVER="$SCRIPT_DIR/../common/aur/resolve_deb_source.sh"
readonly VERIFIED_DOWNLOAD="$SCRIPT_DIR/../common/download/download_verified_with_wayback.sh"

###### 准备 Arch Linux 构建环境 ######

# 安装仓库统一的 Arch AppImage 基础环境。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base

###### 动态取得 AUR 当前版本、官方来源与校验值 ######

rm -rf -- "$APPDIR" "$DIST" "$WORKDIR"
mkdir -p "$DIST" "$WORKDIR"

# AUR 元数据只用于确定当前稳定版本、官方 x86_64 DEB URL、对应 SHA-256 和运行依赖。
# 公共入口负责浅克隆、解析与校验；此处只加载其已规范化的结果，不固定 Version / Tag / Commit。
"$AUR_RESOLVER" todesk-bin "$ARCH" "$WORKDIR" "$AUR_METADATA" "$AUR_DEPENDENCIES_FILE"
# 元数据文件由上面的公共入口用 Bash %q 安全生成。
# shellcheck disable=SC1090
source "$AUR_METADATA"

readonly SOFTWARE_VERSION="$PACKAGE_VERSION"
readonly PACKAGE_BUILD_VERSION="$PACKAGE_VERSION-$PACKAGE_REL"

# 按当前 AUR .SRCINFO 安装声明的运行依赖；公共入口已去掉版本比较符并排序。
# Fcitx5 GTK3 是本 AppImage 的中文输入补充；IBus 已包含在统一基础环境中。
mapfile -t AUR_DEPENDENCIES < "$AUR_DEPENDENCIES_FILE"

# AUR 当前只声明 gtk3 / libappindicator-gtk3 / noto-fonts-cjk，但 ToDesk 4.9.6.0 的主 ELF 还直接需要一组 XCB helper ABI。
# 2026-09-24 Actions 已实际报缺 libxcb-util.so.1 / libxcb-keysyms.so.1 / libxcb-icccm.so.4。
# 同时把 Qt/XCB 同族的 image / render-util / cursor 一并安装，避免只补前三个后再次因同一依赖族中断；这些都是 Arch 官方 Extra 包。
# 公共 DEB 解包入口需要 dpkg-deb；ToDesk 自身会调用 pulseaudio 命令启动音频服务。
"$SCRIPT_DIR/../common/arch/install_packages.sh" \
    "${AUR_DEPENDENCIES[@]}" \
    fcitx5-gtk \
    dpkg \
    pulseaudio \
    xcb-util \
    xcb-util-keysyms \
    xcb-util-wm \
    xcb-util-image \
    xcb-util-renderutil \
    xcb-util-cursor

###### 下载并校验 ToDesk 官方 DEB ######

# 公共入口先尝试 AUR 当前官方 URL；失败时只接受同一 URL 且通过原 SHA-256 的归档快照。
"$VERIFIED_DOWNLOAD" "$SOURCE_URL" "$DEB_FILE" "$EXPECTED_SHA256" --deb
log "已取得并校验 ToDesk $PACKAGE_BUILD_VERSION 官方 DEB。"

###### 解包官方 DEB ######

"$SCRIPT_DIR/../common/archive/extract_archive.sh" "$DEB_FILE" "$DEB_ROOT"

###### 核对上游包布局 ######

[[ -d "$SOURCE_ROOT" ]] || die "官方 DEB 中未找到 ToDesk 目录：$SOURCE_ROOT"

# 当前 AUR PKGBUILD 启用 emptydirs，并在 package() 中显式创建 /opt/todesk/config。
# 官方 DEB 本身不包含这个空目录；直接解包时按 AUR 的实际安装布局补回。
mkdir -p "$SOURCE_ROOT/config"

for binary in ToDesk ToDesk_Service ToDesk_Session CrashReport; do
    [[ -x "$SOURCE_ROOT/bin/$binary" ]] || die "缺少 ToDesk 运行组件：$SOURCE_ROOT/bin/$binary"
done

[[ -d "$SOURCE_ROOT/res" ]] || die "缺少 ToDesk 资源目录：$SOURCE_ROOT/res"
[[ -d "$SOURCE_ROOT/config" ]] || die "缺少 ToDesk 配置目录：$SOURCE_ROOT/config"

DESKTOP_SOURCE="$DEB_ROOT/usr/share/applications/todesk.desktop"
[[ -f "$DESKTOP_SOURCE" ]] || die "官方 DEB 中缺少 ToDesk desktop 文件。"
[[ -f /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so ]] || die "缺少 GTK3 IBus 输入模块。"
[[ -f /usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so ]] || die "缺少 GTK3 Fcitx5 输入模块。"

ICON="$(
    find "$DEB_ROOT/usr/share/icons" -type f \
        \( -iname 'todesk.png' -o -iname 'todesk.svg' \) -print 2>/dev/null |
        sort -V |
        tail -n 1
)"
[[ -f "$ICON" ]] || die "官方 DEB 中未找到 ToDesk 图标。"

###### 准备 AppDir ######

mkdir -p "$APP_ROOT"

# ToDesk 是 /opt 布局；完整保留官方应用目录，避免拆散 bin、res、config 和私有编码库。
cp -a "$SOURCE_ROOT/." "$APP_ROOT/"

# 使用官方 desktop 作为元数据，只把启动命令改成 AppImage 内实际主入口。
DESKTOP="$WORKDIR/todesk.desktop"
cp -a "$DESKTOP_SOURCE" "$DESKTOP"
sed -i -E 's|^Exec=[^[:space:]]+|Exec=ToDesk|' "$DESKTOP"
sed -i -E 's|^TryExec=.*|TryExec=ToDesk|' "$DESKTOP"

export ARCH
export APPDIR
export ICON
export DESKTOP
export OUTPATH="$DIST"
export OUTNAME="todesk.AppImage"

# AUR 明确使用 !strip；保持 ToDesk 闭源二进制和官方私有库原样。
export NO_STRIP=1

# 构建时先登记 /opt/todesk 映射，使 quick-sharun 收入 path-mapping 运行库。
# 最终运行时由 90-todesk-runtime.hook 把该映射改到当前用户的可写运行目录。
export PATH_MAPPING='/opt/todesk:${SHARUN_DIR}/shared/bin/todesk'

###### quick-sharun 依赖收集 ######

# 在 quick-sharun 前一次性检查四个入口的直接动态库，避免只看到第一个 ELF 的缺库信息后反复触发 Actions。
MISSING_SHARED_LIBS="$(
    for binary in ToDesk ToDesk_Service ToDesk_Session CrashReport; do
        LD_LIBRARY_PATH="$APP_ROOT/bin${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
            ldd "$APP_ROOT/bin/$binary" 2>/dev/null |
            awk -v binary="$binary" '/=> not found/ {print binary ": " $1}'
    done | sort -u
)"
if [[ -n "$MISSING_SHARED_LIBS" ]]; then
    printf 'ToDesk 仍缺少直接动态库：\n%s\n' "$MISSING_SHARED_LIBS" >&2
    die "ToDesk 直接动态库依赖不完整，停止 quick-sharun。"
fi

# ToDesk 四个入口必须在同一次 quick-sharun 调用中处理。
# quick-sharun 生成的 AppRun 会根据 AppImage/软链接文件名自动选择同名入口。
# ToDesk 会调用 pulseaudio --start；现有产物有 libpulse，但缺少这个可执行程序。
#
# AUR 已声明 libappindicator-gtk3，但 2026-09-24 成功构建日志没有看到 AppIndicator/
# libdbusmenu 运行库被 quick-sharun 收入；实机随后也没有出现托盘小图标。
# 因此显式把整条 GTK3 AppIndicator 运行链加入同一次依赖收集。
for tray_library in \
    /usr/lib/libappindicator3.so.1 \
    /usr/lib/libdbusmenu-glib.so.4 \
    /usr/lib/libdbusmenu-gtk3.so.4; do
    [[ -e "$tray_library" ]] || die "缺少 ToDesk 托盘运行库：$tray_library"
done

LD_LIBRARY_PATH="$APP_ROOT/bin${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
quick-sharun \
    "$APP_ROOT/bin/ToDesk" \
    "$APP_ROOT/bin/ToDesk_Service" \
    "$APP_ROOT/bin/ToDesk_Session" \
    "$APP_ROOT/bin/CrashReport" \
    /usr/bin/pulseaudio \
    /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so \
    /usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so \
    /usr/lib/libappindicator3.so.1 \
    /usr/lib/libdbusmenu-glib.so.4 \
    /usr/lib/libdbusmenu-gtk3.so.4

###### 中文环境 ######

# 生成 AppImage 自带的简体中文 UTF-8 locale，不依赖宿主是否预先生成该 locale。
mkdir -p "$APPDIR/lib/locale"
localedef --no-archive \
    -i zh_CN \
    -f UTF-8 \
    "$APPDIR/lib/locale/zh_CN.utf8"

cat >> "$APPDIR/.env" <<'EOF_LOCALE'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
EOF_LOCALE

###### 可写运行目录与固定路径映射 ######

# 保存本次实际 AUR 包版本（含 pkgrel），运行时据此只在包版本变化时刷新程序副本，并保留已有 config。
mkdir -p "$APPDIR/share/todesk-appimage"
printf '%s\n' "$PACKAGE_BUILD_VERSION" > "$APPDIR/share/todesk-appimage/package-version"

# ToDesk 官方布局固定使用 /opt/todesk，服务日志还可能写 /var/log/todesk。
# AppImage 本体只读，因此运行时把官方目录复制到当前用户数据目录；
# config 在升级时保留，避免设备配置因替换 AppImage 被无条件重置。
cat > "$APPDIR/bin/90-todesk-runtime.hook" <<'EOF_HOOK'
#!/bin/sh

TODESK_SOURCE_ROOT="$APPDIR/shared/bin/todesk"
TODESK_PACKAGE_VERSION="$(cat "$APPDIR/share/todesk-appimage/package-version")"

if [ -n "${XDG_DATA_HOME:-}" ]; then
    TODESK_STATE_ROOT="$XDG_DATA_HOME/todesk-appimage"
elif [ -n "${HOME:-}" ]; then
    TODESK_STATE_ROOT="$HOME/.local/share/todesk-appimage"
else
    TODESK_STATE_ROOT="/tmp/todesk-appimage-$(id -u)"
fi

TODESK_RUNTIME_ROOT="$TODESK_STATE_ROOT/runtime"
TODESK_LOG_ROOT="$TODESK_STATE_ROOT/logs"
TODESK_ETC_ROOT="$TODESK_STATE_ROOT/etc"
TODESK_VERSION_FILE="$TODESK_STATE_ROOT/.package-version"

mkdir -p "$TODESK_STATE_ROOT" "$TODESK_LOG_ROOT" "$TODESK_ETC_ROOT"

if [ ! -f "$TODESK_VERSION_FILE" ] || [ "$(cat "$TODESK_VERSION_FILE" 2>/dev/null || true)" != "$TODESK_PACKAGE_VERSION" ]; then
    TODESK_TEMP_ROOT="$TODESK_STATE_ROOT/.runtime.$$"
    rm -rf "$TODESK_TEMP_ROOT"
    mkdir -p "$TODESK_TEMP_ROOT"
    cp -a "$TODESK_SOURCE_ROOT/." "$TODESK_TEMP_ROOT/"

    if [ -d "$TODESK_RUNTIME_ROOT/config" ]; then
        rm -rf "$TODESK_TEMP_ROOT/config"
        mkdir -p "$TODESK_TEMP_ROOT/config"
        cp -a "$TODESK_RUNTIME_ROOT/config/." "$TODESK_TEMP_ROOT/config/" 2>/dev/null || :
    fi

    rm -rf "$TODESK_RUNTIME_ROOT"
    mv "$TODESK_TEMP_ROOT" "$TODESK_RUNTIME_ROOT"
    printf '%s\n' "$TODESK_PACKAGE_VERSION" > "$TODESK_VERSION_FILE"
fi

mkdir -p "$TODESK_RUNTIME_ROOT/config" "$TODESK_LOG_ROOT" "$TODESK_ETC_ROOT"
chmod -R u+rwX "$TODESK_RUNTIME_ROOT/config" "$TODESK_LOG_ROOT" "$TODESK_ETC_ROOT" 2>/dev/null || :

# 对显式程序入口优先映射回 sharun wrapper，保证 ToDesk 自行拉起 Session/CrashReport 时仍使用包内运行库。
# 其他 /opt/todesk 资源映射到当前用户的可写运行副本；/etc/todesk 用于持久化 reg.conf，服务日志也不写宿主 /var/log。
export PATH_MAPPING="/opt/todesk/bin/ToDesk:${APPDIR}/bin/ToDesk,/opt/todesk/bin/ToDesk_Service:${APPDIR}/bin/ToDesk_Service,/opt/todesk/bin/ToDesk_Session:${APPDIR}/bin/ToDesk_Session,/opt/todesk/bin/CrashReport:${APPDIR}/bin/CrashReport,/opt/todesk/config:${TODESK_RUNTIME_ROOT}/config,/opt/todesk/res:${TODESK_RUNTIME_ROOT}/res,/opt/todesk/bin:${TODESK_RUNTIME_ROOT}/bin,/opt/todesk:${TODESK_RUNTIME_ROOT},/etc/todesk:${TODESK_ETC_ROOT},/var/log/todesk:${TODESK_LOG_ROOT}"

# ToDesk 的官方程序与私有编码库位于同一 bin 目录；固定工作目录保持官方相对路径语义。
export SHARUN_WORKING_DIR="$TODESK_RUNTIME_ROOT/bin"
export SHARUN_EXTRA_LIBRARY_PATH="$TODESK_RUNTIME_ROOT/bin${SHARUN_EXTRA_LIBRARY_PATH:+:$SHARUN_EXTRA_LIBRARY_PATH}"

unset TODESK_SOURCE_ROOT TODESK_PACKAGE_VERSION TODESK_STATE_ROOT TODESK_RUNTIME_ROOT
unset TODESK_LOG_ROOT TODESK_ETC_ROOT TODESK_VERSION_FILE TODESK_TEMP_ROOT
EOF_HOOK

chmod +x "$APPDIR/bin/90-todesk-runtime.hook"

###### 生成最终 AppImage ######

for binary in ToDesk ToDesk_Service ToDesk_Session CrashReport; do
    [[ -x "$APPDIR/bin/$binary" ]] || die "AppDir 中缺少 ToDesk 入口：$binary"
done

[[ -f "$APPDIR/bin/90-todesk-runtime.hook" ]] || die "缺少 ToDesk 运行时路径映射 hook。"
[[ -f "$APPDIR/share/todesk-appimage/package-version" ]] || die "缺少 ToDesk 包内版本标记。"

quick-sharun --make-appimage

[[ -s "$OUTFILE" ]] || die "没有生成有效的 ToDesk AppImage。"

log "构建完成：$OUTFILE"
sha256sum "$OUTFILE"

# 最终 AppImage 成功生成后输出统一软件版本元数据。
printf '%s\n' "$SOFTWARE_VERSION" > "$DIST/version.txt"
