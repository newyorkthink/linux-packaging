#!/usr/bin/env bash
set -Eeuo pipefail

# 从指定 GitHub Release 归档标签按固定名或 {version} 模板选择最高版本（或指定/限定前缀版本）资产并校验下载。
# 可显式使用 GitHub 指定的正式最新版，并从同一次响应选择校验清单。
EXPECTED_SHA256=""
RELEASE_TAG_OUTPUT=""
while [[ "${1:-}" == --sha256 || "${1:-}" == --release-tag-file ]]; do
  (( $# >= 2 )) && [[ -n "$2" && "$2" != --* ]] || {
    echo "错误：$1 缺少参数。" >&2
    exit 2
  }
  case "$1" in
    --sha256)
      [[ -z "$EXPECTED_SHA256" && "$2" =~ ^[0-9a-fA-F]{64}$ ]] || {
        echo "错误：--sha256 需要唯一的官方 SHA-256。" >&2
        exit 2
      }
      EXPECTED_SHA256="${2,,}"
      ;;
    --release-tag-file)
      [[ -z "$RELEASE_TAG_OUTPUT" ]] || {
        echo "错误：--release-tag-file 只能指定一次。" >&2
        exit 2
      }
      RELEASE_TAG_OUTPUT="$2"
      ;;
  esac
  shift 2
done

USE_LATEST=false
CHECKSUM_ASSET=""
if [[ "${1:-}" == --latest ]]; then
  USE_LATEST=true
  shift
fi
if [[ "${1:-}" == --checksum-asset ]]; then
  (( $# >= 2 )) && [[ "$2" =~ ^[A-Za-z0-9][A-Za-z0-9_.+-]*$ && "$2" != *..* ]] || {
    echo "错误：--checksum-asset 需要一个有效的校验清单资产名。" >&2
    exit 2
  }
  CHECKSUM_ASSET="$2"
  shift 2
fi

PINNED_VERSION=""
VERSION_PREFIX=""
if [[ "${1:-}" == --version ]]; then
  (( $# >= 2 )) && [[ -n "$2" ]] || {
    echo "用法：$0 [--version <精确版本> | --version-prefix <版本前缀>] <owner/repo> <归档标签> '<固定资产名或含 {version} 的资产名模板>' <输出文件> [DEB 包名] [DEB 架构]" >&2
    exit 2
  }
  PINNED_VERSION="$2"
  shift 2
elif [[ "${1:-}" == --version-prefix ]]; then
  (( $# >= 2 )) && [[ -n "$2" ]] || {
    echo "用法：$0 [--version <精确版本> | --version-prefix <版本前缀>] <owner/repo> <归档标签> '<固定资产名或含 {version} 的资产名模板>' <输出文件> [DEB 包名] [DEB 架构]" >&2
    exit 2
  }
  VERSION_PREFIX="$2"
  shift 2
fi

POSITIONAL_COUNT=4
if [[ "$USE_LATEST" == true ]]; then
  POSITIONAL_COUNT=3
fi
if (( $# != POSITIONAL_COUNT && $# != POSITIONAL_COUNT + 2 )); then
  echo "用法：$0 [--sha256 <官方 SHA-256>] [--release-tag-file <标签文件>] [--latest] [--checksum-asset <清单资产名>] [--version <精确版本> | --version-prefix <版本前缀>] <owner/repo> [归档标签] '<资产名模板>' <输出文件> [DEB 包名] [DEB 架构]" >&2
  echo "仅在使用 --latest 时省略归档标签。" >&2
  exit 2
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GITHUB_API="$SCRIPT_DIR/github_api.sh"
DOWNLOAD_FILE="$SCRIPT_DIR/../download/download_file.sh"
CHECK_DEB_METADATA="$SCRIPT_DIR/../archive/check_deb_metadata.sh"

REPO="$1"
shift
RELEASE_TAG=""
if [[ "$USE_LATEST" == false ]]; then
  RELEASE_TAG="$1"
  shift
fi
ASSET_TEMPLATE="$1"
OUTPUT="$2"
EXPECTED_DEB_PACKAGE="${3:-}"
EXPECTED_DEB_ARCHITECTURE="${4:-}"

[[ -r "$GITHUB_API" ]] || {
  echo "错误：GitHub API 公共脚本不存在：$GITHUB_API" >&2
  exit 1
}
[[ -x "$DOWNLOAD_FILE" ]] || {
  echo "错误：公共下载入口不存在或不可执行：$DOWNLOAD_FILE" >&2
  exit 1
}
[[ "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || {
  echo "错误：GitHub 仓库名无效：$REPO" >&2
  exit 2
}
[[ "$USE_LATEST" == true || ( "$RELEASE_TAG" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ && "$RELEASE_TAG" != *..* ) ]] || {
  echo "错误：归档标签无效：$RELEASE_TAG" >&2
  exit 2
}
[[ -n "$ASSET_TEMPLATE" && "$ASSET_TEMPLATE" != *..* && "$ASSET_TEMPLATE" =~ ^[A-Za-z0-9_.+~{}-]+$ ]] || {
  echo "错误：资产名模板无效：$ASSET_TEMPLATE" >&2
  exit 2
}
if [[ "$ASSET_TEMPLATE" == *'{'* || "$ASSET_TEMPLATE" == *'}'* ]]; then
  TEMPLATE_PREFIX="${ASSET_TEMPLATE%%'{version}'*}"
  TEMPLATE_SUFFIX="${ASSET_TEMPLATE#*'{version}'}"
  [[ "$TEMPLATE_PREFIX" != "$ASSET_TEMPLATE" && "$TEMPLATE_PREFIX" != *'{'* && "$TEMPLATE_PREFIX" != *'}'* && "$TEMPLATE_SUFFIX" != *'{'* && "$TEMPLATE_SUFFIX" != *'}'* ]] || {
    echo "错误：资产名模板最多只允许包含一个 {version} 占位符：$ASSET_TEMPLATE" >&2
    exit 2
  }
fi
if [[ -n "$EXPECTED_SHA256" && ( "$USE_LATEST" == true || "$ASSET_TEMPLATE" == *'{version}'* || -n "$CHECKSUM_ASSET" ) ]]; then
  echo "错误：--sha256 只用于固定标签和固定资产名，不得与 --checksum-asset 同用。" >&2
  exit 2
fi
if [[ -n "$PINNED_VERSION" ]]; then
  [[ "$ASSET_TEMPLATE" == *'{version}'* ]] || {
    echo "错误：使用 --version 时资产名模板必须包含 {version}：$ASSET_TEMPLATE" >&2
    exit 2
  }
  [[ "$PINNED_VERSION" =~ ^[0-9][0-9A-Za-z.+:~-]*$ && "$PINNED_VERSION" != *..* ]] || {
    echo "错误：--version 指定的版本号无效：$PINNED_VERSION" >&2
    exit 2
  }
fi
if [[ -n "$VERSION_PREFIX" ]]; then
  [[ "$ASSET_TEMPLATE" == *'{version}'* ]] || {
    echo "错误：使用 --version-prefix 时资产名模板必须包含 {version}：$ASSET_TEMPLATE" >&2
    exit 2
  }
  [[ "$VERSION_PREFIX" =~ ^[0-9][0-9A-Za-z.+:~-]*$ && "$VERSION_PREFIX" != *..* ]] || {
    echo "错误：--version-prefix 指定的版本前缀无效：$VERSION_PREFIX" >&2
    exit 2
  }
fi
[[ -n "$OUTPUT" && "$OUTPUT" != */ && ! -d "$OUTPUT" ]] || {
  echo "错误：输出文件路径无效：$OUTPUT" >&2
  exit 2
}
if [[ -n "$EXPECTED_DEB_PACKAGE" ]]; then
  [[ -x "$CHECK_DEB_METADATA" ]] || {
    echo "错误：公共 DEB 校验入口不存在或不可执行：$CHECK_DEB_METADATA" >&2
    exit 1
  }
  [[ "$EXPECTED_DEB_PACKAGE" =~ ^[a-z0-9][a-z0-9+.-]*$ && "$EXPECTED_DEB_ARCHITECTURE" =~ ^[a-z0-9][a-z0-9+.-]*$ ]] || {
    echo "错误：DEB 包名或架构无效：$EXPECTED_DEB_PACKAGE / $EXPECTED_DEB_ARCHITECTURE" >&2
    exit 2
  }
fi

for command_name in curl python3 sha256sum; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "错误：缺少必需命令：$command_name" >&2
    exit 1
  }
done
if [[ -n "$EXPECTED_DEB_PACKAGE" ]]; then
  for command_name in dpkg dpkg-deb; do
    command -v "$command_name" >/dev/null 2>&1 || {
      echo "错误：DEB 校验缺少必需命令：$command_name" >&2
      exit 1
    }
  done
fi

# 所有 GitHub API 请求必须具备有效身份认证，禁止匿名回退。
AUTH_HEADER=""
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  AUTH_HEADER="Authorization: Bearer $GITHUB_TOKEN"
elif [[ -n "${GH_TOKEN:-}" ]]; then
  AUTH_HEADER="Authorization: Bearer $GH_TOKEN"
elif command -v git >/dev/null 2>&1; then
  AUTH_HEADER="$(git config --get http.https://github.com/.extraheader 2>/dev/null || true)"
fi
[[ -n "$AUTH_HEADER" ]] || {
  echo "错误：查询 GitHub Release 归档资产需要有效的 GitHub 认证凭据。" >&2
  exit 1
}

# shellcheck source=Common/github/github_api.sh
source "$GITHUB_API"

OUTPUT_DIR="$(dirname -- "$OUTPUT")"
mkdir -p -- "$OUTPUT_DIR"
OUTPUT_DIR="$(cd -- "$OUTPUT_DIR" && pwd -P)"
OUTPUT="$OUTPUT_DIR/$(basename -- "$OUTPUT")"

if [[ -n "$RELEASE_TAG_OUTPUT" ]]; then
  if [[ "$RELEASE_TAG_OUTPUT" == */ || -d "$RELEASE_TAG_OUTPUT" ||
    "$(realpath -m -- "$RELEASE_TAG_OUTPUT")" == "$(realpath -m -- "$OUTPUT")" ]]; then
    echo "错误：标签文件和资产文件必须使用不同的有效路径。" >&2
    exit 2
  fi
  mkdir -p -- "$(dirname -- "$RELEASE_TAG_OUTPUT")"
fi

RELEASE_JSON="$(mktemp "$OUTPUT_DIR/.release-meta.XXXXXXXX")"
TEMP_FILE="$(mktemp "$OUTPUT_DIR/.release-asset.XXXXXXXX")"
CHECKSUM_FILE=""
TAG_TEMP=""
# 清理本次 Release 查询及下载产生的临时文件。
cleanup() {
  rm -f -- "$RELEASE_JSON" "$TEMP_FILE"
  if [[ -n "$CHECKSUM_FILE" ]]; then
    rm -f -- "$CHECKSUM_FILE"
  fi
  if [[ -n "$TAG_TEMP" ]]; then
    rm -f -- "$TAG_TEMP"
  fi
}
trap cleanup EXIT

# 通过统一认证入口读取同一份 Release 元数据。
RELEASE_SELECTOR="tags/$RELEASE_TAG"
if [[ "$USE_LATEST" == true ]]; then
  RELEASE_SELECTOR=latest
fi
github_api_get "https://api.github.com/repos/$REPO/releases/$RELEASE_SELECTOR" "$RELEASE_JSON"

# 从同一份 Release 响应中筛选已上传且带官方 SHA-256 的最高版本（或指定版本）唯一资产。
mapfile -t RESOLVED < <(
  python3 - "$RELEASE_JSON" "$REPO" "$RELEASE_TAG" "$ASSET_TEMPLATE" "$EXPECTED_DEB_PACKAGE" "$PINNED_VERSION" "$VERSION_PREFIX" "$CHECKSUM_ASSET" "$EXPECTED_SHA256" <<'PY'
import functools
import json
import re
import subprocess
import sys
from urllib.parse import quote


def fail(message):
    raise SystemExit(f"错误：{message}")


def compare_deb_versions(left, right):
    for relation, result in (("lt", -1), ("gt", 1)):
        status = subprocess.run(
            ["dpkg", "--compare-versions", left, relation, right], check=False,
        ).returncode
        if status == 0:
            return result
        if status != 1:
            fail(f"归档资产版本号不符合 Debian 规则：{left} / {right}")
    return 0


def version_key(value):
    return [
        (0, int(token)) if token.isdigit() else (1, token)
        for token in re.findall(r"[0-9]+|[A-Za-z]+|[^0-9A-Za-z]+", value)
    ]


def compare_generic_versions(left, right):
    left_key = version_key(left)
    right_key = version_key(right)
    if left_key < right_key:
        return -1
    if left_key > right_key:
        return 1
    return 0


json_path, repo, tag, template, deb_package, pinned_version, version_prefix, checksum_name, expected_sha256 = sys.argv[1:]
with open(json_path, encoding="utf-8") as stream:
    release = json.load(stream)

if (
    not isinstance(release, dict)
    or release.get("draft") is not False
    or release.get("prerelease") is not False
    or not isinstance(release.get("tag_name"), str)
    or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", release["tag_name"])
    or ".." in release["tag_name"]
    or (tag and release["tag_name"] != tag)
):
    fail(f"目标 Release 标签不是正式非草稿归档：{repo} / {tag}")

tag = release["tag_name"]

has_version = "{version}" in template
if has_version:
    prefix, suffix = template.split("{version}", 1)
    if pinned_version:
        pattern = re.compile(
            r"^" + re.escape(prefix) + r"(?P<version>" + re.escape(pinned_version) + r")" + re.escape(suffix) + r"$"
        )
    else:
        pattern = re.compile(
            r"^" + re.escape(prefix) + r"(?P<version>[0-9][0-9A-Za-z.+:~-]*)" + re.escape(suffix) + r"$"
        )
else:
    pattern = re.compile(r"^" + re.escape(template) + r"$")

candidates = []
checksums = []
for asset in release.get("assets") or []:
    if not isinstance(asset, dict):
        continue
    name = asset.get("name")
    if not isinstance(name, str) or ".." in name or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.+~:-]*", name):
        continue
    is_checksum = bool(checksum_name and name == checksum_name)
    match = pattern.fullmatch(name)
    if not is_checksum and not match:
        continue
    if asset.get("state") != "uploaded":
        continue
    asset_id = asset.get("id")
    if not isinstance(asset_id, int) or isinstance(asset_id, bool) or asset_id <= 0:
        continue
    url = asset.get("browser_download_url")
    expected_urls = {
        f"https://github.com/{repo}/releases/download/{tag}/{name}",
        f"https://github.com/{repo}/releases/download/{quote(tag, safe='')}/{quote(name, safe='')}",
    }
    if url not in expected_urls:
        continue
    digest = asset.get("digest")
    if expected_sha256 and digest is None:
        # 历史资产的 API 缺少摘要时，只采用调用方从上游取得的固定官方摘要。
        sha256 = expected_sha256
    elif isinstance(digest, str) and re.fullmatch(r"sha256:[0-9a-fA-F]{64}", digest):
        sha256 = digest.split(":", 1)[1].lower()
        if expected_sha256 and sha256 != expected_sha256:
            fail(f"发布方提供的 SHA-256 与 GitHub 资产摘要不一致：{name}")
    elif expected_sha256:
        fail(f"GitHub 资产摘要格式无效：{name}")
    else:
        continue
    if is_checksum:
        checksums.append((name, url, sha256, str(asset_id)))
        continue
    extracted_version = match.group("version") if has_version else ""
    if version_prefix and not extracted_version.startswith(version_prefix):
        continue
    if has_version and deb_package:
        if subprocess.run(["dpkg", "--validate-version", extracted_version], check=False).returncode != 0:
            fail(f"归档 DEB 文件名版本无效：{name}")
    candidates.append((extracted_version, name, url, sha256, str(asset_id)))

if not candidates:
    fail(f"归档 Release {repo}@{tag} 中没有符合模板且带有效 SHA-256 的已上传资产：{template}")

if not has_version or pinned_version:
    if len(candidates) != 1:
        fail(f"归档 Release {repo}@{tag} 中匹配目标资产不唯一：{template}")
    selected = candidates[0]
else:
    comparator = compare_deb_versions if deb_package else compare_generic_versions
    selected = max(candidates, key=functools.cmp_to_key(lambda a, b: comparator(a[0], b[0])))
    tied = [item for item in candidates if comparator(item[0], selected[0]) == 0]
    if len(tied) != 1:
        fail(f"归档 Release {repo}@{tag} 中最高版本资产不唯一：{template}")

if checksum_name and len(checksums) != 1:
    fail(f"Release {repo}@{tag} 中缺少唯一且带官方 SHA-256 的校验清单：{checksum_name}")

metadata = (*selected, *checksums[0]) if checksum_name else selected
for value in (*metadata, tag):
    print(value)
PY
)

METADATA_COUNT=6
if [[ -n "$CHECKSUM_ASSET" ]]; then
  METADATA_COUNT=10
fi
(( ${#RESOLVED[@]} == METADATA_COUNT )) || {
  echo "错误：无法解析归档 Release 资产元数据：$REPO / $RELEASE_TAG / $ASSET_TEMPLATE" >&2
  exit 1
}

EXTRACTED_VERSION="${RESOLVED[0]}"
ASSET_NAME="${RESOLVED[1]}"
ASSET_URL="${RESOLVED[2]}"
ASSET_SHA256="${RESOLVED[3]}"
ASSET_ID="${RESOLVED[4]}"

[[ "$ASSET_SHA256" =~ ^[0-9a-f]{64}$ && "$ASSET_ID" =~ ^[1-9][0-9]*$ ]] || {
  echo "错误：归档资产摘要或 ID 无效：$ASSET_NAME" >&2
  exit 1
}

# 先尝试官方 Release 直链并校验官方 SHA-256，失败后使用同一资产 ID 通过认证 API 回退并校验同一 SHA-256。
download_release_asset() {
  local ASSET_NAME="$1" ASSET_URL="$2" ASSET_SHA256="$3" ASSET_ID="$4" TEMP_FILE="$5"
  if ! "$DOWNLOAD_FILE" "$ASSET_URL" "$TEMP_FILE" "$ASSET_SHA256" >&2; then
    echo "官方 Release 直链下载失败，改用认证 API 按同一资产 ID 回退：$ASSET_NAME" >&2
    rm -f -- "$TEMP_FILE"
    curl --fail --show-error --location --proto '=https' --tlsv1.2 \
      --retry 3 --retry-delay 2 --connect-timeout 20 --max-time 900 \
      -H 'Accept: application/octet-stream' \
      -H "$AUTH_HEADER" \
      -H 'X-GitHub-Api-Version: 2022-11-28' \
      "https://api.github.com/repos/$REPO/releases/assets/$ASSET_ID" \
      --output "$TEMP_FILE"
    printf '%s  %s\n' "$ASSET_SHA256" "$TEMP_FILE" | sha256sum -c - >&2
  fi
}

# 下载并校验所选主资产。
download_release_asset "$ASSET_NAME" "$ASSET_URL" "$ASSET_SHA256" "$ASSET_ID" "$TEMP_FILE"

if [[ -n "$CHECKSUM_ASSET" ]]; then
  # 下载同一 Release 中的校验清单，核对清单的官方摘要。
  CHECKSUM_FILE="$(mktemp "$OUTPUT_DIR/.release-checksum.XXXXXXXX")"
  download_release_asset "${RESOLVED[5]}" "${RESOLVED[6]}" "${RESOLVED[7]}" "${RESOLVED[8]}" "$CHECKSUM_FILE"

  # 在交付前，核对清单中唯一对应主资产的 SHA-256。
  python3 - "$CHECKSUM_FILE" "$ASSET_NAME" "$ASSET_SHA256" <<'PY'
import sys

checksum_path, asset_name, expected = sys.argv[1:]
matches = []
with open(checksum_path, encoding="utf-8") as stream:
    for line in stream:
        fields = line.rstrip("\r\n").split(maxsplit=1)
        if len(fields) == 2 and fields[1].removeprefix("*") == asset_name:
            matches.append(fields[0].lower())
if matches != [expected]:
    raise SystemExit(f"错误：校验清单没有为 {asset_name} 提供唯一且一致的 SHA-256。")
PY
fi

# 传入 DEB 包名和架构时，核对 DEB 身份与包内版本。
if [[ -n "$EXPECTED_DEB_PACKAGE" ]]; then
  "$CHECK_DEB_METADATA" "$TEMP_FILE" "" "$EXPECTED_DEB_PACKAGE" "$EXPECTED_DEB_ARCHITECTURE"
  DEB_VERSION="$(dpkg-deb -f "$TEMP_FILE" Version)"
  dpkg --validate-version "$DEB_VERSION"
  if [[ -n "$EXTRACTED_VERSION" && "$DEB_VERSION" != "$EXTRACTED_VERSION" ]]; then
    echo "错误：归档 DEB 包内版本（$DEB_VERSION）与文件名版本（$EXTRACTED_VERSION）不一致：$ASSET_NAME" >&2
    exit 1
  fi
  FINAL_VERSION="$DEB_VERSION"
else
  FINAL_VERSION="${EXTRACTED_VERSION:-$ASSET_NAME}"
fi

if [[ -n "$RELEASE_TAG_OUTPUT" ]]; then
  TAG_TEMP="$(mktemp -- "${RELEASE_TAG_OUTPUT}.part.XXXXXXXX")"
  printf '%s\n' "${RESOLVED[METADATA_COUNT-1]}" > "$TAG_TEMP"
fi
mv -fT -- "$TEMP_FILE" "$OUTPUT"
if [[ -n "$TAG_TEMP" ]]; then
  mv -fT -- "$TAG_TEMP" "$RELEASE_TAG_OUTPUT"
fi
cleanup
trap - EXIT
printf '%s\n' "$FINAL_VERSION"
