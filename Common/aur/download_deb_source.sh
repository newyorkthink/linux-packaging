#!/usr/bin/env bash
set -Eeuo pipefail

# 定位现有的 AUR 来源解析和公共下载入口。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 保留原三个位置参数；额外能力由调用方明确启用。
if (( $# < 3 )) || [[ -z "$1" || -z "$2" || -z "$3" ]]; then
  echo "用法：$0 <AUR 包名> <架构> <DEB 输出文件> [--user-agent <客户端标识>] [--downloader curl|wget|aria2c] [--wayback] [--fallback-origin <HTTPS 源站>] [--deb] [--version-file <文件>] [--package-version-file <文件>] [--makepkg-source-dir <目录>] [--source-filename <DEB 文件名>]" >&2
  exit 2
fi
AUR_PACKAGE="$1"
AUR_ARCH="$2"
OUTPUT="$3"
shift 3
USER_AGENT=""
DOWNLOADER=""
USE_WAYBACK=false
FALLBACK_ORIGIN=""
CHECK_DEB=false
VERSION_FILE=""
PACKAGE_VERSION_FILE=""
MAKEPKG_SOURCE_DIR=""
SELECTED_FILENAME=""

# 只解析本入口新增的可选参数，旧调用不改变下载方式或输出。
while (( $# > 0 )); do
  case "$1" in
    --downloader)
      if (( $# < 2 )) || [[ -n "$DOWNLOADER" || ( "$2" != curl && "$2" != wget && "$2" != aria2c ) ]]; then
        echo "错误：--downloader 需要唯一的 curl、wget 或 aria2c。" >&2
        exit 2
      fi
      DOWNLOADER="$2"
      shift 2
      ;;
    --user-agent|--version-file|--package-version-file|--makepkg-source-dir|--source-filename)
      (( $# >= 2 )) && [[ -n "$2" && "$2" != --* ]] || {
        echo "错误：$1 需要一个非空参数。" >&2
        exit 2
      }
      case "$1" in
        --user-agent) target=USER_AGENT ;;
        --version-file) target=VERSION_FILE ;;
        --package-version-file) target=PACKAGE_VERSION_FILE ;;
        --makepkg-source-dir) target=MAKEPKG_SOURCE_DIR ;;
        --source-filename) target=SELECTED_FILENAME ;;
      esac
      [[ -z "${!target}" ]] || {
        echo "错误：$1 不得重复指定。" >&2
        exit 2
      }
      printf -v "$target" '%s' "$2"
      shift 2
      ;;
    --fallback-origin)
      (( $# >= 2 )) && [[ "$2" =~ ^https://[[:alnum:]]([[:alnum:].-]*[[:alnum:]])?$ ]] && [[ -z "$FALLBACK_ORIGIN" ]] || {
        echo "错误：--fallback-origin 需要唯一的 HTTPS 源站，仅包含协议和域名。" >&2
        exit 2
      }
      FALLBACK_ORIGIN="$2"
      shift 2
      ;;
    --wayback|--deb)
      if [[ "$1" == --wayback ]]; then
        [[ "$USE_WAYBACK" == false ]] || {
          echo "错误：--wayback 不得重复指定。" >&2
          exit 2
        }
        USE_WAYBACK=true
      else
        [[ "$CHECK_DEB" == false ]] || {
          echo "错误：--deb 不得重复指定。" >&2
          exit 2
        }
        CHECK_DEB=true
      fi
      shift
      ;;
    *)
      echo "错误：不支持的参数：$1" >&2
      exit 2
      ;;
  esac
done

[[ -z "$FALLBACK_ORIGIN" || "$USE_WAYBACK" == true ]] || {
  echo "错误：--fallback-origin 需要与 --wayback 一起使用。" >&2
  exit 2
}

# 缓存目录是调用方显式提供的独立输出，不改变默认下载目标。
if [[ -n "$MAKEPKG_SOURCE_DIR" ]]; then
  MAKEPKG_SOURCE_DIR="$(readlink -m -- "$MAKEPKG_SOURCE_DIR")"
  [[ "$MAKEPKG_SOURCE_DIR" != / && ! -f "$MAKEPKG_SOURCE_DIR" ]] || {
    echo "错误：makepkg 来源缓存必须是非根目录。" >&2
    exit 2
  }
fi

# 在联网和创建临时目录前拒绝无效请求头及相互覆盖的输出路径。
[[ "$USER_AGENT" != *$'\r'* && "$USER_AGENT" != *$'\n'* ]] || {
  echo "错误：User-Agent 不得包含换行符。" >&2
  exit 2
}
OUTPUT_CANONICAL="$(readlink -m -- "$OUTPUT")"
METADATA_PATHS=()
for metadata_path in "$VERSION_FILE" "$PACKAGE_VERSION_FILE"; do
  [[ -n "$metadata_path" ]] || continue
  canonical="$(readlink -m -- "$metadata_path")"
  [[ "$canonical" != / && "$canonical" != "$OUTPUT_CANONICAL" && ! -d "$metadata_path" ]] || {
    echo "错误：版本输出不能是目录或与 DEB 输出重合：$metadata_path" >&2
    exit 2
  }
  for existing in "${METADATA_PATHS[@]}"; do
    [[ "$canonical" != "$existing" ]] || {
      echo "错误：两个版本输出不能指向同一文件。" >&2
      exit 2
    }
  done
  METADATA_PATHS+=("$canonical")
done

# 新选项只复用对应的公共能力，不安装软件或在此复制归档逻辑。
if [[ "$USE_WAYBACK" == true ]]; then
  [[ -x "$SCRIPT_DIR/../download/download_verified_with_wayback.sh" ]] || {
    echo "错误：缺少公共归档下载入口。" >&2
    exit 1
  }
fi
if [[ "$CHECK_DEB" == true || -n "$VERSION_FILE$PACKAGE_VERSION_FILE" ]]; then
  [[ -x "$SCRIPT_DIR/../archive/check_deb_metadata.sh" ]] || {
    echo "错误：缺少公共 DEB 元数据校验入口。" >&2
    exit 1
  }
fi

# 为本次解析创建独立的临时目录，避免把中间元数据留在应用目录。
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/aur-deb-download.XXXXXXXX")"
METADATA_TEMPS=()
SOURCE_CACHE_TEMP=""

# 无论成功或失败，都只清理本次创建的临时目录。
cleanup() {
  rm -rf -- "$work_dir"
  if (( ${#METADATA_TEMPS[@]} > 0 )); then
    rm -f -- "${METADATA_TEMPS[@]}"
  fi
  [[ -z "$SOURCE_CACHE_TEMP" ]] || rm -f -- "$SOURCE_CACHE_TEMP"
}
trap cleanup EXIT

# 从当前 .SRCINFO 取得默认或显式选中的 DEB 地址及对应摘要。
RESOLVE_OPTIONS=()
[[ -z "$SELECTED_FILENAME" ]] || RESOLVE_OPTIONS+=(--source-filename "$SELECTED_FILENAME")
[[ -z "$MAKEPKG_SOURCE_DIR" ]] || RESOLVE_OPTIONS+=(--with-source-filename)
"$SCRIPT_DIR/resolve_deb_source.sh" "$AUR_PACKAGE" "$AUR_ARCH" "$work_dir" "$work_dir/source.env" "$work_dir/dependencies.txt" "${RESOLVE_OPTIONS[@]}"

# 载入已经由公共解析入口转义的元数据，不在调用方重复解析来源。
source "$work_dir/source.env"

# 原文件名只来自同次 .SRCINFO；禁止让缓存文件覆盖版本元数据。
if [[ -n "$MAKEPKG_SOURCE_DIR" ]]; then
  SOURCE_CACHE_FILE="$MAKEPKG_SOURCE_DIR/$SOURCE_FILENAME"
  for existing in "${METADATA_PATHS[@]}"; do
    [[ "$SOURCE_CACHE_FILE" != "$existing" ]] || {
      echo "错误：makepkg 来源缓存不能与版本输出重合。" >&2
      exit 2
    }
  done
fi

# 使用公共下载入口校验指定算法的摘要，并在成功后原子写入调用方指定的文件。
if [[ "$USE_WAYBACK" == true ]]; then
  DOWNLOAD_OPTIONS=()
  [[ "$CHECK_DEB" == false ]] || DOWNLOAD_OPTIONS+=(--deb)
  [[ -z "$USER_AGENT" ]] || DOWNLOAD_OPTIONS+=(--user-agent "$USER_AGENT")
  [[ -z "$DOWNLOADER" ]] || DOWNLOAD_OPTIONS+=(--downloader "$DOWNLOADER")
  [[ -z "$FALLBACK_ORIGIN" ]] || DOWNLOAD_OPTIONS+=(--fallback-origin "$FALLBACK_ORIGIN")
  "$SCRIPT_DIR/../download/download_verified_with_wayback.sh" "$SOURCE_URL" "$OUTPUT" "$SOURCE_CHECKSUM" "${DOWNLOAD_OPTIONS[@]}"
elif [[ -n "$DOWNLOADER" ]]; then
  "$SCRIPT_DIR/../download/download_file.sh" "$SOURCE_URL" "$OUTPUT" "$SOURCE_CHECKSUM" "$USER_AGENT" "$DOWNLOADER"
elif [[ -n "$USER_AGENT" ]]; then
  "$SCRIPT_DIR/../download/download_file.sh" "$SOURCE_URL" "$OUTPUT" "$SOURCE_CHECKSUM" "$USER_AGENT"
else
  "$SCRIPT_DIR/../download/download_file.sh" "$SOURCE_URL" "$OUTPUT" "$SOURCE_CHECKSUM"
fi

# 仅在请求 DEB 检查或版本输出时，核对实际 DEB 的完整版本与同次 AUR 元数据一致。
if [[ "$CHECK_DEB" == true || -n "$VERSION_FILE$PACKAGE_VERSION_FILE" ]]; then
  "$SCRIPT_DIR/../archive/check_deb_metadata.sh" "$OUTPUT" "$PACKAGE_VERSION" "" ""
fi

# 所有校验通过后才原子写入显式请求的来源缓存。
if [[ -n "$MAKEPKG_SOURCE_DIR" ]]; then
  mkdir -p -- "$MAKEPKG_SOURCE_DIR"
  SOURCE_CACHE_TEMP="$(mktemp "$MAKEPKG_SOURCE_DIR/.source.part.XXXXXX")"
  # makepkg 由非 root 用户执行，只向显式缓存输出提供可读的公共安装包。
  install -m 644 -- "$OUTPUT" "$SOURCE_CACHE_TEMP"
  mv -f -- "$SOURCE_CACHE_TEMP" "$SOURCE_CACHE_FILE"
  SOURCE_CACHE_TEMP=""
fi

# 版本文件仍按原有显式选项写入。
for metadata_path in "$VERSION_FILE" "$PACKAGE_VERSION_FILE"; do
  [[ -n "$metadata_path" ]] || continue
  mkdir -p -- "$(dirname -- "$metadata_path")"
  metadata_temp="$(mktemp "${metadata_path}.part.XXXXXX")"
  METADATA_TEMPS+=("$metadata_temp")
  if [[ "$metadata_path" == "$VERSION_FILE" ]]; then
    printf '%s\n' "$PACKAGE_VERSION" > "$metadata_temp"
  else
    printf '%s\n' "$PACKAGE_VERSION-$PACKAGE_REL" > "$metadata_temp"
  fi
done
metadata_index=0
for metadata_path in "$VERSION_FILE" "$PACKAGE_VERSION_FILE"; do
  [[ -n "$metadata_path" ]] || continue
  mv -f -- "${METADATA_TEMPS[$metadata_index]}" "$metadata_path"
  metadata_index=$((metadata_index + 1))
done
