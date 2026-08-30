#!/usr/bin/env bash
set -euo pipefail

# 稳定基线说明：
# - 只使用 sagb/alttab 官方最新稳定 GitHub Release 源码，不依赖 AUR 的 alttab/alttab-git 包。
# - 每次构建先读取 releases/latest，再把发布 tag 解析到具体 commit SHA，并按该 commit 下载源码。
# - 使用 Arch Linux 官方仓库提供的构建/运行依赖。
# - 使用 quick-sharun 生成 AppImage，并在 Xvfb 中执行 alttab -h 做运行时验证。

# 清理上一次构建生成的 AppDir。
rm -rf AppDir || true

# 创建最终输出目录。
mkdir -p dist

# 获取当前系统架构。
ARCH="$(uname -m)"

# 导出 AppImage 架构。
export ARCH

# 创建本次构建使用的临时目录。
WORKDIR="$(mktemp -d)"

# 退出时删除本次构建的临时目录。
trap 'rm -rf "$WORKDIR"' EXIT

# 定义上游最新稳定 Release API 和本地元数据路径。
ALTTAB_RELEASE_API="https://api.github.com/repos/sagb/alttab/releases/latest"
RELEASE_JSON="$WORKDIR/latest-release.json"

# 安装 quick-sharun 打包、源码编译、Release 解析和 Xvfb 验证所需的基础依赖。
yay -S --noconfirm gcc base-devel pkgconf wget git jq binutils patchelf coreutils appstream-glib desktop-file-utils util-linux zsync xorg-server xorg-server-common xorg-server-xvfb

# 安装 alttab 官方声明的 X11、图形和 uthash 构建/运行依赖。
yay -S --noconfirm libx11 libxmu libxft libxrender libxrandr libpng libxpm uthash

# 读取上游最新稳定 GitHub Release；在 GitHub Actions 中优先使用现有 GH_TOKEN，避免匿名 API 限额。
if [[ -n "${GH_TOKEN:-}" ]]; then
  wget --quiet \
    --header="Authorization: Bearer ${GH_TOKEN}" \
    --header="Accept: application/vnd.github+json" \
    --header="X-GitHub-Api-Version: 2022-11-28" \
    -O "$RELEASE_JSON" \
    "$ALTTAB_RELEASE_API"
else
  wget --quiet \
    --header="Accept: application/vnd.github+json" \
    --header="X-GitHub-Api-Version: 2022-11-28" \
    -O "$RELEASE_JSON" \
    "$ALTTAB_RELEASE_API"
fi

# 确认取得的是非草稿、非预发布的稳定 Release。
jq -e '.draft == false and .prerelease == false' "$RELEASE_JSON" >/dev/null

# 读取最新稳定 Release 的 tag。
ALTTAB_TAG="$(jq -er '.tag_name | strings | select(length > 0)' "$RELEASE_JSON")"

# 拒绝包含路径分隔符、空白或其他异常字符的 tag。
if [[ ! "$ALTTAB_TAG" =~ ^[0-9A-Za-z][0-9A-Za-z._+-]*$ ]]; then
  echo "错误：上游 Release tag 格式异常：$ALTTAB_TAG" >&2
  exit 1
fi

# 去掉常见的 v 前缀，作为 AppImage 版本信息；没有 v 前缀时保持原值。
ALTTAB_VERSION="${ALTTAB_TAG#v}"

# 将 Release tag 解析到具体 commit；annotated tag 优先使用 peeled commit SHA。
REMOTE_REFS="$(git ls-remote https://github.com/sagb/alttab.git \
  "refs/tags/${ALTTAB_TAG}" \
  "refs/tags/${ALTTAB_TAG}^{}")"
ALTTAB_COMMIT="$(awk -v ref="refs/tags/${ALTTAB_TAG}^{}" '$2 == ref {print $1; exit}' <<< "$REMOTE_REFS")"
if [[ -z "$ALTTAB_COMMIT" ]]; then
  ALTTAB_COMMIT="$(awk -v ref="refs/tags/${ALTTAB_TAG}" '$2 == ref {print $1; exit}' <<< "$REMOTE_REFS")"
fi

# 确认 Release tag 最终解析到有效的 Git commit SHA。
if [[ ! "$ALTTAB_COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
  echo "错误：无法把上游 Release tag $ALTTAB_TAG 解析到有效 commit。" >&2
  exit 1
fi

# 记录本次实际构建的上游版本和 commit。
printf 'AltTab release: %s\nAltTab commit: %s\n' "$ALTTAB_TAG" "$ALTTAB_COMMIT"

# 按本次已解析出的不可变 commit SHA 构造官方源码下载地址。
ALTTAB_SOURCE_URL="https://codeload.github.com/sagb/alttab/tar.gz/${ALTTAB_COMMIT}"
SOURCE_ARCHIVE="$WORKDIR/alttab-${ALTTAB_COMMIT}.tar.gz"

# 下载该 Release 对应 commit 的官方源码归档。
wget -O "$SOURCE_ARCHIVE" "$ALTTAB_SOURCE_URL"

# 输出本次源码归档 SHA-256，便于构建日志审计。
sha256sum "$SOURCE_ARCHIVE"

# 解压源码并去掉 GitHub 归档自动生成的顶层目录名。
SOURCE_DIR="$WORKDIR/source"
mkdir -p "$SOURCE_DIR"
tar -xzf "$SOURCE_ARCHIVE" -C "$SOURCE_DIR" --strip-components=1

# 确认关键源码、许可证和构建文件存在。
test -f "$SOURCE_DIR/configure"
test -f "$SOURCE_DIR/src/alttab.c"
test -f "$SOURCE_DIR/doc/alttab.svg"
test -f "$SOURCE_DIR/COPYING"

# 配置 alttab，保持标准 /usr 安装前缀。
(
  cd "$SOURCE_DIR"
  ./configure --prefix=/usr
)

# 编译 alttab。
make -C "$SOURCE_DIR" -j"$(nproc)"

# 确认编译后的主程序存在且可执行。
test -x "$SOURCE_DIR/src/alttab"

# 创建 AppImage 使用的 desktop 文件；alttab 是 X11 常驻窗口切换器。
cat > "$WORKDIR/alttab.desktop" <<'EOF_DESKTOP'
[Desktop Entry]
Type=Application
Name=AltTab
Comment=X11 window switcher for minimalistic window managers
Exec=alttab
Icon=alttab
Terminal=false
Categories=Utility;
StartupNotify=false
EOF_DESKTOP

# 校验 desktop 文件语法。
desktop-file-validate "$WORKDIR/alttab.desktop"

# 使用本次最新稳定 Release 的版本号作为 AppImage 版本信息。
export VERSION="$ALTTAB_VERSION"

# 使用上游 SVG 图标。
export ICON="$SOURCE_DIR/doc/alttab.svg"

# 使用本次生成的 desktop 文件。
export DESKTOP="$WORKDIR/alttab.desktop"

# 设置 AppImage 输出目录。
export OUTPATH=./dist

# 固定最终 AppImage 文件名，便于 latest Release 持续覆盖更新。
export OUTNAME="alttab.AppImage"

# 固定 AppImage 主程序为 alttab。
export MAIN_BIN=alttab

# 将刚刚从官方 Release 对应 commit 编译出的 alttab 及其动态依赖封装进 AppDir。
quick-sharun "$SOURCE_DIR/src/alttab"

# 将上游 GPL-3.0 许可证随 AppImage 一并保留。
mkdir -p AppDir/share/licenses/alttab
cp -a "$SOURCE_DIR/COPYING" AppDir/share/licenses/alttab/COPYING

# 生成最终 alttab AppImage。
quick-sharun --make-appimage

# 确认最终 AppImage 文件已经生成且不为空。
test -s ./dist/alttab.AppImage

# 在虚拟 X11 显示中执行帮助命令，验证 AppImage 主程序及动态链接依赖可以正常加载。
APPIMAGE_EXTRACT_AND_RUN=1 xvfb-run -a ./dist/alttab.AppImage -h >/dev/null
