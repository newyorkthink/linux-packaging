#!/usr/bin/env bash
set -Eeuo pipefail

# 下载 GitHub 最新正式 Release 标签的源码；仅显式传入 --archive 时按提交下载源码归档。
# 只向 stdout 输出标签名。仓库和目标目录由调用方传入。

if (( $# < 2 || $# > 3 )) || [[ $# -eq 3 && "${3:-}" != --archive ]]; then
  echo "用法：$0 <owner/repo> <目标目录> [--archive]" >&2
  exit 2
fi

REPOSITORY="$1"
DEST="$2"
SOURCE_MODE="${3:-clone}"

case "$REPOSITORY" in
  *[!a-zA-Z0-9_./-]*|.*|*..*|/*|*/|*/*/*)
    echo "错误：无效仓库：$REPOSITORY" >&2
    exit 1
    ;;
esac
[[ "$REPOSITORY" == */* ]] || {
  echo "错误：无效仓库：$REPOSITORY" >&2
  exit 1
}
[[ -n "$DEST" && "$DEST" != -* ]] || {
  echo "错误：无效目标目录。" >&2
  exit 1
}
[[ ! -e "$DEST" ]] || {
  echo "错误：目标目录已存在：$DEST" >&2
  exit 1
}

for command_name in jq git; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "错误：缺少必需命令：$command_name" >&2
    exit 1
  }
done

ROOT="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
# shellcheck source=common/github/github_api.sh
source "$ROOT/common/github/github_api.sh"

# 归档模式要求现有认证凭据和解包工具，原两参数克隆模式不增加这些检查。
if [[ "$SOURCE_MODE" == --archive ]]; then
  [[ ! -L "$DEST" ]] || {
    echo "错误：目标目录已存在：$DEST" >&2
    exit 1
  }

  if [[ -z "${GITHUB_TOKEN:-}" && -z "${GH_TOKEN:-}" ]]; then
    CHECKOUT_AUTH_HEADER="$(git config --get http.https://github.com/.extraheader 2>/dev/null || true)"
    if [[ "${CHECKOUT_AUTH_HEADER,,}" != authorization:* ||
          ! "${CHECKOUT_AUTH_HEADER#*:}" =~ [^[:space:]] ]]; then
      echo "错误：归档模式缺少 GitHub 认证凭据。" >&2
      exit 1
    fi
  fi

  for command_name in curl tar mktemp sha256sum mv basename dirname; do
    command -v "$command_name" >/dev/null 2>&1 || {
      echo "错误：归档模式缺少必需命令：$command_name" >&2
      exit 1
    }
  done
fi

RELEASE_JSON="$(github_api_get "https://api.github.com/repos/$REPOSITORY/releases/latest")"
TAG="$(printf '%s\n' "$RELEASE_JSON" | jq -er '
  select(type == "object" and .draft == false and .prerelease == false)
  | .tag_name
  | select(type == "string" and test("^[vV]?[0-9]+([.][0-9]+){2}([._+-][0-9A-Za-z]+)*$"))
')" || {
  echo "错误：无法解析最新正式版本：$REPOSITORY" >&2
  exit 1
}

# 仅显式归档模式解析标签对应的提交，再按该不可变提交下载并解包。
if [[ "$SOURCE_MODE" == --archive ]]; then
  # 读取 Git 引用或附注标签指向的对象，只接受提交或标签及有效的完整 SHA。
  read_git_object() {
    github_api_get "$1" | jq -er '
      .object
      | select(type == "object")
      | select(.type == "commit" or .type == "tag")
      | select(.sha | type == "string")
      | select(.sha | test("^[0-9a-f]{40}$"))
      | [.type, .sha]
      | @tsv
    '
  }

  # 从精确标签引用开始解析，避免把同名分支当成 Release 标签。
  GIT_OBJECT="$(read_git_object "https://api.github.com/repos/$REPOSITORY/git/ref/tags/$TAG")" || {
    echo "错误：无法解析正式 Release 标签引用：$REPOSITORY $TAG" >&2
    exit 1
  }
  IFS=$'\t' read -r OBJECT_TYPE COMMIT <<< "$GIT_OBJECT"

  # 逐级解析附注标签；重复遇到同一标签对象时停止，避免循环请求。
  SEEN_TAG_OBJECTS=" "
  while [[ "$OBJECT_TYPE" == tag ]]; do
    if [[ "$SEEN_TAG_OBJECTS" == *" $COMMIT "* ]]; then
      echo "错误：正式 Release 标签存在循环引用：$REPOSITORY $TAG" >&2
      exit 1
    fi
    SEEN_TAG_OBJECTS+="$COMMIT "
    GIT_OBJECT="$(read_git_object "https://api.github.com/repos/$REPOSITORY/git/tags/$COMMIT")" || {
      echo "错误：无法把正式 Release 标签解析到提交：$REPOSITORY $TAG" >&2
      exit 1
    }
    IFS=$'\t' read -r OBJECT_TYPE COMMIT <<< "$GIT_OBJECT"
  done

  # 在目标目录的上级创建临时目录，使最终源码可以在同一文件系统内移动。
  DEST_NAME="$(basename -- "$DEST")"
  [[ "$DEST_NAME" != . && "$DEST_NAME" != .. ]] || {
    echo "错误：无效目标目录。" >&2
    exit 1
  }
  DEST_PARENT="$(dirname -- "$DEST")"
  mkdir -p -- "$DEST_PARENT"
  DEST_PARENT="$(cd -- "$DEST_PARENT" && pwd -P)"
  DEST="$DEST_PARENT/$DEST_NAME"
  [[ ! -e "$DEST" && ! -L "$DEST" ]] || {
    echo "错误：目标目录已存在：$DEST" >&2
    exit 1
  }
  SOURCE_WORKDIR="$(mktemp -d "$DEST_PARENT/.github-source.XXXXXXXX")"
  trap 'rm -rf -- "$SOURCE_WORKDIR"' EXIT
  SOURCE_ARCHIVE="$SOURCE_WORKDIR/source.tar.gz"
  UNPACK_DIR="$SOURCE_WORKDIR/unpacked"

  # 记录本次实际使用的正式标签和完整提交，日志不混入 stdout 标签返回。
  printf '源码标签：%s\n源码提交：%s\n' "$TAG" "$COMMIT" >&2

  # 通过现有认证 API 入口下载该提交的源码归档，不使用匿名备用地址。
  github_api_get "https://api.github.com/repos/$REPOSITORY/tarball/$COMMIT" "$SOURCE_ARCHIVE"

  # 记录实际归档的 SHA-256，供构建日志审计，不冒充官方摘要比对。
  sha256sum -- "$SOURCE_ARCHIVE" >&2

  # 通用归档解包仍由现有公共入口负责，解包日志写入 stderr。
  "$ROOT/common/archive/extract_archive.sh" "$SOURCE_ARCHIVE" "$UNPACK_DIR" >&2

  # 官方源码归档应只有一个顶层目录；交付其完整内容，不依赖顶层目录名称。
  shopt -s nullglob dotglob
  SOURCE_ENTRIES=("$UNPACK_DIR"/*)
  SOURCE_ROOT="${SOURCE_ENTRIES[0]:-}"
  if [[ ${#SOURCE_ENTRIES[@]} -ne 1 || ! -d "$SOURCE_ROOT" || -L "$SOURCE_ROOT" ]]; then
    echo "错误：源码归档未包含唯一的顶层目录。" >&2
    exit 1
  fi

  # 源码准备完成后才交付目标；目标途中出现时也不覆盖其内容。
  mv -T --no-clobber -- "$SOURCE_ROOT" "$DEST"
  if [[ -e "$SOURCE_ROOT" ]]; then
    echo "错误：目标目录已在准备期间被创建：$DEST" >&2
    exit 1
  fi

  # 删除本次归档和临时目录，成功后仅返回原始 Release 标签。
  rm -rf -- "$SOURCE_WORKDIR"
  trap - EXIT
  printf '%s\n' "$TAG"
  exit 0
fi

git clone --depth 1 --branch "$TAG" "https://github.com/$REPOSITORY.git" "$DEST" >&2
printf '%s\n' "$TAG"
