#!/usr/bin/env bash
set -Eeuo pipefail

# 定位现有的 AUR 来源解析和公共下载入口。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 保留原三个位置参数；额外能力由调用方明确启用。
if (( $# < 3 )) || [[ -z "$1" || -z "$2" || -z "$3" ]]; then
  echo "用法：$0 <AUR 包名> <架构> <DEB 输出文件> [--user-agent <客户端标识>] [--wayback] [--deb] [--version-file <文件>] [--package-version-file <文件>]" >&2
  exit 2
fi
AUR_PACKAGE="$1"
AUR_ARCH="$2"
OUTPUT="$3"
shift 3
USER_AGENT=""
USE_WAYBACK=false
CHECK_DEB=false
VERSION_FILE=""
PACKAGE_VERSION_FILE=""

# 只解析本入口新增的可选参数，旧调用不改变下载方式或输出。
while (( $# > 0 )); do
  case "$1" in
    --user-agent|--version-file|--package-version-file)
      (( $# >= 2 )) && [[ -n "$2" && "$2" != --* ]] || {
        echo "错误：$1 需要一个非空参数。" >&2
        exit 2
      }
      case "$1" in
        --user-agent) target=USER_AGENT ;;
        --version-file) target=VERSION_FILE ;;
        --package-version-file) target=PACKAGE_VERSION_FILE ;;
      esac
      [[ -z "${!target}" ]] || {
        echo "错误：$1 不得重复指定。" >&2
        exit 2
      }
      printf -v "$target" '%s' "$2"
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

# 无论成功或失败，都只清理本次创建的临时目录。
cleanup() {
  rm -rf -- "$work_dir"
  if (( ${#METADATA_TEMPS[@]} > 0 )); then
    rm -f -- "${METADATA_TEMPS[@]}"
  fi
}
trap cleanup EXIT

# 从当前 .SRCINFO 取得唯一的架构专用 DEB 地址和对应的完整摘要。
"$SCRIPT_DIR/resolve_deb_source.sh" "$AUR_PACKAGE" "$AUR_ARCH" "$work_dir" "$work_dir/source.env" "$work_dir/dependencies.txt"

# 载入已经由公共解析入口转义的元数据，不在调用方重复解析来源。
source "$work_dir/source.env"

# 使用公共下载入口校验指定算法的摘要，并在成功后原子写入调用方指定的文件。
if [[ "$USE_WAYBACK" == true ]]; then
  DOWNLOAD_OPTIONS=()
  [[ "$CHECK_DEB" == false ]] || DOWNLOAD_OPTIONS+=(--deb)
  [[ -z "$USER_AGENT" ]] || DOWNLOAD_OPTIONS+=(--user-agent "$USER_AGENT")
  "$SCRIPT_DIR/../download/download_verified_with_wayback.sh" "$SOURCE_URL" "$OUTPUT" "$SOURCE_CHECKSUM" "${DOWNLOAD_OPTIONS[@]}"
elif [[ -n "$USER_AGENT" ]]; then
  "$SCRIPT_DIR/../download/download_file.sh" "$SOURCE_URL" "$OUTPUT" "$SOURCE_CHECKSUM" "$USER_AGENT"
else
  "$SCRIPT_DIR/../download/download_file.sh" "$SOURCE_URL" "$OUTPUT" "$SOURCE_CHECKSUM"
fi

# 仅在请求 DEB 检查或版本输出时，核对实际 DEB 的完整版本与同次 AUR 元数据一致。
if [[ "$CHECK_DEB" == true || -n "$VERSION_FILE$PACKAGE_VERSION_FILE" ]]; then
  "$SCRIPT_DIR/../archive/check_deb_metadata.sh" "$OUTPUT" "$PACKAGE_VERSION" "" ""
fi

# 所有校验通过后才准备版本文件；先完成全部临时写入，再替换目标文件。
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
