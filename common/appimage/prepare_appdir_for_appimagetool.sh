#!/usr/bin/env bash
# 适配 appimagetool 对 AppDir 权限和 .DirIcon 有效性的检查，不改变封装命令。
# 上游不再主动用 SVG 生成 .DirIcon；本入口在缺少同名 PNG / XPM 根图标时补 PNG，并保留原 SVG。
# SVG 转换需要构建环境提供 rsvg-convert、magick 或 convert；Ubuntu 可安装 librsvg2-bin。
# 上游变更、适用条件和依赖说明见 docs/appimagetool-icon-compatibility.md。
set -Eeuo pipefail

die() {
  echo "错误：$*" >&2
  exit 1
}

if [[ $# -ne 1 ]]; then
  die "用法：$0 <AppDir>"
fi

input="$1"
if [[ -z "$input" || "$input" == "/" ]]; then
  die "拒绝空路径或根目录。"
fi
if [[ ! -d "$input" ]]; then
  die "不是有效目录：$input"
fi

APPDIR="$(cd -- "$input" && pwd -P)"
if [[ -z "$APPDIR" || "$APPDIR" == "/" ]]; then
  die "拒绝空路径或根目录。"
fi

# GNU chmod -R 不沿软链接进入或修改包外文件。只处理这个 AppDir。
chmod -R a-s,a+rX -- "$APPDIR"

# 主 desktop：AppDir 根目录按名字排序后的第一个 *.desktop，与非递归查找一致。
desktop_list="$(mktemp)"
find -P "$APPDIR" -maxdepth 1 \( -type f -o -type l \) -name '*.desktop' -print | sort > "$desktop_list"
desktop=""
IFS= read -r desktop < "$desktop_list" || true
rm -f -- "$desktop_list"
if [[ -z "$desktop" ]]; then
  exit 0
fi

icon=""
in_entry=0
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"
  trimmed="${line#"${line%%[![:space:]]*}"}"
  trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
  case "${trimmed,,}" in
    \[*\])
      if [[ "${trimmed,,}" == "[desktop entry]" ]]; then
        in_entry=1
      else
        in_entry=0
      fi
      ;;
    icon=*)
      if [[ "$in_entry" -eq 1 && -z "$icon" ]]; then
        icon="${trimmed#*=}"
        icon="${icon#"${icon%%[![:space:]]*}"}"
        icon="${icon%"${icon##*[![:space:]]}"}"
      fi
      ;;
  esac
done < "$desktop"

if [[ -z "$icon" ]]; then
  exit 0
fi

case "${icon,,}" in
  *.png) icon="${icon:0:${#icon}-4}" ;;
  *.svg) icon="${icon:0:${#icon}-4}" ;;
  *.xpm) icon="${icon:0:${#icon}-4}" ;;
esac

case "$icon" in
  ""|/*|..|.)
    die "Icon 名无法放到 AppDir 根目录：$icon"
    ;;
  *[/]*|*'..'*|*'\'*)
    die "Icon 名无法放到 AppDir 根目录：$icon"
    ;;
  *'*'*|*'?'*|*'['*)
    die "Icon 名含通配符，拒绝搜索：$icon"
    ;;
esac

root_png="$APPDIR/$icon.png"
root_xpm="$APPDIR/$icon.xpm"
if [[ -f "$root_png" || -f "$root_xpm" ]]; then
  exit 0
fi

largest_match() {
  local name="$1"
  local list best="" best_size=-1 path size
  list="$(mktemp)"
  find -P "$APPDIR" -type f -name "$name" -print0 > "$list"
  while IFS= read -r -d '' path; do
    size="$(stat -c '%s' -- "$path")"
    if (( size > best_size )); then
      best="$path"
      best_size="$size"
    fi
  done < "$list"
  rm -f -- "$list"
  printf '%s' "$best"
}

place_png() {
  local dest="$1"
  if [[ -L "$dest" ]]; then
    rm -f -- "$dest"
  elif [[ -e "$dest" ]]; then
    die "根图标路径已存在且不是合格文件：$dest"
  fi
}

src="$(largest_match "$icon.png")"
if [[ -n "$src" ]]; then
  place_png "$root_png"
  cp -f -- "$src" "$root_png"
  chmod 0644 -- "$root_png"
  exit 0
fi

# 根目录和包内均无同名 PNG 时，保留原 SVG，并生成供 appimagetool 选择的 PNG 根图标。
src="$(largest_match "$icon.svg")"
if [[ -z "$src" ]]; then
  die "desktop 图标 $icon 没有可用的 PNG 或 SVG。"
fi

# 仅在需要转换 SVG 时查找工具；依赖由调用方安装，本入口不安装软件包。
tmp="$(mktemp)"
if command -v rsvg-convert >/dev/null 2>&1; then
  rsvg-convert -w 256 -h 256 "$src" -o "$tmp" || {
    rm -f -- "$tmp"
    die "SVG 转 PNG 失败：$src"
  }
elif command -v magick >/dev/null 2>&1; then
  magick -background none "$src" -resize 256x256 "PNG32:$tmp" || {
    rm -f -- "$tmp"
    die "SVG 转 PNG 失败：$src"
  }
elif command -v convert >/dev/null 2>&1; then
  convert -background none -resize 256x256 "$src" "PNG32:$tmp" || {
    rm -f -- "$tmp"
    die "SVG 转 PNG 失败：$src"
  }
else
  rm -f -- "$tmp"
  die "没有可用的 SVG 转 PNG 工具，需要 rsvg-convert、magick 或 convert；Ubuntu 构建环境可安装 librsvg2-bin（提供 rsvg-convert）。"
fi

actual="$(head -c 4 -- "$tmp" || true)"
if [[ ! -s "$tmp" || "$actual" != "$(printf '\x89PNG')" ]]; then
  rm -f -- "$tmp"
  die "SVG 转 PNG 结果不是 PNG：$src"
fi

place_png "$root_png"
mv -f -- "$tmp" "$root_png"
chmod 0644 -- "$root_png"
