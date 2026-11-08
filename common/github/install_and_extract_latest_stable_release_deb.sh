#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

###### 读取调用参数 ######

# 默认从 GitHub Release 下载，传入 --checksum 或 --html-checksum 时改用官网校验来源。
DOWNLOAD_SOURCE=github
RELEASE_TAG=""
if [[ "${1:-}" == --release-tag ]]; then
  (( $# >= 3 )) || {
    echo "用法：$0 --release-tag <标签> <owner/repo> <固定资产名> <下载 DEB 路径> <解包目录>" >&2
    exit 2
  }
  RELEASE_TAG="$2"
  DOWNLOAD_SOURCE=tagged-release
  shift 2
elif [[ "${1:-}" == --checksum ]]; then
  DOWNLOAD_SOURCE=checksum
  shift
elif [[ "${1:-}" == --html-checksum ]]; then
  DOWNLOAD_SOURCE=html-checksum
  shift
fi

# HTML 校验来源可显式指定 JSON 中保存表格的字段，其他下载模式不受影响。
HTML_SOURCE_ARGS=()
if [[ "$DOWNLOAD_SOURCE" == html-checksum && "${1:-}" == --json-html ]]; then
  [[ -n "${2:-}" ]] || {
    echo "错误：--json-html 需要指定 HTML 字段。" >&2
    exit 1
  }
  HTML_SOURCE_ARGS=(--json-html "$2")
  shift 2
fi

# 根据下载来源检查参数数量，GitHub 模式保留可选的包名和架构校验。
if [[ ( "$DOWNLOAD_SOURCE" == github || "$DOWNLOAD_SOURCE" == tagged-release ) && $# -ne 4 && $# -ne 6 ]] || [[ "$DOWNLOAD_SOURCE" == checksum && $# -ne 4 ]] || [[ "$DOWNLOAD_SOURCE" == html-checksum && $# -ne 5 && $# -ne 7 ]]; then
  echo "用法：$0 <owner/repo> '<包含 {version} 的资产名模板>' <下载 DEB 路径> <解包目录> [DEB 包名] [DEB 架构]" >&2
  echo "用法：$0 --release-tag <标签> <owner/repo> <固定资产名> <下载 DEB 路径> <解包目录> [DEB 包名] [DEB 架构]" >&2
  echo "用法：$0 --checksum <HTTPS 校验清单 URL> '<完整资产名正则>' <下载 DEB 路径> <解包目录>" >&2
  echo "用法：$0 --html-checksum [--json-html <JSON HTML 字段>] <HTTPS 校验来源 URL> '<完整资产名的 Python 正则>' <HTTPS 资产目录 URL> <下载 DEB 路径> <解包目录> [DEB 包名] [DEB 架构]" >&2
  exit 1
fi

SOURCE_REF="$1"
ASSET_SELECTOR="$2"

# HTML 来源额外接收资产目录，移除该参数后复用原有 DEB 参数布局。
if [[ "$DOWNLOAD_SOURCE" == html-checksum ]]; then
  ASSET_BASE_URL="$3"
  set -- "$1" "$2" "${@:4}"
fi
DEB_FILE="$3"
OUTPUT_DIR="$4"
EXPECTED_DEB_PACKAGE="${5:-}"
EXPECTED_DEB_ARCHITECTURE="${6:-}"

###### 准备公共入口 ######

# 根据下载来源选用已有入口，安装和解包入口保持共用。
case "$DOWNLOAD_SOURCE" in
  github|tagged-release)
    DOWNLOAD_ASSET="$SCRIPT_DIR/download_latest_stable_release_asset.sh"
    ;;
  checksum)
    DOWNLOAD_ASSET="$SCRIPT_DIR/../download/download_latest_checksum_asset.sh"
    ;;
  html-checksum)
    DOWNLOAD_ASSET="$SCRIPT_DIR/../download/download_html_checksum_asset.sh"
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
  tagged-release)
    VERSION="$("$DOWNLOAD_ASSET" --release-tag "$RELEASE_TAG" "$SOURCE_REF" "$ASSET_SELECTOR" "$DEB_FILE" "$EXPECTED_DEB_PACKAGE" "$EXPECTED_DEB_ARCHITECTURE")"
    ;;
  checksum)
    VERSION="$("$DOWNLOAD_ASSET" "$SOURCE_REF" "$ASSET_SELECTOR" "$DEB_FILE")"
    ;;
  html-checksum)
    VERSION="$("$DOWNLOAD_ASSET" "${HTML_SOURCE_ARGS[@]}" "$SOURCE_REF" "$ASSET_SELECTOR" "$ASSET_BASE_URL" "$DEB_FILE")"
    ;;
esac

# HTML 来源在系统安装前核对 DEB 实际版本，并按调用参数核对包名和架构。
if [[ "$DOWNLOAD_SOURCE" == html-checksum ]]; then
  "$SCRIPT_DIR/../archive/check_deb_metadata.sh" "$DEB_FILE" "$VERSION" "$EXPECTED_DEB_PACKAGE" "$EXPECTED_DEB_ARCHITECTURE"
fi

# 构建依赖和 APT 索引须由调用方预先准备；安装时不重复更新索引，日志统一写入 stderr。
"$INSTALL_PACKAGES" --no-update "$DEB_FILE" >&2

# 将同一份已校验并安装的 DEB 按上游原始布局解包，日志统一写入 stderr。
"$EXTRACT_ARCHIVE" "$DEB_FILE" "$OUTPUT_DIR" >&2

# 只有下载、安装和解包全部成功后，才向 stdout 返回版本号。
printf '%s\n' "$VERSION"
