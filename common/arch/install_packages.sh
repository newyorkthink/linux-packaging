#!/usr/bin/env bash
set -Eeuo pipefail

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
