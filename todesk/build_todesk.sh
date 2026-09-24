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
readonly AUR_DIR="$WORKDIR/todesk-bin"
readonly DEB_ROOT="$WORKDIR/deb-root"
readonly DEB_PARTS="$WORKDIR/deb-parts"
readonly DEB_FILE="$WORKDIR/todesk.deb"
readonly SOURCE_ROOT="$DEB_ROOT/opt/todesk"
readonly APP_ROOT="$APPDIR/shared/bin/todesk"
readonly OUTFILE="$DIST/todesk.AppImage"
readonly DOWNLOAD_FILE="$SCRIPT_DIR/../common/download/download_file.sh"

###### 准备 Arch Linux 构建环境 ######

# 安装仓库统一的 Arch AppImage 基础环境。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base

###### 动态取得 AUR 当前版本、官方来源与校验值 ######

rm -rf -- "$APPDIR" "$DIST" "$WORKDIR"
mkdir -p "$DIST" "$WORKDIR"

# AUR 元数据只用于确定当前稳定版本、官方 x86_64 DEB URL 与对应 SHA-256；不固定 Version / Tag / Commit。
for attempt in 1 2 3; do
    rm -rf -- "$AUR_DIR"
    if git -c http.version=HTTP/1.1 clone --depth=1 \
        https://aur.archlinux.org/todesk-bin.git \
        "$AUR_DIR"; then
        break
    fi
    [[ "$attempt" -lt 3 ]] || die "连续 3 次无法读取 AUR todesk-bin 元数据。"
    sleep $((attempt * 2))
done

readonly SRCINFO="$AUR_DIR/.SRCINFO"
[[ -f "$SRCINFO" ]] || die "AUR todesk-bin 缺少 .SRCINFO。"

PACKAGE_VERSION="$(awk -F ' = ' '/^[[:space:]]*pkgver = / {print $2; exit}' "$SRCINFO")"
PACKAGE_REL="$(awk -F ' = ' '/^[[:space:]]*pkgrel = / {print $2; exit}' "$SRCINFO")"
SOURCE_URL="$(awk -F ' = ' '/^[[:space:]]*source_x86_64 = / {print $2; exit}' "$SRCINFO")"
EXPECTED_SHA256="$(awk -F ' = ' '/^[[:space:]]*sha256sums_x86_64 = / {print $2; exit}' "$SRCINFO")"

[[ -n "$PACKAGE_VERSION" ]] || die "无法从 AUR .SRCINFO 解析 ToDesk 版本。"
[[ -n "$PACKAGE_REL" ]] || die "无法从 AUR .SRCINFO 解析 ToDesk pkgrel。"
[[ -n "$SOURCE_URL" ]] || die "无法从 AUR .SRCINFO 解析 x86_64 官方来源。"
[[ -n "$EXPECTED_SHA256" ]] || die "无法从 AUR .SRCINFO 解析 x86_64 SHA-256。"

# .SRCINFO 允许 filename::URL 形式；下载时只使用真实 HTTPS URL。
SOURCE_URL="${SOURCE_URL#*::}"
[[ "$SOURCE_URL" == https://* ]] || die "AUR x86_64 来源不是 HTTPS：$SOURCE_URL"
[[ "$EXPECTED_SHA256" =~ ^[[:xdigit:]]{64}$ ]] || die "AUR x86_64 SHA-256 无效：$EXPECTED_SHA256"

readonly SOFTWARE_VERSION="$PACKAGE_VERSION"
readonly PACKAGE_BUILD_VERSION="$PACKAGE_VERSION-$PACKAGE_REL"

# 按当前 AUR .SRCINFO 安装 ToDesk 声明的运行依赖；去掉版本比较符后交给 Arch 包管理器解析当前仓库版本。
# Fcitx5 GTK3 是本 AppImage 的中文输入补充；IBus 已包含在统一基础环境中。
mapfile -t AUR_DEPENDENCIES < <(
    awk -F ' = ' '/^[[:space:]]*depends(_x86_64)? = / {print $2}' "$SRCINFO" |
        sed -E 's/[<>=].*$//' |
        awk 'NF' |
        sort -u
)
(( ${#AUR_DEPENDENCIES[@]} > 0 )) || die "AUR todesk-bin 没有解析到运行依赖。"
"$SCRIPT_DIR/../common/arch/install_packages.sh" "${AUR_DEPENDENCIES[@]}" fcitx5-gtk

###### 下载并校验 ToDesk 官方 DEB ######

# 优先直接取 AUR 当前指向的 ToDesk 官方文件；公共下载入口会在落盘前强制校验 AUR SHA-256。
if "$DOWNLOAD_FILE" "$SOURCE_URL" "$DEB_FILE" "$EXPECTED_SHA256"; then
    log "已从 ToDesk 官方来源取得并校验 $PACKAGE_BUILD_VERSION。"
else
    # 2026-09-24 的正式 Actions 中，官方 URL 对 CI 返回 29181 字节 text/html，AUR 因 SHA-256 不匹配失败。
    # 这里不跳过校验、不降级版本；仅从 Internet Archive 查找“同一个官方 URL”的历史响应，
    # 并且仍要求内容与当前 AUR 的 SHA-256 完全一致，否则拒绝使用。
    log "ToDesk 官方来源未返回 AUR 校验对应文件，尝试同一官方 URL 的 Internet Archive 快照。"
    rm -f -- "$DEB_FILE"

    SOURCE_URL_ENCODED="$(jq -rn --arg value "$SOURCE_URL" '$value|@uri')"
    [[ -n "$SOURCE_URL_ENCODED" ]] || die "无法编码 ToDesk 官方 URL，不能查询 Internet Archive。"
    CDX_URL="https://web.archive.org/cdx/search/cdx?url=${SOURCE_URL_ENCODED}&output=json&fl=timestamp,original,statuscode,mimetype,digest&filter=statuscode:200&limit=20&sort=reverse"
    CDX_JSON="$WORKDIR/wayback-cdx.json"
    "$DOWNLOAD_FILE" "$CDX_URL" "$CDX_JSON"

    mapfile -t WAYBACK_TIMESTAMPS < <(jq -r '.[1:][]? | .[0] // empty' "$CDX_JSON")
    (( ${#WAYBACK_TIMESTAMPS[@]} > 0 )) || die "Internet Archive 中没有找到当前 ToDesk 官方 URL 的可用快照。"

    ARCHIVE_MATCHED=false
    for timestamp in "${WAYBACK_TIMESTAMPS[@]}"; do
        [[ "$timestamp" =~ ^[0-9]{14}$ ]] || continue
        ARCHIVE_URL="https://web.archive.org/web/${timestamp}id_/${SOURCE_URL}"
        if "$DOWNLOAD_FILE" "$ARCHIVE_URL" "$DEB_FILE" "$EXPECTED_SHA256"; then
            ARCHIVE_MATCHED=true
            log "已从 Internet Archive 取得与 AUR SHA-256 完全一致的 ToDesk 官方 DEB：$timestamp"
            break
        fi
        rm -f -- "$DEB_FILE"
    done

    [[ "$ARCHIVE_MATCHED" == true ]] || die "Internet Archive 快照均未通过当前 AUR SHA-256 校验。"
fi

[[ -s "$DEB_FILE" ]] || die "ToDesk DEB 不存在或为空。"
file "$DEB_FILE" | grep -qi 'Debian binary package' || die "下载内容不是有效的 Debian 软件包。"
printf '%s  %s\n' "$EXPECTED_SHA256" "$DEB_FILE" | sha256sum -c - >/dev/null

###### 解包官方 DEB ######

mkdir -p "$DEB_ROOT" "$DEB_PARTS"
(
    cd "$DEB_PARTS"
    ar x "$DEB_FILE"
)

DATA_ARCHIVE="$(find "$DEB_PARTS" -maxdepth 1 -type f -name 'data.tar.*' -print -quit)"
[[ -f "$DATA_ARCHIVE" ]] || die "ToDesk DEB 中没有 data.tar.*。"
tar -xf "$DATA_ARCHIVE" -C "$DEB_ROOT"

###### 核对上游包布局 ######

[[ -d "$SOURCE_ROOT" ]] || die "官方 DEB 中未找到 ToDesk 目录：$SOURCE_ROOT"

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

# ToDesk 四个入口必须在同一次 quick-sharun 调用中处理。
# quick-sharun 生成的 AppRun 会根据 AppImage/软链接文件名自动选择同名入口。
LD_LIBRARY_PATH="$APP_ROOT/bin${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
quick-sharun \
    "$APP_ROOT/bin/ToDesk" \
    "$APP_ROOT/bin/ToDesk_Service" \
    "$APP_ROOT/bin/ToDesk_Session" \
    "$APP_ROOT/bin/CrashReport" \
    /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so \
    /usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so

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
TODESK_VERSION_FILE="$TODESK_STATE_ROOT/.package-version"

mkdir -p "$TODESK_STATE_ROOT" "$TODESK_LOG_ROOT"

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

mkdir -p "$TODESK_RUNTIME_ROOT/config" "$TODESK_LOG_ROOT"
chmod -R u+rwX "$TODESK_RUNTIME_ROOT/config" "$TODESK_LOG_ROOT" 2>/dev/null || :

# 对显式程序入口优先映射回 sharun wrapper，保证 ToDesk 自行拉起 Session/CrashReport 时仍使用包内运行库。
# 其他 /opt/todesk 资源映射到当前用户的可写运行副本；服务日志也不写宿主 /var/log。
export PATH_MAPPING="/opt/todesk/bin/ToDesk:${APPDIR}/bin/ToDesk,/opt/todesk/bin/ToDesk_Service:${APPDIR}/bin/ToDesk_Service,/opt/todesk/bin/ToDesk_Session:${APPDIR}/bin/ToDesk_Session,/opt/todesk/bin/CrashReport:${APPDIR}/bin/CrashReport,/opt/todesk/config:${TODESK_RUNTIME_ROOT}/config,/opt/todesk/res:${TODESK_RUNTIME_ROOT}/res,/opt/todesk/bin:${TODESK_RUNTIME_ROOT}/bin,/opt/todesk:${TODESK_RUNTIME_ROOT},/var/log/todesk:${TODESK_LOG_ROOT}"

# ToDesk 的官方程序与私有编码库位于同一 bin 目录；固定工作目录保持官方相对路径语义。
export SHARUN_WORKING_DIR="$TODESK_RUNTIME_ROOT/bin"
export SHARUN_EXTRA_LIBRARY_PATH="$TODESK_RUNTIME_ROOT/bin${SHARUN_EXTRA_LIBRARY_PATH:+:$SHARUN_EXTRA_LIBRARY_PATH}"

unset TODESK_SOURCE_ROOT TODESK_PACKAGE_VERSION TODESK_STATE_ROOT TODESK_RUNTIME_ROOT
unset TODESK_LOG_ROOT TODESK_VERSION_FILE TODESK_TEMP_ROOT
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
