#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 来源、输出位置和预期 DEB 身份全部由调用方明确指定。
if (( $# != 7 )) || [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" || -z "$6" || -z "$7" ]]; then
  echo "用法：$0 <AUR 包名> <AUR 架构> <来源工作目录> <下载 DEB 路径> <解包目录> <DEB 包名> <DEB 架构>" >&2
  exit 2
fi
AUR_PACKAGE="$1"
AUR_ARCH="$2"
SOURCE_DIR="$(readlink -m -- "$3")"
DEB_FILE="$(readlink -m -- "$4")"
APPDIR="$(readlink -m -- "$5")"
EXPECTED_DEB_PACKAGE="$6"
EXPECTED_DEB_ARCHITECTURE="$7"

# 工作目录由调用方提前准备，DEB 保留扩展名；拒绝向根目录或来源目录解包。
if [[ ! -d "$SOURCE_DIR" || "$SOURCE_DIR" == / || "$DEB_FILE" != *.deb || "$APPDIR" == / || "$APPDIR" == "$SOURCE_DIR" ]]; then
  echo "错误：来源工作目录必须已存在且不是根目录，DEB 路径须以 .deb 结尾，解包目录不能是根目录或来源工作目录。" >&2
  exit 2
fi

# 在联网和系统安装前确认组合流程需要的公共入口全部可执行。
RESOLVE_SOURCE="$SCRIPT_DIR/resolve_deb_source.sh"
DOWNLOAD_FILE="$SCRIPT_DIR/../download/download_file.sh"
READ_VERSION="$SCRIPT_DIR/../build/read_app_version.sh"
CHECK_DEB="$SCRIPT_DIR/../archive/check_deb_metadata.sh"
INSTALL_PACKAGES="$SCRIPT_DIR/../apt/install_packages.sh"
EXTRACT_ARCHIVE="$SCRIPT_DIR/../archive/extract_archive.sh"
for helper in "$RESOLVE_SOURCE" "$DOWNLOAD_FILE" "$READ_VERSION" "$CHECK_DEB" "$INSTALL_PACKAGES" "$EXTRACT_ARCHIVE"; do
  [[ -x "$helper" ]] || {
    echo "错误：公共入口不存在或不可执行：$helper" >&2
    exit 1
  }
done

# 保留同次 AUR 快照、来源元数据和依赖清单，不执行 PKGBUILD 或 makepkg。
"$RESOLVE_SOURCE" "$AUR_PACKAGE" "$AUR_ARCH" "$SOURCE_DIR" "$SOURCE_DIR/source.env" "$SOURCE_DIR/dependencies.txt" >&2

# 加载公共解析入口已安全转义的来源元数据。
source "$SOURCE_DIR/source.env"

# 下载同一官方 DEB，摘要算法及完整摘要沿用本次 AUR 元数据。
"$DOWNLOAD_FILE" "$SOURCE_URL" "$DEB_FILE" "$SOURCE_CHECKSUM" >&2

# 读取本次打包使用的版本。
VERSION="$("$READ_VERSION" command dpkg-deb --field 1 -- -f "$DEB_FILE" Version)"

# 安装前精确核对 DEB 与来源版本、预期包名及预期架构是否一致。
"$CHECK_DEB" "$DEB_FILE" "$PACKAGE_VERSION" "$EXPECTED_DEB_PACKAGE" "$EXPECTED_DEB_ARCHITECTURE" >&2

# 构建依赖和 APT 索引由调用方提前准备，安装同一份已校验的本地 DEB。
"$INSTALL_PACKAGES" --no-update "$DEB_FILE" >&2

# 按官方原始布局解包同一份 DEB，应用专属目录调整留给调用方处理。
"$EXTRACT_ARCHIVE" "$DEB_FILE" "$APPDIR" >&2

# 下载、校验、安装和解包全部成功后，只向 stdout 返回实际软件版本。
printf '%s\n' "$VERSION"
