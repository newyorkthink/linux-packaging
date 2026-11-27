#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 安装统一的 Arch AppImage 基础包
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
cd "$SCRIPT_DIR"

export ARCH="$(uname -m)"
export DESKTOP="https://raw.githubusercontent.com/virt-manager/virt-manager/refs/heads/main/data/virt-manager.desktop.in"
export ICON="https://raw.githubusercontent.com/virt-manager/virt-manager/refs/heads/main/data/icons/256x256/apps/virt-manager.png"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|virt-manager.AppImage.zsync"
export RIM_ALLOW_ROOT=1

# 下载上游 RunImage 构建运行时。
curl --fail --location --retry 3 --retry-delay 5 \
  "https://github.com/VHSgunzo/runimage/releases/download/continuous/runimage-$ARCH" \
  --output runimage
chmod +x runimage

run_install() {
  set -Eeuo pipefail

  readonly EXTRA_PACKAGES="https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/eefb8bed88f227bf7d29d3d0c5c816c2b4c5fdf4/useful-tools/get-debloated-pkgs.sh"
  readonly INSTALL_PKGS=(
    bridge-utils
    dnsmasq
    freetype2
    libxcb
    libxcursor
    libxi
    libxkbcommon-x11
    openbsd-netcat
    pipewire-audio
    pulseaudio
    pulseaudio-alsa
    qemu-desktop
    qemu-full
    swtpm
    virtiofsd
    virt-manager
    wget
  )

  rim-update
  pac --needed --noconfirm -S "${INSTALL_PKGS[@]}"

  wget --retry-connrefused --tries=30 "$EXTRA_PACKAGES" -O ./get-debloated-pkgs.sh
  chmod +x ./get-debloated-pkgs.sh
  ./get-debloated-pkgs.sh --add-opengl --prefer-nano opus-mini gdk-pixbuf2-mini librsvg-mini

  pac -Rsn --noconfirm llvm-libs || true
  pac -Rsn --noconfirm glycin || true
  pac -Rsn --noconfirm x265 || true
  pac -Rsn --noconfirm lib32-glibc lib32-fakechroot lib32-fakeroot || true

  pac -Rsndd --noconfirm wget svt-av1 gocryptfs jq gnupg
  rim-shrink --all
  pac -Rsndd --noconfirm binutils perl

  pac -Qi | awk -F': ' '/Name/ {name=$2}
    /Installed Size/ {size=$2}
    name && size {print name, size; name=size=""}' \
    | column -t | grep MiB | sort -nk 2

  pacman -Q virt-manager | awk '{print $2; exit}' > ~/version

  cat <<'EOF' > "$RUNDIR/config/Run.rcfg"
RIM_CMPRS_LVL="${RIM_CMPRS_LVL:=22}"
RIM_CMPRS_BSIZE="${RIM_CMPRS_BSIZE:=25}"
RIM_SYS_NVLIBS="${RIM_SYS_NVLIBS:=1}"
RIM_NVIDIA_DRIVERS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/runimage_nvidia"
RIM_SHARE_ICONS="${RIM_SHARE_ICONS:=1}"
RIM_SHARE_FONTS="${RIM_SHARE_FONTS:=1}"
RIM_SHARE_THEMES="${RIM_SHARE_THEMES:=1}"
RIM_HOST_XDG_OPEN="${RIM_HOST_XDG_OPEN:=1}"
RIM_BIND="/usr/share/locale:/usr/share/locale,/usr/lib/locale:/usr/lib/locale"
RIM_AUTORUN=virt-manager
EOF

  rim-build -s /tmp/virt-manager.RunImage
}
export -f run_install

RIM_OVERFS_MODE=1 RIM_NO_NVIDIA_CHECK=1 ./runimage bash -c run_install

/tmp/virt-manager.RunImage --runtime-extract
rm -f /tmp/virt-manager.RunImage
mv ./RunDir ./AppDir
mv ./AppDir/Run ./AppDir/AppRun

rm -rfv \
  ./AppDir/sharun/bin/chisel \
  ./AppDir/rootfs/usr/lib/libgo.so* \
  ./AppDir/rootfs/usr/lib/libgphobos.so* \
  ./AppDir/rootfs/usr/lib/libgfortran.so* \
  ./AppDir/rootfs/usr/bin/rav1e \
  ./AppDir/rootfs/usr/*/*pacman* \
  ./AppDir/rootfs/var/lib/pacman \
  ./AppDir/rootfs/etc/pacman* \
  ./AppDir/rootfs/usr/share/licenses \
  ./AppDir/rootfs/usr/lib/udev/hwdb.bin

export VERSION="$(cat ~/version)"
export APPNAME="virt-manager"
export OUTPATH="./dist"
export OUTNAME="virt-manager.AppImage"
export OPTIMIZE_LAUNCH=1

# 使用 quick-sharun 将完整 RunImage 根文件系统封装为固定名称的 AppImage。
quick-sharun --make-appimage
