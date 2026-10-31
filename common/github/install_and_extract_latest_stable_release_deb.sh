#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

###### 读取调用参数 ######

# 默认从 GitHub Release 下载，传入 --checksum 时改用官网校验清单。
DOWNLOAD_SOURCE=github
if [[ "${1:-}" == --checksum ]]; then
  DOWNLOAD_SOURCE=checksum
  shift
fi

# 根据下载来源检查参数数量，GitHub 模式保留可选的包名和架构校验。
if [[ "$DOWNLOAD_SOURCE" == github && $# -ne 4 && $# -ne 6 ]] || [[ "$DOWNLOAD_SOURCE" == checksum && $# -ne 4 ]]; then
  echo "用法：$0 <owner/repo> '<包含 {version} 的资产名模板>' <下载 DEB 路径> <解包目录> [DEB 包名] [DEB 架构]" >&2
  echo "用法：$0 --checksum <HTTPS 校验清单 URL> '<完整资产名正则>' <下载 DEB 路径> <解包目录>" >&2
  exit 1
fi

SOURCE_REF="$1"
ASSET_SELECTOR="$2"
DEB_FILE="$3"
OUTPUT_DIR="$4"
EXPECTED_DEB_PACKAGE="${5:-}"
EXPECTED_DEB_ARCHITECTURE="${6:-}"

###### 准备公共入口 ######

# 根据下载来源选用已有入口，安装和解包入口保持共用。
case "$DOWNLOAD_SOURCE" in
  github)
    DOWNLOAD_ASSET="$SCRIPT_DIR/download_latest_stable_release_asset.sh"
    ;;
  checksum)
    DOWNLOAD_ASSET="$SCRIPT_DIR/../download/download_latest_checksum_asset.sh"
    ;;
esac
INSTALL_PACKAGES="$SCRIPT_DIR/../apt/install_packages.sh"
EXTRACT_ARCHIVE="$SCRIPT_DIR/../archive/extract_archive.sh"

# 在下载或安装前检查本入口需要的参数，具体来源和摘要校验仍由下载入口负责。
if [[ -z "$SOURCE_REF" || -z "$ASSET_SELECTOR" || -z "$DEB_FILE" || -z "$OUTPUT_DIR" ]]; then
  echo "错误：下载来源、资产匹配规则、DEB 保存路径和解包目录不能为空。" >&2
  exit 1
fi
if [[ "$DEB_FILE" != *.deb ]]; then
  echo "错误：安装包保存路径必须以 .deb 结尾。" >&2
  exit 1
fi

# 统一转换为绝对路径，保证 APT 正确识别本地 DEB，并拒绝向根目录解包。
DEB_FILE="$(readlink -m -- "$DEB_FILE")"
OUTPUT_DIR="$(readlink -m -- "$OUTPUT_DIR")"
if [[ "$OUTPUT_DIR" == / ]]; then
  echo "错误：禁止把安装包解包到根目录。" >&2
  exit 1
fi

# 所需公共入口必须全部可执行，避免完成下载后才发现后续入口不可用。
for helper in "$DOWNLOAD_ASSET" "$INSTALL_PACKAGES" "$EXTRACT_ARCHIVE"; do
  if [[ ! -x "$helper" ]]; then
    echo "错误：公共入口不存在或不可执行：$helper" >&2
    exit 1
  fi
done

###### 下载、安装并解包 ######

# 下载并校验 DEB；GitHub 模式下可同时核对包名和架构。
case "$DOWNLOAD_SOURCE" in
  github)
    VERSION="$("$DOWNLOAD_ASSET" "$SOURCE_REF" "$ASSET_SELECTOR" "$DEB_FILE" "$EXPECTED_DEB_PACKAGE" "$EXPECTED_DEB_ARCHITECTURE")"
    ;;
  checksum)
    VERSION="$("$DOWNLOAD_ASSET" "$SOURCE_REF" "$ASSET_SELECTOR" "$DEB_FILE")"
    ;;
esac

# 构建依赖和 APT 索引须由调用方预先准备；安装时不重复更新索引，日志统一写入 stderr。
"$INSTALL_PACKAGES" --no-update "$DEB_FILE" >&2

# 将同一份已校验并安装的 DEB 按上游原始布局解包，日志统一写入 stderr。
"$EXTRACT_ARCHIVE" "$DEB_FILE" "$OUTPUT_DIR" >&2

# 只有下载、安装和解包全部成功后，才向 stdout 返回版本号。
printf '%s\n' "$VERSION"
