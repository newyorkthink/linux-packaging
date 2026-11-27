#!/usr/bin/env bash
set -Eeuo pipefail

# 从指定 GitHub Release 归档标签按固定名或 {version} 模板选择最高版本（或指定/限定前缀版本）资产并校验下载。
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

if (( $# != 4 && $# != 6 )); then
  echo "用法：$0 [--version <精确版本> | --version-prefix <版本前缀>] <owner/repo> <归档标签> '<固定资产名或含 {version} 的资产名模板>' <输出文件> [DEB 包名] [DEB 架构]" >&2
  exit 2
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GITHUB_API="$SCRIPT_DIR/github_api.sh"
DOWNLOAD_FILE="$SCRIPT_DIR/../download/download_file.sh"
CHECK_DEB_METADATA="$SCRIPT_DIR/../archive/check_deb_metadata.sh"

REPO="$1"
RELEASE_TAG="$2"
ASSET_TEMPLATE="$3"
OUTPUT="$4"
EXPECTED_DEB_PACKAGE="${5:-}"
EXPECTED_DEB_ARCHITECTURE="${6:-}"

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
[[ "$RELEASE_TAG" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ && "$RELEASE_TAG" != *..* ]] || {
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

RELEASE_JSON="$(mktemp "$OUTPUT_DIR/.release-meta.XXXXXXXX")"
TEMP_FILE="$(mktemp "$OUTPUT_DIR/.release-asset.XXXXXXXX")"
cleanup() {
  rm -f -- "$RELEASE_JSON" "$TEMP_FILE"
}
trap cleanup EXIT

# 通过统一认证入口读取指定归档标签的 Release 元数据。
github_api_get "https://api.github.com/repos/$REPO/releases/tags/$RELEASE_TAG" "$RELEASE_JSON"

# 从同一份 Release 响应中筛选已上传且带官方 SHA-256 的最高版本（或指定版本）唯一资产。
mapfile -t RESOLVED < <(
  python3 - "$RELEASE_JSON" "$REPO" "$RELEASE_TAG" "$ASSET_TEMPLATE" "$EXPECTED_DEB_PACKAGE" "$PINNED_VERSION" "$VERSION_PREFIX" <<'PY'
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


json_path, repo, tag, template, deb_package, pinned_version, version_prefix = sys.argv[1:8]
with open(json_path, encoding="utf-8") as stream:
    release = json.load(stream)

if (
    not isinstance(release, dict)
    or release.get("draft") is not False
    or release.get("prerelease") is not False
    or release.get("tag_name") != tag
):
    fail(f"目标 Release 标签不是正式非草稿归档：{repo} / {tag}")

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
for asset in release.get("assets") or []:
    if not isinstance(asset, dict):
        continue
    name = asset.get("name")
    if not isinstance(name, str) or ".." in name or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.+~:-]*", name):
        continue
    match = pattern.fullmatch(name)
    if not match:
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
    digest = asset.get("digest") or ""
    if not isinstance(digest, str) or not re.fullmatch(r"sha256:[0-9a-fA-F]{64}", digest):
        continue
    extracted_version = match.group("version") if has_version else ""
    if version_prefix and not extracted_version.startswith(version_prefix):
        continue
    if has_version and deb_package:
        if subprocess.run(["dpkg", "--validate-version", extracted_version], check=False).returncode != 0:
            fail(f"归档 DEB 文件名版本无效：{name}")
    candidates.append((extracted_version, name, url, digest.split(":", 1)[1].lower(), str(asset_id)))

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

for value in selected:
    print(value)
PY
)

(( ${#RESOLVED[@]} == 5 )) || {
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

mv -f -- "$TEMP_FILE" "$OUTPUT"
rm -f -- "$RELEASE_JSON"
trap - EXIT
printf '%s\n' "$FINAL_VERSION"
