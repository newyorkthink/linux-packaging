#!/usr/bin/env bash
set -Eeuo pipefail

# 从 AUR 当前 .SRCINFO 解析唯一的架构专用 DEB 来源，并输出已规范化的构建元数据。
if (( $# < 5 )); then
  echo "用法：$0 <AUR 包名> <架构> <工作目录> <元数据输出文件> <依赖输出文件> [--with-source-filename] [--source-filename <DEB 文件名>]" >&2
  exit 2
fi

PACKAGE="$1"
ARCH="$2"
WORKDIR="$3"
METADATA_FILE="$4"
DEPENDENCIES_FILE="$5"
WITH_SOURCE_FILENAME=false
SELECTED_FILENAME=""
shift 5

# 保留原有文件名输出选项，只有显式指定文件名时才解析多来源配方。
while (( $# > 0 )); do
  case "$1" in
    --with-source-filename)
      if [[ "$WITH_SOURCE_FILENAME" == true ]]; then
        echo "错误：--with-source-filename 不得重复指定。" >&2
        exit 2
      fi
      WITH_SOURCE_FILENAME=true
      shift
      ;;
    --source-filename)
      if (( $# < 2 )) || [[ -n "$SELECTED_FILENAME" || "$2" != *.deb || "$2" == --* || "$2" == */* || "$2" == *$'\r'* || "$2" == *$'\n'* ]]; then
        echo "错误：--source-filename 需要唯一的 DEB 文件名，可用 {version} 代表 pkgver。" >&2
        exit 2
      fi
      SELECTED_FILENAME="$2"
      shift 2
      ;;
    *)
      echo "错误：不支持的来源选项：$1" >&2
      exit 2
      ;;
  esac
done

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

PACKAGE_VERSION="$(awk -F ' = ' '/^[[:space:]]*pkgver = / {print $2; exit}' "$SRCINFO")"
PACKAGE_REL="$(awk -F ' = ' '/^[[:space:]]*pkgrel = / {print $2; exit}' "$SRCINFO")"

if [[ -n "$SELECTED_FILENAME" ]]; then
  # 从同次快照展开版本占位符，再按 makepkg 的实际缓存文件名精确匹配。
  SELECTED_FILENAME="${SELECTED_FILENAME//\{version\}/"$PACKAGE_VERSION"}"
  if [[ -z "$PACKAGE_VERSION" || "$SELECTED_FILENAME" == */* || "$SELECTED_FILENAME" == *$'\r'* || "$SELECTED_FILENAME" == *$'\n'* ]]; then
    echo "错误：无法展开安全的 AUR DEB 文件名。" >&2
    exit 1
  fi

  read_source_values() {
    awk -F ' = ' -v target="$1" '{
      key=$1
      sub(/^[[:space:]]*/, "", key)
      if (key == target) print substr($0, index($0, " = ") + 3)
    }' "$SRCINFO"
  }

  SOURCES=()
  SHA256S=()
  SHA512S=()
  # 通用来源和当前架构来源分别按原索引配对，其他架构不参与选择。
  for suffix in "" "_$ARCH"; do
    mapfile -t group_sources < <(read_source_values "source$suffix")
    for index in "${!group_sources[@]}"; do
      entry="${group_sources[index]}"
      if [[ "$entry" == *::* ]]; then
        filename="${entry%%::*}"
      else
        filename="${entry##*/}"
      fi
      [[ "$filename" == "$SELECTED_FILENAME" ]] || continue
      SOURCES+=("$entry")

      mapfile -t group_sha256 < <(read_source_values "sha256sums$suffix")
      if (( ${#group_sha256[@]} > 0 )); then
        if (( ${#group_sha256[@]} != ${#group_sources[@]} )); then
          echo "错误：AUR $PACKAGE 的 sha256sums$suffix 与来源数量不一致。" >&2
          exit 1
        fi
        SHA256S+=("${group_sha256[index]}")
      else
        mapfile -t group_sha512 < <(read_source_values "sha512sums$suffix")
        if (( ${#group_sha512[@]} != ${#group_sources[@]} )); then
          echo "错误：AUR $PACKAGE 的 sha512sums$suffix 与来源数量不一致。" >&2
          exit 1
        fi
        SHA512S+=("${group_sha512[index]}")
      fi
    done
  done
  if (( ${#SOURCES[@]} != 1 )); then
    echo "错误：AUR $PACKAGE 的 DEB 文件名必须唯一匹配：$SELECTED_FILENAME" >&2
    exit 1
  fi
else
  # 本入口只接受唯一的架构专用 DEB；优先沿用 SHA-256，缺少时才读取对应 SHA-512。
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
  mapfile -t SHA512S < <(
    awk -F ' = ' -v target="sha512sums_$ARCH" '{
      key=$1
      sub(/^[[:space:]]*/, "", key)
      if (key == target) print $2
    }' "$SRCINFO"
  )
fi
(( ${#SOURCES[@]} == 1 && ${#SHA256S[@]} <= 1 && (${#SHA256S[@]} == 1 || ${#SHA512S[@]} == 1) )) || {
  echo "错误：AUR $PACKAGE 的 $ARCH DEB 来源必须唯一，并有对应的唯一 SHA-256 或 SHA-512。" >&2
  exit 1
}

SOURCE_URL="${SOURCES[0]#*::}"

[[ -n "$PACKAGE_VERSION" && -n "$PACKAGE_REL" ]] || {
  echo "错误：AUR $PACKAGE 缺少版本或 pkgrel。" >&2
  exit 1
}
[[ "$SOURCE_URL" == https://* && "$SOURCE_URL" == *.deb ]] || {
  echo "错误：AUR $PACKAGE 的 $ARCH 来源不是 HTTPS DEB：$SOURCE_URL" >&2
  exit 1
}

# 仅为请求 makepkg 缓存的调用保留原始文件名，兼容 source 中的名称::URL 别名。
if [[ "$WITH_SOURCE_FILENAME" == true ]]; then
  if [[ "${SOURCES[0]}" == *::* ]]; then
    SOURCE_FILENAME="${SOURCES[0]%%::*}"
  else
    SOURCE_FILENAME="${SOURCE_URL##*/}"
  fi
  [[ -n "$SOURCE_FILENAME" && "$SOURCE_FILENAME" != . && "$SOURCE_FILENAME" != .. && "$SOURCE_FILENAME" != */* && "$SOURCE_FILENAME" != *$'\r'* && "$SOURCE_FILENAME" != *$'\n'* ]] || {
    echo "错误：AUR 来源缓存文件名必须是安全的单个文件名。" >&2
    exit 1
  }
fi

# 保留 SHA-256 的既有校验规则，不因 SHA-512 存在而回退无效或 SKIP 的 SHA-256。
if (( ${#SHA256S[@]} == 1 )); then
  EXPECTED_SHA256="${SHA256S[0]}"
  [[ "$EXPECTED_SHA256" =~ ^[[:xdigit:]]{64}$ ]] || {
    echo "错误：AUR $PACKAGE 的 $ARCH SHA-256 无效。" >&2
    exit 1
  }
  SOURCE_CHECKSUM="sha256:$EXPECTED_SHA256"
else
  EXPECTED_SHA512="${SHA512S[0]}"
  [[ "$EXPECTED_SHA512" =~ ^[[:xdigit:]]{128}$ ]] || {
    echo "错误：AUR $PACKAGE 的 $ARCH SHA-512 无效。" >&2
    exit 1
  }
  SOURCE_CHECKSUM="sha512:$EXPECTED_SHA512"
fi

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
  if (( ${#SHA256S[@]} == 1 )); then
    printf 'EXPECTED_SHA256=%q\n' "$EXPECTED_SHA256"
  fi
  printf 'SOURCE_CHECKSUM=%q\n' "$SOURCE_CHECKSUM"
  if [[ "$WITH_SOURCE_FILENAME" == true ]]; then
    printf 'SOURCE_FILENAME=%q\n' "$SOURCE_FILENAME"
  fi
} > "$METADATA_TEMP"
mv -f -- "$DEPENDENCIES_TEMP" "$DEPENDENCIES_FILE"
mv -f -- "$METADATA_TEMP" "$METADATA_FILE"
trap - EXIT
