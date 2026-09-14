#!/usr/bin/env bash
# Parsec Linux 客户端 AppImage 构建脚本
# 上游程序来自 AUR parsec-bin 所引用的 Parsec 官方 Linux .deb。
# 本脚本仅处理 AppImage 依赖、官方资源路径、解码运行时与中文 locale 兼容。
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log() {
    printf '[Parsec] %s\n' "$*"
}

die() {
    printf '错误：%s\n' "$*" >&2
    exit 1
}

readonly ARCH="$(uname -m)"
[[ "$ARCH" == "x86_64" ]] || die "当前仅支持 x86_64，检测到：$ARCH"

readonly OUTDIR="$SCRIPT_DIR/dist"
readonly OUTFILE="$OUTDIR/parsec.AppImage"
readonly PARSEC_SHARE=/usr/share/parsec
readonly PARSEC_SKEL="$PARSEC_SHARE/skel"

###### 清理旧构建目录 ######

rm -rf "$SCRIPT_DIR/AppDir"
mkdir -p "$OUTDIR"
rm -f "$OUTFILE" "$OUTFILE.zsync"

###### 准备构建环境 ######

yay -S --noconfirm \
    base-devel git wget curl jq binutils patchelf file coreutils findutils \
    grep sed gawk tar gzip xz unzip rsync util-linux appstream-glib \
    desktop-file-utils zsync ca-certificates

###### 安装 Parsec 与应用级运行依赖 ######

# parsec-bin 当前从 Parsec 官方 Linux .deb 取程序本体，并按 AUR 元数据拉取 ffmpeg4.4 等依赖。
# libjpeg-turbo 提供 Parsec 需要的 libjpeg v8 ABI；libva 用于硬件解码能力发现。
yay -S --noconfirm parsec-bin ffmpeg4.4 libjpeg-turbo libva

command -v parsecd >/dev/null 2>&1 || die "未找到 /usr/bin/parsecd。"
[[ -d "$PARSEC_SKEL" ]] || die "未找到 Parsec 官方 skel 目录：$PARSEC_SKEL"
[[ -f "$PARSEC_SKEL/appdata.json" ]] || die "未找到 Parsec 官方 appdata.json。"

mapfile -t PARSEC_MODULES < <(
    find "$PARSEC_SKEL" -maxdepth 1 -type f -name 'parsecd-*.so' -print | sort -V
)
(( ${#PARSEC_MODULES[@]} > 0 )) || die "未找到 Parsec 官方 parsecd-*.so 模块。"

for required_library in \
    /usr/lib/libavcodec.so.58 \
    /usr/lib/libavutil.so.56 \
    /usr/lib/libswresample.so.3 \
    /usr/lib/libva.so.2 \
    /usr/lib/libva-drm.so.2 \
    /usr/lib/libva-x11.so.2; do
    [[ -e "$required_library" ]] || die "缺少 Parsec 解码所需运行库：$required_library"
done

VERSION="$(pacman -Q parsec-bin | awk '{print $2; exit}')"
[[ -n "$VERSION" ]] || die "无法读取 parsec-bin 版本。"

# 官方包历史上出现过 parsec.desktop / parsecd.desktop 命名；按当前已安装包文件清单动态选择，避免绑定文件名。
DESKTOP="$(pacman -Ql parsec-bin | awk '$2 ~ /^\/usr\/share\/applications\/parsec.*\.desktop$/ {print $2; exit}')"
[[ -f "$DESKTOP" ]] || die "未找到 Parsec desktop 文件。"

ICON="$(pacman -Ql parsec-bin | awk '$2 ~ /^\/usr\/share\/icons\/hicolor\/.*\/apps\/parsec.*\.(png|svg)$/ {print $2}' | sort -V | tail -n 1)"
[[ -f "$ICON" ]] || die "未找到 Parsec 图标。"

export ARCH VERSION DESKTOP ICON
export STARTUPWMCLASS=parsecd
export OUTPATH="$OUTDIR"
export OUTNAME="parsec.AppImage"

# Parsec 官方 Linux 客户端使用 OpenGL，并通过 ALSA / PipeWire 输出音频。
export DEPLOY_OPENGL=1
export DEPLOY_PIPEWIRE=1
export DEPLOY_LOCALE=1

# AUR 对官方 Parsec 二进制使用 !strip；保持上游闭源 ELF 原样。
export NO_STRIP=1

# parsecd 使用官方 /usr/share/parsec/skel 作为启动资源，运行时映射回 AppImage 内部。
export PATH_MAPPING='/usr/share/parsec:${SHARUN_DIR}/share/parsec'

###### 核心打包 ######

# 显式把官方动态模块、FFmpeg 4.4 解码 ABI 和 VA-API loader 交给 quick-sharun。
# libva 是 AUR 标注的硬件解码可选依赖，属于运行时按需加载组件，不能只依赖 ELF 直接依赖扫描。
# 这里只封装通用 libva loader；GPU 厂商驱动继续使用宿主系统，避免把构建机驱动写进 AppImage。
quick-sharun \
    /usr/bin/parsecd \
    "${PARSEC_MODULES[@]}" \
    /usr/lib/libavcodec.so.58 \
    /usr/lib/libavutil.so.56 \
    /usr/lib/libswresample.so.3 \
    /usr/lib/libva.so.2 \
    /usr/lib/libva-drm.so.2 \
    /usr/lib/libva-x11.so.2

###### 保留官方启动资源与中文环境 ######

mkdir -p AppDir/share/parsec
cp -a "$PARSEC_SHARE/." AppDir/share/parsec/

# 生成 AppImage 自带的简体中文 UTF-8 locale，不依赖宿主机是否预先生成该 locale。
mkdir -p AppDir/lib/locale
localedef --no-archive \
    -i zh_CN \
    -f UTF-8 \
    AppDir/lib/locale/zh_CN.utf8

cat >> AppDir/.env <<'EOF_LOCALE'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_CTYPE=zh_CN.UTF-8
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
EOF_LOCALE

# Parsec 官方依赖列表未要求 Qt / GTK 输入上下文插件。
# 不覆盖 XMODIFIERS、GTK_IM_MODULE 或 QT_IM_MODULE，继续继承宿主会话中的 Fcitx5 / IBus / XIM 配置。

###### 生成 AppImage ######

[[ -x AppDir/bin/parsecd ]] || die "AppDir 中缺少 parsecd 主程序。"
[[ -f AppDir/share/parsec/skel/appdata.json ]] || die "AppDir 中缺少 Parsec appdata.json。"
find AppDir/share/parsec/skel -maxdepth 1 -type f -name 'parsecd-*.so' -print -quit | grep -q . \
    || die "AppDir 中缺少 Parsec 官方动态模块。"
find AppDir -type f -name 'libavcodec.so.58*' -print -quit | grep -q . \
    || die "AppDir 中缺少 libavcodec.so.58。"
find AppDir -type f -name 'libavutil.so.56*' -print -quit | grep -q . \
    || die "AppDir 中缺少 libavutil.so.56。"
find AppDir -type f -name 'libva.so.2*' -print -quit | grep -q . \
    || die "AppDir 中缺少 libva.so.2。"

quick-sharun --make-appimage

[[ -s "$OUTFILE" ]] || die "没有生成有效的 Parsec AppImage。"

log "构建完成：$OUTFILE"
sha256sum "$OUTFILE"
