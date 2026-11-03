#!/usr/bin/env bash
set -Eeuo pipefail

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
