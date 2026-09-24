#!/usr/bin/env bash
set -Eeuo pipefail

# 从 AUR 当前 .SRCINFO 解析唯一的架构专用 DEB 来源，并输出已规范化的构建元数据。
if (( $# != 5 )); then
  echo "用法：$0 <AUR 包名> <架构> <工作目录> <元数据输出文件> <依赖输出文件>" >&2
  exit 2
fi

PACKAGE="$1"
ARCH="$2"
WORKDIR="$3"
METADATA_FILE="$4"
DEPENDENCIES_FILE="$5"

[[ "$PACKAGE" =~ ^[a-z0-9][a-z0-9@._+-]*$ && "$PACKAGE" != *..* ]] || {
  echo "错误：无效 AUR 包名：$PACKAGE" >&2
  exit 1
}
[[ "$ARCH" =~ ^[a-zA-Z0-9_]+$ ]] || {
  echo "错误：无效架构：$ARCH" >&2
  exit 1
}
[[ -d "$WORKDIR" && "$METADATA_FILE" != "$DEPENDENCIES_FILE" ]] || {
  echo "错误：工作目录不存在，或两个输出文件路径相同。" >&2
  exit 1
}

WORKDIR="$(cd -- "$WORKDIR" && pwd -P)"
AUR_DIR="$WORKDIR/$PACKAGE"

# 保留原有三次浅克隆和 HTTP/1.1 重试行为；只在公共入口维护。
for attempt in 1 2 3; do
  rm -rf -- "$AUR_DIR"
  if git -c http.version=HTTP/1.1 clone --depth=1 \
    "https://aur.archlinux.org/$PACKAGE.git" "$AUR_DIR"; then
    break
  fi
  if (( attempt == 3 )); then
    echo "错误：连续 3 次无法读取 AUR $PACKAGE 元数据。" >&2
    exit 1
  fi
  sleep $((attempt * 2))
done

SRCINFO="$AUR_DIR/.SRCINFO"
[[ -f "$SRCINFO" ]] || {
  echo "错误：AUR $PACKAGE 缺少 .SRCINFO。" >&2
  exit 1
}

# 多包 .SRCINFO 可能混合不同子包的依赖；本入口只处理与仓库名一致的单包。
mapfile -t PACKAGE_NAMES < <(
  awk -F ' = ' '{
    key=$1
    sub(/^[[:space:]]*/, "", key)
    if (key == "pkgname") print $2
  }' "$SRCINFO"
)
(( ${#PACKAGE_NAMES[@]} == 1 )) && [[ "${PACKAGE_NAMES[0]}" == "$PACKAGE" ]] || {
  echo "错误：AUR $PACKAGE 不是同名的单包 .SRCINFO。" >&2
  exit 1
}

# 本入口只接受唯一的架构专用 DEB；多来源需要明确配对，不能猜测第一个摘要。
mapfile -t SOURCES < <(
  awk -F ' = ' -v target="source_$ARCH" '{
    key=$1
    sub(/^[[:space:]]*/, "", key)
    if (key == target) print $2
  }' "$SRCINFO"
)
mapfile -t SHA256S < <(
  awk -F ' = ' -v target="sha256sums_$ARCH" '{
    key=$1
    sub(/^[[:space:]]*/, "", key)
    if (key == target) print $2
  }' "$SRCINFO"
)
(( ${#SOURCES[@]} == 1 && ${#SHA256S[@]} == 1 )) || {
  echo "错误：AUR $PACKAGE 的 $ARCH DEB 来源与 SHA-256 必须各有且仅有一项。" >&2
  exit 1
}

PACKAGE_VERSION="$(awk -F ' = ' '/^[[:space:]]*pkgver = / {print $2; exit}' "$SRCINFO")"
PACKAGE_REL="$(awk -F ' = ' '/^[[:space:]]*pkgrel = / {print $2; exit}' "$SRCINFO")"
SOURCE_URL="${SOURCES[0]#*::}"
EXPECTED_SHA256="${SHA256S[0]}"

[[ -n "$PACKAGE_VERSION" && -n "$PACKAGE_REL" ]] || {
  echo "错误：AUR $PACKAGE 缺少版本或 pkgrel。" >&2
  exit 1
}
[[ "$SOURCE_URL" == https://* && "$SOURCE_URL" == *.deb ]] || {
  echo "错误：AUR $PACKAGE 的 $ARCH 来源不是 HTTPS DEB：$SOURCE_URL" >&2
  exit 1
}
[[ "$EXPECTED_SHA256" =~ ^[[:xdigit:]]{64}$ ]] || {
  echo "错误：AUR $PACKAGE 的 $ARCH SHA-256 无效。" >&2
  exit 1
}

mkdir -p -- "$(dirname -- "$METADATA_FILE")" "$(dirname -- "$DEPENDENCIES_FILE")"
METADATA_TEMP="$(mktemp "${METADATA_FILE}.part.XXXXXX")"
DEPENDENCIES_TEMP="$(mktemp "${DEPENDENCIES_FILE}.part.XXXXXX")"
cleanup() {
  rm -f -- "$METADATA_TEMP" "$DEPENDENCIES_TEMP"
}
trap cleanup EXIT

# 只输出当前架构适用的运行依赖，保持调用方原有的去版本约束与排序结果。
awk -F ' = ' -v arch="$ARCH" '{
  key=$1
  sub(/^[[:space:]]*/, "", key)
  if (key == "depends" || key == "depends_" arch) print $2
}' "$SRCINFO" |
  sed -E 's/[<>=].*$//' |
  awk 'NF' |
  sort -u > "$DEPENDENCIES_TEMP"
[[ -s "$DEPENDENCIES_TEMP" ]] || {
  echo "错误：AUR $PACKAGE 没有解析到运行依赖。" >&2
  exit 1
}

# %q 保证元数据可安全地由 Bash source；最后写入元数据文件表示本次解析完成。
{
  printf 'PACKAGE_VERSION=%q\n' "$PACKAGE_VERSION"
  printf 'PACKAGE_REL=%q\n' "$PACKAGE_REL"
  printf 'SOURCE_URL=%q\n' "$SOURCE_URL"
  printf 'EXPECTED_SHA256=%q\n' "$EXPECTED_SHA256"
} > "$METADATA_TEMP"
mv -f -- "$DEPENDENCIES_TEMP" "$DEPENDENCIES_FILE"
mv -f -- "$METADATA_TEMP" "$METADATA_FILE"
trap - EXIT
