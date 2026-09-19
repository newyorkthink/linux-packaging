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

# linuxdeploy + appimagetool 路线固定在 Ubuntu 24.04 构建，不使用 Arch Linux / yay。
# 更新 Ubuntu 软件包索引并准备 aptitude。
sudo apt-get update
sudo apt-get install -y aptitude
# 安装 linuxdeploy / appimagetool 打包所需的最小基础工具。
sudo aptitude install -y build-essential git wget curl jq binutils patchelf file appstream-util desktop-file-utils zsync ca-certificates

# 从 MediaArea 官方仓库页面动态取得当前 releases 仓库安装包。
MEDIAAREA_REPOS_PAGE="$(curl -fsSL --retry 3 --retry-all-errors --connect-timeout 20 --max-time 120 \
  https://mediaarea.net/en/Repos)"
MEDIAAREA_REPO_URL="$(
  sed -nE 's#.*(https://mediaarea\.net/repo/deb/repo-mediaarea_[0-9.-]+_all\.deb).*#\1#p' \
    <<< "$MEDIAAREA_REPOS_PAGE" |
    head -n 1
)"
[[ "$MEDIAAREA_REPO_URL" =~ ^https://mediaarea\.net/repo/deb/repo-mediaarea_[0-9.-]+_all\.deb$ ]] || {
  echo "错误：无法从 MediaArea 官方页面解析 releases 仓库安装包。" >&2
  exit 1
}
# 安装官方 releases 仓库配置，并记录该安装包的实际哈希。
curl -fL --retry 3 --retry-all-errors --connect-timeout 20 --max-time 120 \
  "$MEDIAAREA_REPO_URL" -o source/repo-mediaarea.deb
sha256sum source/repo-mediaarea.deb
sudo dpkg -i source/repo-mediaarea.deb
sudo apt-get update
# 安装 MediaArea 官方最新稳定版 CLI，由 APT 拉入实际运行依赖。
sudo aptitude install -y mediainfo

# 从实际安装包读取上游版本，去掉 Debian epoch / revision。
MEDIAINFO_PACKAGE_VERSION="$(dpkg-query -W -f='${Version}\n' mediainfo)"
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
  -o source/MediaInfo.svg

###### 准备 AppDir ######

# 放入 CLI 主程序，依赖由 linuxdeploy 自动收集。
cp /usr/bin/mediainfo AppDir/usr/bin/mediainfo
# 先检查实际安装包；只有 CLI 包确实没有 desktop 时才生成最小 desktop。
mapfile -t MEDIAINFO_DESKTOP_FILES < <(
  dpkg -L mediainfo | awk '/\/usr\/share\/applications\/.*\.desktop$/ {print}'
)
if (( ${#MEDIAINFO_DESKTOP_FILES[@]} == 0 )); then
  cat > source/mediainfo.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=MediaInfo
Exec=mediainfo %f
Icon=mediainfo
Terminal=true
Categories=AudioVideo;
EOF
elif (( ${#MEDIAINFO_DESKTOP_FILES[@]} == 1 )); then
  cp "${MEDIAINFO_DESKTOP_FILES[0]}" source/mediainfo.desktop
else
  echo "错误：mediainfo CLI 包包含多个 desktop，无法唯一选择。" >&2
  printf '%s\n' "${MEDIAINFO_DESKTOP_FILES[@]}" >&2
  exit 1
fi
# 将最终使用的 desktop 和官方图标放入 AppDir。
cp source/mediainfo.desktop AppDir/usr/share/applications/mediainfo.desktop
cp source/MediaInfo.svg AppDir/usr/share/icons/hicolor/scalable/apps/mediainfo.svg

###### 核心打包 ######

# 仅构建工具在 CI 中解包运行；此变量不会写入最终 AppImage。
export APPIMAGE_EXTRACT_AND_RUN=1
export PATH="$SCRIPT_DIR/source:$PATH"
# 保留 linuxdeploy 输出步骤；该中间产物不进入发布目录。
export LDAI_OUTPUT="$SCRIPT_DIR/source/mediainfo-intermediate.AppImage"
export LDAI_NO_APPSTREAM=1
# linuxdeploy 负责整理 AppDir、收集依赖并生成中间 AppImage。
export ARCH=x86_64; linuxdeploy --appdir AppDir --output appimage

# 最终由官方 appimagetool 使用构建时下载的最新 continuous runtime 重新封装。
export ARCH=x86_64; appimagetool -n ./AppDir ./dist/mediainfo.AppImage --runtime-file ./source/runtime-x86_64

###### 整理产物 ######

# 最终封装成功后写入本次实际软件版本。
printf '%s\n' "$MEDIAINFO_VERSION" > ./dist/version.txt
