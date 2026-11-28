#!/usr/bin/env bash
set -Eeuo pipefail

# 根据仓库索引定位 Arch 二进制包，验签后安装并解包同一份文件。
if (( $# < 6 || $# > 7 )); then
  echo "用法：$0 <仓库 HTTPS 目录> <仓库名> <软件包名> <架构> <受信 pacman GPG 目录> <解包目录> [预期上游版本]" >&2
  exit 2
fi

REPO_URL="${1%/}"
REPO_NAME="$2"
PACKAGE_NAME="$3"
ARCH="$4"
GPG_DIR="$5"
OUTPUT_DIR="$6"
EXPECTED_VERSION="${7:-}"

if [[ ! "$REPO_URL" =~ ^https://[A-Za-z0-9][A-Za-z0-9.-]*(/[A-Za-z0-9._+-]+)*$ || "$REPO_URL" == *..* || "$REPO_URL/" == *"/./"* ||
      ! "$REPO_NAME" =~ ^[a-z0-9][a-z0-9_-]*$ || "$REPO_NAME" == options ||
      ! "$PACKAGE_NAME" =~ ^[a-z0-9][a-z0-9@._+-]*$ || "$PACKAGE_NAME" == *..* ||
      ! "$ARCH" =~ ^[A-Za-z0-9_]+$ || "$ARCH" != "$(uname -m)" ||
      -z "$GPG_DIR" || ! -d "$GPG_DIR" || -z "$OUTPUT_DIR" || -e "$OUTPUT_DIR" || -L "$OUTPUT_DIR" ]]; then
  echo "错误：请提供有效的 HTTPS 仓库、本机架构、受信 GPG 目录和尚不存在的解包目录。" >&2
  exit 2
fi
if (( EUID != 0 )); then
  echo "错误：请在具备软件包安装权限的 Arch 构建容器中运行。" >&2
  exit 1
fi

export LC_ALL=C
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GPG_DIR="$(cd -- "$GPG_DIR" && pwd -P)"
OUTPUT_NAME="$(basename -- "$OUTPUT_DIR")"
if [[ "$OUTPUT_NAME" == . || "$OUTPUT_NAME" == .. ]]; then
  echo "错误：解包目录不能以 . 或 .. 结尾。" >&2
  exit 2
fi

# 在输出目录旁建立临时工作区，全部步骤成功后才交付解包目录。
mkdir -p -- "$(dirname -- "$OUTPUT_DIR")"
OUTPUT_PARENT="$(cd -- "$(dirname -- "$OUTPUT_DIR")" && pwd -P)"
OUTPUT_DIR="$OUTPUT_PARENT/$OUTPUT_NAME"
WORK_DIR="$(mktemp -d "$OUTPUT_PARENT/.arch-signed-package.XXXXXXXX")"
# 退出时清理本次下载、查询配置和未交付的文件。
cleanup() {
  rm -rf -- "$WORK_DIR"
}
trap cleanup EXIT

# 用独立数据库读取索引。这里的索引只负责定位，信任依据是软件包的独立签名。
mkdir -p -- "$WORK_DIR/db/sync"
"$SCRIPT_DIR/../download/download_file.sh" "$REPO_URL/$REPO_NAME.db" "$WORK_DIR/db/sync/$REPO_NAME.db" >&2
printf '[options]\nArchitecture = %s\nSigLevel = PackageRequired DatabaseOptional TrustedOnly\n[%s]\nServer = %s\n' "$ARCH" "$REPO_NAME" "$REPO_URL" > "$WORK_DIR/query.conf"
INDEX_ENTRY="$(pacman --config "$WORK_DIR/query.conf" --dbpath "$WORK_DIR/db" --gpgdir "$GPG_DIR" \
  --sync --nodeps --nodeps --print --print-format '%n|%v|%a|%f|%h' -- "$REPO_NAME/$PACKAGE_NAME")"
IFS='|' read -r INDEX_NAME PACKAGE_VERSION PACKAGE_ARCH PACKAGE_FILE PACKAGE_SHA256 <<< "$INDEX_ENTRY"
if [[ "$INDEX_ENTRY" == *$'\n'* || "$INDEX_NAME" != "$PACKAGE_NAME" ||
      ! "$PACKAGE_VERSION" =~ ^([0-9]+:)?[A-Za-z0-9._+~]+-[0-9]+([.][0-9]+)*$ ||
      ( "$PACKAGE_ARCH" != "$ARCH" && "$PACKAGE_ARCH" != any ) ||
      ! "$PACKAGE_FILE" =~ ^[A-Za-z0-9@._+~-]+[.]pkg[.]tar[.]zst$ ||
      "$PACKAGE_FILE" != "$PACKAGE_NAME-"* || ! "$PACKAGE_SHA256" =~ ^[0-9a-fA-F]{64}$ ]]; then
  echo "错误：仓库索引没有给出唯一、完整且匹配的软件包记录。" >&2
  exit 1
fi
UPSTREAM_VERSION="${PACKAGE_VERSION#*:}"
UPSTREAM_VERSION="${UPSTREAM_VERSION%-*}"
if [[ -n "$EXPECTED_VERSION" && "$UPSTREAM_VERSION" != "$EXPECTED_VERSION" ]]; then
  printf '错误：仓库中的上游版本为 %s，期望 %s。\n' "$UPSTREAM_VERSION" "$EXPECTED_VERSION" >&2
  exit 1
fi

# 下载索引选中的软件包和独立签名，并核对包文件的 SHA-256。
PACKAGE_PATH="$WORK_DIR/$PACKAGE_FILE"
"$SCRIPT_DIR/../download/download_file.sh" "$REPO_URL/$PACKAGE_FILE" "$PACKAGE_PATH" "$PACKAGE_SHA256" >&2
"$SCRIPT_DIR/../download/download_file.sh" "$REPO_URL/$PACKAGE_FILE.sig" "$PACKAGE_PATH.sig" >&2

# 通过 pacman 校验本地包的受信签名，并核对签名覆盖的包名、版本和架构。
# 此配置使用正常的已安装包数据库，因此依赖必须由调用方提前安装。
printf '[options]\nArchitecture = %s\nSigLevel = Required TrustedOnly\nLocalFileSigLevel = Required TrustedOnly\n' "$ARCH" > "$WORK_DIR/install.conf"
SIGNED_ENTRY="$(pacman --config "$WORK_DIR/install.conf" --gpgdir "$GPG_DIR" --noconfirm \
  --upgrade --print --print-format '%n|%v|%a' -- "$PACKAGE_PATH")"
if [[ "$SIGNED_ENTRY" != "$PACKAGE_NAME|$PACKAGE_VERSION|$PACKAGE_ARCH" ]]; then
  echo "错误：签名包的身份与仓库索引记录不一致。" >&2
  exit 1
fi

# 在独立目录解包，再按同一验签策略安装同一文件。
"$SCRIPT_DIR/../archive/extract_archive.sh" "$PACKAGE_PATH" "$WORK_DIR/extracted" >&2
# 64 对应 ALPM_QUESTION_IMPORT_KEY，反转无人值守模式默认同意导入未知密钥的回答。
pacman --config "$WORK_DIR/install.conf" --gpgdir "$GPG_DIR" --ask 64 \
  --upgrade -- "$PACKAGE_PATH" >&2

# 一次性发布已验签包的解包内容，输出本次采用的上游版本。
mv -T --update=none-fail -- "$WORK_DIR/extracted" "$OUTPUT_DIR"
printf '%s\n' "$UPSTREAM_VERSION"
