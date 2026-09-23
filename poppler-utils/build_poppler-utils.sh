#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

###### 准备构建环境 ######

[[ "$(uname -m)" == x86_64 ]] || {
  echo "错误：当前仅支持 x86_64。" >&2
  exit 1
}

rm -rf AppDir dist source
mkdir -p AppDir/usr/bin AppDir/usr/share/applications \
  AppDir/usr/share/icons/hicolor/256x256/apps AppDir/usr/share dist source

# linuxdeploy + appimagetool 固定在 Ubuntu 24.04 构建，不使用 Arch Linux / yay。
# 使用 Ubuntu 官方 deb 包，不编译 Poppler 源码。
"$SCRIPT_DIR/../common/apt/install_packages.sh" \
  aptitude build-essential git wget curl jq binutils patchelf file \
  appstream-util desktop-file-utils zsync ca-certificates \
  poppler-utils poppler-data

POPPLER_PACKAGE_VERSION="$(dpkg-query -W -f='${Version}\n' poppler-utils)"
POPPLER_VERSION="${POPPLER_PACKAGE_VERSION#*:}"
POPPLER_VERSION="${POPPLER_VERSION%-*}"

###### 下载官方打包工具 ######

download_tool() {
  local repo="$1" asset="$2" output="$3" metadata digest
  metadata="$(curl -fsSL --retry 3 --retry-all-errors --connect-timeout 20 --max-time 120 \
    "https://api.github.com/repos/$repo/releases/tags/continuous")"
  digest="$(jq -er --arg name "$asset" '.assets[] | select(.name == $name) | .digest' <<< "$metadata")"
  [[ "$digest" =~ ^sha256:[[:xdigit:]]{64}$ ]] || {
    echo "错误：官方工具缺少有效 SHA-256：$repo/$asset" >&2
    exit 1
  }
  curl -fL --retry 3 --retry-all-errors --connect-timeout 20 --max-time 300 \
    "https://github.com/$repo/releases/download/continuous/$asset" -o "$output"
  printf '%s  %s\n' "${digest#sha256:}" "$output" | sha256sum -c -
}

download_tool linuxdeploy/linuxdeploy linuxdeploy-x86_64.AppImage source/linuxdeploy
download_tool AppImage/appimagetool appimagetool-x86_64.AppImage source/appimagetool
download_tool AppImage/type2-runtime runtime-x86_64 source/runtime-x86_64
chmod +x source/linuxdeploy source/appimagetool

curl -fL --retry 3 --retry-all-errors --connect-timeout 20 --max-time 120 \
  https://poppler.freedesktop.org/logo.png -o source/poppler-utils.png

###### 准备 AppDir ######

PDF_TOOLS=(
  pdfattach pdfdetach pdffonts pdfimages pdfinfo pdfseparate pdfsig
  pdftocairo pdftohtml pdftoppm pdftops pdftotext pdfunite
)

for tool in "${PDF_TOOLS[@]}"; do
  [[ -x "/usr/bin/$tool" ]] || {
    echo "错误：Ubuntu poppler-utils 缺少 /usr/bin/$tool。" >&2
    exit 1
  }
  cp "/usr/bin/$tool" AppDir/usr/bin/
done

cp -a /usr/share/poppler AppDir/usr/share/

cat > AppDir/usr/share/applications/poppler-utils.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Poppler Utilities
Exec=pdftotext %F
Icon=poppler-utils
Terminal=true
Categories=Office;Utility;
EOF

cp source/poppler-utils.png AppDir/usr/share/icons/hicolor/256x256/apps/poppler-utils.png

# ARGV0 保留软链接入口名；也支持把命令名作为第一个参数。
cat > AppDir/AppRun <<'EOF'
#!/bin/sh
set -eu

APPDIR="${APPDIR:-$(CDPATH= cd -P -- "$(dirname -- "$0")" && pwd)}"
export PATH="$APPDIR/usr/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$APPDIR/usr/lib:$APPDIR/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$APPDIR/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

tool="$(basename -- "${ARGV0:-${APPIMAGE:-$0}}")"
case "$tool" in
  pdfattach|pdfdetach|pdffonts|pdfimages|pdfinfo|pdfseparate|pdfsig|pdftocairo|pdftohtml|pdftoppm|pdftops|pdftotext|pdfunite) ;;
  *)
    case "${1-}" in
      pdfattach|pdfdetach|pdffonts|pdfimages|pdfinfo|pdfseparate|pdfsig|pdftocairo|pdftohtml|pdftoppm|pdftops|pdftotext|pdfunite)
        tool="$1"
        shift
        ;;
      *) tool=pdftotext ;;
    esac
    ;;
esac

exec "$APPDIR/usr/bin/$tool" "$@"
EOF
chmod +x AppDir/AppRun

###### 核心打包 ######

export APPIMAGE_EXTRACT_AND_RUN=1
export PATH="$SCRIPT_DIR/source:$PATH"
export LDAI_OUTPUT="$SCRIPT_DIR/source/poppler-utils-intermediate.AppImage"
export LDAI_NO_APPSTREAM=1

# linuxdeploy 负责收集 AppDir 中全部命令及依赖。
export ARCH=x86_64; linuxdeploy --appdir AppDir --output appimage

# appimagetool 使用最新官方 Type 2 runtime 生成最终 AppImage。
export ARCH=x86_64; appimagetool -n ./AppDir ./dist/poppler-utils.AppImage --runtime-file ./source/runtime-x86_64

###### 整理产物 ######

printf '%s\n' "$POPPLER_VERSION" > ./dist/version.txt
