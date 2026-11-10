#!/usr/bin/env bash
set -Eeuo pipefail

# 显式安装 AUR 应用并导出同次下载的原始源文件，普通安装调用保持原样。
if [[ "${1:-}" == --aur-source ]]; then
  shift
  if (( $# < 6 )); then
    echo "用法：$0 --aur-source <AUR 包名> <架构> <源文件名模板> <源文件输出> <版本文件> -- [额外软件包...]" >&2
    exit 2
  fi
  AUR_PACKAGE="$1"
  AUR_ARCH="$2"
  SOURCE_PATTERN="$3"
  SOURCE_OUTPUT="$4"
  VERSION_OUTPUT="$5"
  shift 5
  SOURCE_LITERAL="${SOURCE_PATTERN//\{version\}/}"
  if [[ ! "$AUR_PACKAGE" =~ ^[a-z0-9][a-z0-9@._+-]*$ || "$AUR_PACKAGE" == *..* ||
    ! "$AUR_ARCH" =~ ^[a-zA-Z0-9_]+$ || ! "$SOURCE_LITERAL" =~ ^[A-Za-z0-9._+-]+$ ||
    "$SOURCE_LITERAL" == . || "$SOURCE_LITERAL" == .. ||
    -z "$SOURCE_OUTPUT" || "$SOURCE_OUTPUT" == / || -d "$SOURCE_OUTPUT" ||
    -z "$VERSION_OUTPUT" || "$VERSION_OUTPUT" == / || -d "$VERSION_OUTPUT" ||
    "$SOURCE_OUTPUT" == "$VERSION_OUTPUT" || "${1:-}" != -- ]]; then
    echo "错误：AUR 包、架构、源文件名模板、输出路径或参数分隔符无效。" >&2
    exit 2
  fi
  shift
  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

  # 原应用依赖仍由普通公共入口安装，不启用来源导出模式。
  if (( $# > 0 )); then
    "$SCRIPT_DIR/install_packages.sh" "$@"
  fi

  # 缓存与构建目录仅供本次安装使用，导出成功或失败后均清理。
  INSTALL_WORK="$(mktemp -d "${TMPDIR:-/tmp}/arch-aur-source.XXXXXXXX")"
  cleanup() {
    rm -rf -- "$INSTALL_WORK"
  }
  trap cleanup EXIT
  mkdir -p "$INSTALL_WORK/sources" "$INSTALL_WORK/build"
  # 仅设置本次目录权限，让非 root 构建用户能够进入并写入带粘滞位的子目录。
  chmod 711 "$INSTALL_WORK"
  chmod 1777 "$INSTALL_WORK/sources" "$INSTALL_WORK/build"

  # makepkg 将原始文件保存在独立来源缓存，yay 继续按 AUR 配方校验和安装。
  SRCDEST="$INSTALL_WORK/sources" yay -S --noconfirm --needed --builddir "$INSTALL_WORK/build" "$AUR_PACKAGE"

  # 版本取自实际安装结果，必须与本次构建目录中的来源元数据一致。
  VERSION="$("$SCRIPT_DIR/../build/read_app_version.sh" pacman "$AUR_PACKAGE")"

  # 只导出指定源文件，按同次元数据重新校验 SHA-256 或 SHA-512 后写入版本。
  python3 - "$AUR_PACKAGE" "$AUR_ARCH" "$SOURCE_PATTERN" "$INSTALL_WORK/build/$AUR_PACKAGE/.SRCINFO" \
    "$INSTALL_WORK/sources" "$SOURCE_OUTPUT" "$VERSION_OUTPUT" "$VERSION" <<'PY'
import hashlib
import os
import re
import sys
import tempfile
from pathlib import Path
from urllib.parse import urlsplit

package, architecture, pattern, metadata_path, cache_path, output_path, version_path, version = sys.argv[1:]
metadata = Path(metadata_path)
if not metadata.is_file():
    raise SystemExit("错误：本次 AUR 构建元数据不存在，无法导出安装来源。")
fields = {}
for raw in metadata.read_text(encoding="utf-8").splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    key, separator, value = line.partition("=")
    if not separator:
        raise SystemExit("错误：AUR 来源元数据格式无效。")
    fields.setdefault(key.strip(), []).append(value.strip())

if fields.get("pkgbase") != [package] or fields.get("pkgname") != [package]:
    raise SystemExit("错误：仅支持包基名与包名一致的单包来源。")
if fields.get("pkgver") != [version]:
    raise SystemExit("错误：实际安装版本与 AUR 来源版本不一致。")
if architecture not in fields.get("arch", []) and "any" not in fields.get("arch", []):
    raise SystemExit("错误：AUR 来源不支持指定架构。")

filename = pattern.replace("{version}", version)
if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._+-]*", filename) or filename in (".", ".."):
    raise SystemExit("错误：源文件名模板展开后不是安全的单个文件名。")

matches = []
for suffix in ("", "_" + architecture):
    sources = fields.get("source" + suffix, [])
    for index, source in enumerate(sources):
        alias, separator, url = source.partition("::")
        if not separator:
            url = source
            alias = urlsplit(url).path.rsplit("/", 1)[-1]
        if alias == filename:
            matches.append((suffix, index, url, len(sources)))
if len(matches) != 1:
    raise SystemExit("错误：无法从同次 AUR 元数据唯一确定指定源文件。")

suffix, source_index, url, source_count = matches[0]
origin = urlsplit(url)
if origin.scheme != "https" or not origin.netloc or origin.username is not None:
    raise SystemExit("错误：选中的 AUR 源文件必须来自无登录凭据的 HTTPS 地址。")

algorithm = ""
expected = ""
for name, length in (("sha256", 64), ("sha512", 128)):
    key = name + "sums" + suffix
    if key not in fields:
        continue
    checksums = fields[key]
    if len(checksums) != source_count or not re.fullmatch(r"[0-9A-Fa-f]{" + str(length) + "}", checksums[source_index]):
        raise SystemExit("错误：选中源文件的原摘要无效，不能跳过或改用其他摘要。")
    algorithm, expected = name, checksums[source_index].lower()
    break
if not algorithm:
    raise SystemExit("错误：选中源文件缺少可校验的 SHA-256 或 SHA-512。")

cached = Path(cache_path) / filename
if not cached.is_file() or cached.is_symlink():
    raise SystemExit("错误：安装来源缓存中缺少指定的原始文件。")
output = Path(output_path)
version_output = Path(version_path)
if output.resolve() == version_output.resolve():
    raise SystemExit("错误：源文件与版本文件不能指向同一路径。")
output.parent.mkdir(parents=True, exist_ok=True)
version_output.parent.mkdir(parents=True, exist_ok=True)

# 复制与摘要计算使用同一份字节，校验通过后才替换正式输出。
fd, temporary = tempfile.mkstemp(prefix=output.name + ".part.", dir=output.parent)
try:
    digest = hashlib.new(algorithm)
    with os.fdopen(fd, "wb") as target, cached.open("rb") as source:
        while chunk := source.read(1024 * 1024):
            target.write(chunk)
            digest.update(chunk)
    if digest.hexdigest() != expected:
        raise SystemExit("错误：安装来源缓存的摘要校验失败。")
    os.chmod(temporary, 0o644)
    os.replace(temporary, output)
finally:
    Path(temporary).unlink(missing_ok=True)

# 只有源文件导出完成后，才原子写入同次实际版本。
fd, temporary = tempfile.mkstemp(prefix=version_output.name + ".part.", dir=version_output.parent)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as target:
        target.write(version + "\n")
    os.chmod(temporary, 0o644)
    os.replace(temporary, version_output)
finally:
    Path(temporary).unlink(missing_ok=True)
print(f"已复用通过 AUR {algorithm.upper()} 校验的原始源文件：{filename}", file=sys.stderr)
PY
  exit 0
fi

# 已校验 DEB 来源模式只在显式请求时启用；原基础包和包名参数保持原样。
if [[ "${1:-}" == --aur-deb ]]; then
  shift
  if (( $# < 2 )) || [[ ! "$1" =~ ^[a-z0-9][a-z0-9@._+-]*$ || "$1" == *..* || ! "$2" =~ ^[a-zA-Z0-9_]+$ ]]; then
    echo "用法：$0 --aur-deb <AUR 包名> <架构> [--user-agent <客户端标识>] [--downloader curl|wget|aria2c] [--wayback] [--fallback-origin <HTTPS 源站>] [--source-filename <DEB 文件名>] -- [额外软件包...]" >&2
    exit 2
  fi
  AUR_PACKAGE="$1"
  AUR_ARCH="$2"
  shift 2
  DOWNLOAD_OPTIONS=()
  USER_AGENT=""
  DOWNLOADER=""
  SELECTED_FILENAME=""
  USE_WAYBACK=false
  FALLBACK_ORIGIN=""
  SEPARATOR=false
  while (( $# > 0 )); do
    case "$1" in
      --user-agent)
        (( $# >= 2 )) && [[ -n "$2" && "$2" != --* && -z "$USER_AGENT" && "$2" != *$'\r'* && "$2" != *$'\n'* ]] || {
          echo "错误：--user-agent 需要唯一且不含换行的非空值。" >&2
          exit 2
        }
        USER_AGENT="$2"
        DOWNLOAD_OPTIONS+=(--user-agent "$USER_AGENT")
        shift 2
        ;;
      --downloader)
        if (( $# < 2 )) || [[ -n "$DOWNLOADER" || ( "$2" != curl && "$2" != wget && "$2" != aria2c ) ]]; then
          echo "错误：--downloader 需要唯一的 curl、wget 或 aria2c。" >&2
          exit 2
        fi
        DOWNLOADER="$2"
        DOWNLOAD_OPTIONS+=(--downloader "$DOWNLOADER")
        shift 2
        ;;
      --source-filename)
        if (( $# < 2 )) || [[ -n "$SELECTED_FILENAME" || "$2" != *.deb || "$2" == --* || "$2" == */* || "$2" == *$'\r'* || "$2" == *$'\n'* ]]; then
          echo "错误：--source-filename 需要唯一的 DEB 文件名，可用 {version} 代表 pkgver。" >&2
          exit 2
        fi
        SELECTED_FILENAME="$2"
        DOWNLOAD_OPTIONS+=(--source-filename "$SELECTED_FILENAME")
        shift 2
        ;;
      --fallback-origin)
        (( $# >= 2 )) && [[ "$2" =~ ^https://[[:alnum:]]([[:alnum:].-]*[[:alnum:]])?$ ]] && [[ -z "$FALLBACK_ORIGIN" ]] || {
          echo "错误：--fallback-origin 需要唯一的 HTTPS 源站，仅包含协议和域名。" >&2
          exit 2
        }
        FALLBACK_ORIGIN="$2"
        DOWNLOAD_OPTIONS+=(--fallback-origin "$FALLBACK_ORIGIN")
        shift 2
        ;;
      --wayback)
        [[ "$USE_WAYBACK" == false ]] || {
          echo "错误：--wayback 不得重复指定。" >&2
          exit 2
        }
        USE_WAYBACK=true
        DOWNLOAD_OPTIONS+=(--wayback)
        shift
        ;;
      --)
        SEPARATOR=true
        shift
        break
        ;;
      *)
        echo "错误：不支持的安装选项：$1" >&2
        exit 2
        ;;
    esac
  done
  [[ "$SEPARATOR" == true ]] || {
    echo "错误：请用 -- 分隔来源选项与额外软件包。" >&2
    exit 2
  }
  [[ -z "$FALLBACK_ORIGIN" || "$USE_WAYBACK" == true ]] || {
    echo "错误：--fallback-origin 需要与 --wayback 一起使用。" >&2
    exit 2
  }
  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  DOWNLOAD_DEB="$SCRIPT_DIR/../aur/download_deb_source.sh"
  command -v yay >/dev/null 2>&1 && [[ -x "$DOWNLOAD_DEB" ]] || {
    echo "错误：缺少 yay 或公共 AUR 下载入口。" >&2
    exit 1
  }

  # 先安装调用方原有的运行依赖，应用安装仍在同一公共阶段完成。
  if (( $# > 0 )); then
    yay -S --noconfirm --needed "$@"
  fi

  # 使用独立缓存和构建目录，避免旧的错误响应被 makepkg 当成已下载源文件。
  INSTALL_WORK="$(mktemp -d "${TMPDIR:-/tmp}/arch-aur-deb.XXXXXXXX")"
  cleanup() {
    rm -rf -- "$INSTALL_WORK"
  }
  trap cleanup EXIT
  mkdir -p "$INSTALL_WORK/sources" "$INSTALL_WORK/build"
  # 仅调整本次临时目录：非 root 构建用户可进入，并可在带粘滞位的子目录工作。
  chmod 711 "$INSTALL_WORK"
  chmod 1777 "$INSTALL_WORK/sources" "$INSTALL_WORK/build"

  # 原摘要通过后才填入 makepkg 期望的文件名，不改 PKGBUILD 或校验值。
  "$DOWNLOAD_DEB" "$AUR_PACKAGE" "$AUR_ARCH" "$INSTALL_WORK/verified.deb" "${DOWNLOAD_OPTIONS[@]}" --makepkg-source-dir "$INSTALL_WORK/sources"

  # SRCDEST 是 makepkg 的来源缓存；只作用于本次 yay，仍由 AUR 规则再次校验和安装。
  SRCDEST="$INSTALL_WORK/sources" yay -S --noconfirm --needed --builddir "$INSTALL_WORK/build" "$AUR_PACKAGE"
  exit 0
fi

if [[ "${1:-}" == --base ]]; then
  shift
  (( $# == 0 )) || {
    echo "用法：$0 --base 或 $0 <Arch 软件包名> [...]" >&2
    exit 1
  }
  PACKAGES=(
    base-devel archlinux-keyring gcc make pkgconf patch autoconf
    automake binutils bison debugedit fakeroot file findutils flex gawk gettext
    grep groff gzip libtool m4 pacman sed sudo texinfo which git wget curl jq
    github-cli patchelf coreutils tar bzip2 xz zstd lz4 unzip zip 7zip rsync
    util-linux appstream-glib desktop-file-utils shared-mime-info
    hicolor-icon-theme xdg-utils zsync ca-certificates ca-certificates-utils
    cmake ninja meson python perl squashfs-tools libarchive cpio elfutils
    pax-utils chrpath openssl openssh gnupg dbus at-spi2-core nspr nss
    nss-mdns avahi xdg-desktop-portal ibus xterm xclip xsel xorg-xrdb
    wqy-microhei wqy-zenhei noto-fonts-emoji polkit glib2 pango gdk-pixbuf2
    libdrm libxkbcommon fontconfig xdotool openal lsb-release socat nginx
    boost-libs inetutils
  )
else
  (( $# > 0 )) || {
    echo "用法：$0 --base 或 $0 <Arch 软件包名> [...]" >&2
    exit 1
  }
  PACKAGES=("$@")
fi

# 标准 Arch 构建容器已由共享 Action 提供 yay，包安装逻辑统一放在公共入口。
command -v yay >/dev/null 2>&1 || {
  echo "错误：Arch 构建环境缺少 yay。" >&2
  exit 1
}
yay -S --noconfirm --needed "${PACKAGES[@]}"
