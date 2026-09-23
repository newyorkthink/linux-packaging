#!/usr/bin/env bash
set -Eeuo pipefail

UPDATE_PACKAGE_INDEX=1
if [[ "${1:-}" == --no-update ]]; then
  UPDATE_PACKAGE_INDEX=0
  shift
fi

(( $# > 0 )) || {
  echo "用法：$0 [--no-update] <软件包名或本地 DEB> [...]" >&2
  exit 1
}

# Ubuntu 22.04/24.04 的公共构建环境；应用专属包继续由调用方传入。
# Arch 专属的 pacman/archlinux-keyring 在 Ubuntu 对应为 dpkg/ubuntu-keyring；
# ca-certificates-utils 的证书更新命令由 Ubuntu ca-certificates 提供。
BASE_PACKAGES=(
  build-essential ubuntu-keyring gcc g++ make pkgconf patch autoconf automake
  binutils bison debugedit fakeroot file findutils flex gawk gettext grep
  groff gzip libtool m4 dpkg sed sudo texinfo debianutils git wget curl jq gh
  patchelf coreutils tar bzip2 xz-utils zstd lz4 unzip zip p7zip-full rsync
  util-linux appstream-util desktop-file-utils shared-mime-info
  hicolor-icon-theme xdg-utils zsync ca-certificates cmake ninja-build meson
  python3 perl squashfs-tools libarchive-tools cpio elfutils pax-utils chrpath
  openssl openssh-client gnupg dbus at-spi2-core libnspr4 libnss3
  libnss-mdns avahi-daemon xdg-desktop-portal ibus xterm xclip xsel
  x11-xserver-utils fonts-wqy-microhei fonts-wqy-zenhei
  fonts-noto-color-emoji polkitd libpango-1.0-0 libgdk-pixbuf-2.0-0
  libdrm2 libxkbcommon0 fontconfig xdotool libopenal1 lsb-release socat
  nginx libboost-all-dev inetutils-tools
)

# Ubuntu 24.04 将 GLib 运行库改为 t64 包名；22.04 仍使用旧包名。
if [[ "$(. /etc/os-release; printf '%s' "$VERSION_ID")" == 22.04 ]]; then
  BASE_PACKAGES+=(libglib2.0-0)
else
  BASE_PACKAGES+=(libglib2.0-0t64)
fi

# 根据当前权限选择 apt-get 调用方式，root 环境不经过 sudo。
if ((EUID == 0)); then
  APT=(apt-get)
elif command -v sudo >/dev/null 2>&1; then
  APT=(sudo apt-get)
else
  echo "错误：安装软件包需要 root 或 sudo。" >&2
  exit 1
fi

# 同一构建后续安装本地 DEB 时可跳过已经完成的软件源索引更新。
if ((UPDATE_PACKAGE_INDEX)); then
  "${APT[@]}" update
fi

DEBIAN_FRONTEND=noninteractive "${APT[@]}" install -y --no-install-recommends "${BASE_PACKAGES[@]}" "$@"
