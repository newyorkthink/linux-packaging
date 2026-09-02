#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APPDIR="$SCRIPT_DIR/AppDir"
DIST_DIR="$SCRIPT_DIR/dist"
OUTFILE="$DIST_DIR/mission-center.AppImage"

rm -rf "$APPDIR" "$DIST_DIR"
mkdir -p "$DIST_DIR"

# 使用 Arch Linux Extra 当前正式版 Mission Center，并安装 quick-sharun 所需 patchelf 与中文环境校验所需 gettext。
pacman -Syu --noconfirm --needed \
  gettext \
  mission-center \
  patchelf \
  zsync

for required_command in localedef msgunfmt pacman patchelf quick-sharun; do
  command -v "$required_command" >/dev/null 2>&1 || {
    echo "错误：缺少构建命令：$required_command" >&2
    exit 1
  }
done

for required_file in \
  /usr/bin/missioncenter \
  /usr/bin/missioncenter-magpie \
  /usr/share/applications/io.missioncenter.MissionCenter.desktop \
  /usr/share/icons/hicolor/scalable/apps/io.missioncenter.MissionCenter.svg \
  /usr/share/locale/zh/LC_MESSAGES/missioncenter.mo \
  /usr/share/locale/zh_TW/LC_MESSAGES/missioncenter.mo; do
  [[ -e "$required_file" ]] || {
    echo "错误：Mission Center 官方包缺少必需文件：$required_file" >&2
    exit 1
  }
done

# 先确认上游自带的简体中文 gettext 文件有效，避免构建出只有语言环境但没有中文翻译的 AppImage。
msgunfmt /usr/share/locale/zh/LC_MESSAGES/missioncenter.mo >/dev/null

PACKAGE_VERSION="$(pacman -Q mission-center | awk '{print $2}')"
printf 'Mission Center package version: %s\n' "$PACKAGE_VERSION"

export ARCH="$(uname -m)"
export APPDIR
export ICON=/usr/share/icons/hicolor/scalable/apps/io.missioncenter.MissionCenter.svg
export DESKTOP=/usr/share/applications/io.missioncenter.MissionCenter.desktop
export OUTPATH="$DIST_DIR"
export OUTNAME="$(basename "$OUTFILE")"
export DEPLOY_GTK=1
export GTK_DIR=gtk-4.0
export DEPLOY_LOCALE=1

# 与 Mission Center 上游 AppImage 当前方案一致，同时部署主程序和 magpie 后端。
quick-sharun /usr/bin/missioncenter /usr/bin/missioncenter-magpie

# quick-sharun 会保留 missioncenter、GTK4 和 libadwaita 对应的 gettext 资源；这里再做强校验。
for bundled_translation in \
  "$APPDIR/share/locale/zh/LC_MESSAGES/missioncenter.mo" \
  "$APPDIR/share/locale/zh_TW/LC_MESSAGES/missioncenter.mo"; do
  [[ -s "$bundled_translation" ]] || {
    echo "错误：AppDir 中缺少 Mission Center 中文翻译：$bundled_translation" >&2
    exit 1
  }
  msgunfmt "$bundled_translation" >/dev/null
done

# 生成 AppImage 自带的简体中文 UTF-8 locale，避免依赖宿主是否已生成 zh_CN.UTF-8。
mkdir -p "$APPDIR/lib/locale"
rm -rf "$APPDIR/lib/locale/zh_CN.utf8"
localedef --no-archive \
  -i zh_CN \
  -f UTF-8 \
  "$APPDIR/lib/locale/zh_CN.utf8"
[[ -s "$APPDIR/lib/locale/zh_CN.utf8/LC_MESSAGES/SYS_LC_MESSAGES" ]] || {
  echo "错误：zh_CN.UTF-8 locale 数据生成失败。" >&2
  exit 1
}

# 固定界面消息使用简体中文；LANGUAGE 保留 zh 回退以匹配上游实际的简体中文目录名。
cat >> "$APPDIR/.env" <<'EOF_LOCALE'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
EOF_LOCALE

# 确认中文环境变量与 locale 路径完整写入，不覆盖 quick-sharun 已生成的运行环境。
grep -Fxq 'LANG=zh_CN.UTF-8' "$APPDIR/.env"
grep -Fxq 'LANGUAGE=zh_CN:zh' "$APPDIR/.env"
grep -Fxq 'LC_MESSAGES=zh_CN.UTF-8' "$APPDIR/.env"
grep -Fxq 'LOCPATH=${SHARUN_DIR}/lib/locale' "$APPDIR/.env"

quick-sharun --make-appimage

[[ -s "$OUTFILE" ]] || {
  echo "错误：未生成 $OUTFILE" >&2
  exit 1
}

printf 'Built: %s\n' "$OUTFILE"
