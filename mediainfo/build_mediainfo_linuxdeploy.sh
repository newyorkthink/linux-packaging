#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# 进入当前应用目录，所有构建文件均放在此处。
cd "$SCRIPT_DIR"

###### 准备构建环境 ######

[[ "$(uname -m)" == x86_64 ]] || {
  echo "错误：当前仅支持 x86_64。" >&2
  exit 1
}
# 仅清理当前应用上一次构建的目录和产物。
rm -rf AppDir dist source
# 创建 CLI、desktop、图标和构建工具目录。
mkdir -p AppDir/usr/bin AppDir/usr/share/applications AppDir/usr/share/icons/hicolor/scalable/apps dist source

# 在现有 Arch CI 容器中安装打包基础工具。
yay -S --needed --noconfirm curl jq binutils patchelf file coreutils desktop-file-utils ca-certificates
# 安装 MediaInfo CLI，由包管理器拉入实际运行依赖。
yay -S --needed --noconfirm mediainfo

# 从实际安装包读取上游版本，去掉 Arch epoch / pkgrel。
MEDIAINFO_PACKAGE_VERSION="$(pacman -Q mediainfo | awk '{print $2}')"
MEDIAINFO_VERSION="${MEDIAINFO_PACKAGE_VERSION#*:}"
MEDIAINFO_VERSION="${MEDIAINFO_VERSION%-*}"
[[ -n "$MEDIAINFO_VERSION" ]] || {
  echo "错误：无法解析 MediaInfo 版本。" >&2
  exit 1
}

###### 下载官方资源 ######

# 下载官方 Release 工具，并核对该资产的 SHA-256；下载失败直接退出。
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

# 下载 linuxdeploy 依赖部署工具。
download_tool linuxdeploy/linuxdeploy linuxdeploy-x86_64.AppImage source/linuxdeploy
# 下载官方最终封装工具。
download_tool AppImage/appimagetool appimagetool-x86_64.AppImage source/appimagetool
# runtime 来自 type2-runtime，与 appimagetool 分属两个官方仓库。
download_tool AppImage/type2-runtime runtime-x86_64 source/runtime-x86_64
# 允许构建工具执行。
chmod +x source/linuxdeploy source/appimagetool
# CLI 没有自带图标，使用 MediaInfo 官方 SVG。
curl -fL --retry 3 --retry-all-errors --connect-timeout 20 --max-time 120 \
  https://raw.githubusercontent.com/MediaArea/MediaInfo/master/Source/Resource/Image/MediaInfo.svg \
  -o AppDir/usr/share/icons/hicolor/scalable/apps/mediainfo.svg

###### 准备 AppDir ######

# 放入 CLI 主程序，依赖由 linuxdeploy 自动收集。
cp /usr/bin/mediainfo AppDir/usr/bin/mediainfo
# 提供 CLI 的启动元数据，不引入 GUI 或 GTK 插件。
cat > AppDir/usr/share/applications/mediainfo.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=MediaInfo
Exec=mediainfo %f
Icon=mediainfo
Terminal=true
Categories=AudioVideo;
EOF

###### 核心打包 ######

# 仅构建工具在 CI 中解包运行；此变量不会写入最终 AppImage。
export APPIMAGE_EXTRACT_AND_RUN=1
export PATH="$SCRIPT_DIR/source:$PATH"
# 保留 linuxdeploy 输出步骤，中间产物不进入发布目录。
export LDAI_OUTPUT="$SCRIPT_DIR/source/mediainfo-intermediate.AppImage"
export LDAI_RUNTIME_FILE="$SCRIPT_DIR/source/runtime-x86_64"
export LDAI_NO_APPSTREAM=1
# 部署依赖并生成中间 AppImage，保持原有核心命令。
export ARCH=x86_64; linuxdeploy --appdir AppDir --output appimage

# 最终由官方 appimagetool 使用明确的 runtime 封装为固定发布名称。
export ARCH=x86_64; appimagetool -n ./AppDir ./dist/mediainfo.AppImage --runtime-file ./source/runtime-x86_64

###### 整理产物 ######

# 最终封装成功后写入本次实际软件版本。
printf '%s\n' "$MEDIAINFO_VERSION" > ./dist/version.txt
