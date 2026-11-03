#!/usr/bin/env bash
set -Eeuo pipefail

# 可选前缀只传给公共解析入口，不改变原有位置参数。
TAG_ARGS=()
if [[ "${1:-}" == --tag-prefix ]]; then
  (( $# >= 2 )) || {
    echo "用法：$0 [--tag-prefix <标签前缀>] <owner/repo> '<包含 {version} 的资产名模板>' <输出文件> [DEB 包名] [DEB 架构]" >&2
    exit 2
  }
  TAG_ARGS=("$1" "$2")
  shift 2
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RESOLVER="$SCRIPT_DIR/resolve_latest_stable_release_asset.sh"
DOWNLOAD_FILE="$SCRIPT_DIR/../download/download_file.sh"
REPO="${1:-}"
ASSET_TEMPLATE="${2:-}"
OUTPUT="${3:-}"
EXPECTED_DEB_PACKAGE="${4:-}"
EXPECTED_DEB_ARCHITECTURE="${5:-}"

[[ -n "$REPO" && -n "$ASSET_TEMPLATE" && -n "$OUTPUT" ]] || {
  echo "用法：$0 <owner/repo> '<包含 {version} 的资产名模板>' <输出文件> [DEB 包名] [DEB 架构]" >&2
  exit 1
}
if [[ "${4:-}" != --latest-with-checksum && ( -n "$EXPECTED_DEB_PACKAGE" || -n "$EXPECTED_DEB_ARCHITECTURE" ) ]]; then
  [[ -n "$EXPECTED_DEB_PACKAGE" && -n "$EXPECTED_DEB_ARCHITECTURE" ]] || {
    echo "错误：DEB 包名和架构必须同时提供。" >&2
    exit 1
  }
fi
[[ -x "$RESOLVER" ]] || {
  echo "错误：稳定 Release 解析入口不存在或不可执行：$RESOLVER" >&2
  exit 1
}
[[ -x "$DOWNLOAD_FILE" ]] || {
  echo "错误：公共下载入口不存在或不可执行：$DOWNLOAD_FILE" >&2
  exit 1
}

# 只有归档和清单双重校验通过后，才交付资产和对应 tag 的 commit。
if [[ "${4:-}" == --latest-with-checksum ]]; then
  (( ${#TAG_ARGS[@]} == 0 )) || {
    echo "错误：--tag-prefix 不能与 --latest-with-checksum 一起使用。" >&2
    exit 2
  }
  CHECKSUM_NAME="${5:-}"
  COMMIT_FILE="${6:-}"
  [[ $# == 6 && -n "$CHECKSUM_NAME" && -n "$COMMIT_FILE" && "$COMMIT_FILE" != "$OUTPUT" ]] || {
    echo "用法：$0 <owner/repo> <资产名模板> <输出文件> --latest-with-checksum <校验清单资产名> <commit 文件>" >&2
    exit 1
  }

  METADATA="$("$RESOLVER" "$REPO" "$ASSET_TEMPLATE" --latest-with-checksum "$CHECKSUM_NAME")"
  mapfile -t RELEASE_META <<< "$METADATA"
  [[ ${#RELEASE_META[@]} == 7 ]] || {
    echo "错误：无法解析同一正式 Release 的归档和校验清单：$REPO" >&2
    exit 1
  }
  VERSION="${RELEASE_META[0]}"
  ASSET_NAME="${RELEASE_META[6]}"
  RELEASE_TAG="${RELEASE_META[5]}"

  OUTPUT_DIR="$(dirname -- "$OUTPUT")"
  mkdir -p -- "$OUTPUT_DIR"
  WORK_DIR="$(mktemp -d "$OUTPUT_DIR/.release-asset.XXXXXX")"
  trap 'rm -rf -- "$WORK_DIR"' EXIT
  "$DOWNLOAD_FILE" "${RELEASE_META[1]}" "$WORK_DIR/archive" "${RELEASE_META[2]}" >&2
  "$DOWNLOAD_FILE" "${RELEASE_META[3]}" "$WORK_DIR/checksums" "${RELEASE_META[4]}" >&2

  EXPECTED_SHA256="$(awk -v name="$ASSET_NAME" '$2 == name || $2 == "*" name { print tolower($1); count++ } END { if (count != 1) exit 1 }' "$WORK_DIR/checksums")" || {
    echo "错误：校验清单未唯一列出 $ASSET_NAME。" >&2
    exit 1
  }
  [[ "$EXPECTED_SHA256" =~ ^[0-9a-f]{64}$ ]] || {
    echo "错误：校验清单中的 SHA-256 无效：$ASSET_NAME" >&2
    exit 1
  }
  ACTUAL_SHA256="$(sha256sum < "$WORK_DIR/archive")"
  [[ "${ACTUAL_SHA256%% *}" == "$EXPECTED_SHA256" ]] || {
    echo "错误：归档与官方校验清单的 SHA-256 不一致：$ASSET_NAME" >&2
    exit 1
  }

  REMOTE_REFS="$(git ls-remote "https://github.com/$REPO.git" "refs/tags/$RELEASE_TAG" "refs/tags/$RELEASE_TAG^{}")"
  RELEASE_COMMIT="$(awk -v ref="refs/tags/$RELEASE_TAG" '$2 == ref { tag=$1 } $2 == ref "^{}" { peeled=$1 } END { print (peeled == "" ? tag : peeled) }' <<< "$REMOTE_REFS")"
  [[ "$RELEASE_COMMIT" =~ ^[0-9a-f]{40}$ ]] || {
    echo "错误：无法把 Release tag 解析到有效 commit：$RELEASE_TAG" >&2
    exit 1
  }

  mv -fT -- "$WORK_DIR/archive" "$OUTPUT"
  printf '%s\n' "$RELEASE_COMMIT" > "$COMMIT_FILE"
  printf '%s\n' "$VERSION"
  exit
fi

# 统一解析正式 semver Release、唯一匹配资产和 GitHub SHA-256 digest。
mapfile -t RELEASE_META < <("$RESOLVER" "${TAG_ARGS[@]}" "$REPO" "$ASSET_TEMPLATE")
[[ ${#RELEASE_META[@]} -eq 3 ]] || {
  echo "错误：无法解析唯一的正式 Release 资产元数据：$REPO / $ASSET_TEMPLATE" >&2
  exit 1
}

VERSION="${RELEASE_META[0]}"
ASSET_URL="${RELEASE_META[1]}"
ASSET_SHA256="${RELEASE_META[2]}"

# 下载并校验解析到的同一资产；下载日志写入 stderr。
"$DOWNLOAD_FILE" "$ASSET_URL" "$OUTPUT" "$ASSET_SHA256" >&2

# 调用方明确传入 DEB 包名和架构时，在公共入口统一核对 DEB 身份与目标架构。
# Release 版本已经由资产名模板和 GitHub digest 绑定；不能假设 DEB Version 必须与 Release tag 完全相同。
if [[ -n "$EXPECTED_DEB_PACKAGE" ]]; then
  "$SCRIPT_DIR/../archive/check_deb_metadata.sh" "$OUTPUT" "" "$EXPECTED_DEB_PACKAGE" "$EXPECTED_DEB_ARCHITECTURE"
fi

# stdout 只返回版本供调用方复用。
printf '%s\n' "$VERSION"
