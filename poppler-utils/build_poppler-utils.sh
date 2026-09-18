#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

###### 准备构建环境 ######

rm -rf AppDir dist
mkdir -p dist

export ARCH="$(uname -m)"
export OUTPATH="./dist"
export OUTNAME="poppler-utils.AppImage"
export APPNAME="poppler-utils"
export DESKTOP=DUMMY
export MAIN_BIN=pdftotext

# 安装 quick-sharun / AppImage 打包所需的最小基础工具
yay -S --noconfirm base-devel git wget curl jq binutils patchelf file coreutils findutils \
  grep sed gawk tar gzip xz unzip rsync util-linux appstream-glib \
  desktop-file-utils zsync ca-certificates

# 单独安装当前应用。poppler 提供整套命令行工具；poppler-data 是文字提取所需的 CMap / 编码数据。
yay -S --noconfirm poppler poppler-data

POPPLER_PACKAGE_VERSION="$(pacman -Q poppler | awk '{print $2}')"
POPPLER_VERSION="${POPPLER_PACKAGE_VERSION#*:}"
POPPLER_VERSION="${POPPLER_VERSION%-*}"
[[ -n "$POPPLER_VERSION" ]] || {
  echo "错误：无法解析 poppler 版本。" >&2
  exit 1
}

# 官方包没有应用图标。quick-sharun 在 DESKTOP=DUMMY 时仍要求 ICON。
# Adwaita 50 没有 application-pdf，使用已随 appstream-glib 装上的文档 MIME 图标。
ICON=/usr/share/icons/Adwaita/scalable/mimetypes/x-office-document.svg
[[ -f "$ICON" ]] || {
  echo "错误：找不到 ${ICON}，无法设置 ICON。" >&2
  exit 1
}
export ICON

###### 核心打包 ######

# Arch extra/poppler 当前提供的 PDF 命令行工具，与 Debian poppler-utils 同一套入口。
PDF_TOOLS=(
  pdfattach
  pdfdetach
  pdffonts
  pdfimages
  pdfinfo
  pdfseparate
  pdfsig
  pdftocairo
  pdftohtml
  pdftoppm
  pdftops
  pdftotext
  pdfunite
)

PDF_BINS=()
for tool in "${PDF_TOOLS[@]}"; do
  bin="/usr/bin/${tool}"
  [[ -x "$bin" ]] || {
    echo "错误：缺少 ${bin}，当前 poppler 包未提供该命令。" >&2
    exit 1
  }
  PDF_BINS+=("$bin")
done

# 有标准 /usr/bin 入口，直接交给 quick-sharun；编码数据随 poppler-data 收集。
QS_ARGS=("${PDF_BINS[@]}")
if [[ -d /usr/share/poppler ]]; then
  QS_ARGS+=(/usr/share/poppler)
fi

quick-sharun "${QS_ARGS[@]}"

###### 整理产物 ######

quick-sharun --make-appimage

test -s ./dist/poppler-utils.AppImage
printf '%s\n' "$POPPLER_VERSION" > ./dist/version.txt
