#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${GITHUB_WORKSPACE:-$(pwd)}"
APPDIR="${WORKSPACE}/arch"
BOOTSTRAP_DIR="${WORKSPACE}/bootstrap"
ROOT="${APPDIR}/root"

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  binutils \
  ca-certificates \
  desktop-file-utils \
  file \
  gcc \
  wget \
  xz-utils \
  zstd

wget -q \
  https://geo.mirror.pkgbuild.com/iso/latest/archlinux-bootstrap-x86_64.tar.zst \
  -O archlinux-bootstrap-x86_64.tar.zst

sudo rm -rf "${APPDIR}" "${BOOTSTRAP_DIR}"
mkdir -p "${APPDIR}" "${BOOTSTRAP_DIR}"
sudo tar --zstd -xf archlinux-bootstrap-x86_64.tar.zst -C "${BOOTSTRAP_DIR}"
sudo mv "${BOOTSTRAP_DIR}/root.x86_64" "${ROOT}"

sudo install -m 0644 /etc/resolv.conf "${ROOT}/etc/resolv.conf"
sudo install -m 0644 "${WORKSPACE}/files/mirrorlist" "${ROOT}/etc/pacman.d/mirrorlist"
sudo install -m 0644 "${WORKSPACE}/files/pacman.conf" "${ROOT}/etc/pacman.conf"

# Install official prebuilt packages only. QEMU is not compiled here.
# virt-viewer provides the SPICE client used for reliable host/guest clipboard.
sudo chroot "${ROOT}" /usr/bin/bash -euo pipefail -c '
  pacman -Syyu --noconfirm
  pacman -S --needed --noconfirm qemu-desktop jack2 virt-viewer

  rm -rf \
    /var/cache/pacman/pkg/* \
    /var/lib/pacman/sync \
    /usr/include \
    /usr/share/doc \
    /usr/share/info \
    /usr/share/man

  if [[ -d /usr/share/locale ]]; then
    find /usr/share/locale -mindepth 1 -maxdepth 1 \
      ! -name C \
      ! -name C.utf8 \
      ! -name en \
      ! -name en_US \
      ! -name zh_CN \
      -exec rm -rf -- {} +
  fi
'

QEMU_VERSION="$(sudo chroot "${ROOT}" pacman -Q qemu-system-x86 | awk '{print $2}')"

# Make remote-viewer portable when QEMU's spice-app display launches it.
sudo mv "${ROOT}/usr/bin/remote-viewer" "${ROOT}/usr/bin/remote-viewer.real"
sudo tee "${ROOT}/usr/bin/remote-viewer" >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)"
INTERPRETER="${ROOT}/usr/lib/ld-linux-x86-64.so.2"
[[ -x "${INTERPRETER}" ]] || INTERPRETER="${ROOT}/lib64/ld-linux-x86-64.so.2"
exec "${INTERPRETER}" \
  --inhibit-cache \
  --library-path "${ROOT}/usr/lib" \
  "${ROOT}/usr/bin/remote-viewer.real" "$@"
EOF
sudo chmod +x "${ROOT}/usr/bin/remote-viewer"

# Build libunionpreload independently; QEMU itself remains the official package.
LIBUNIONPRELOAD_COMMIT=bd1fc4a17ddac6ab999b741d3d16e930862a3d98
wget -q \
  "https://raw.githubusercontent.com/project-portable/libunionpreload/${LIBUNIONPRELOAD_COMMIT}/libunionpreload.c" \
  -O "${WORKSPACE}/libunionpreload.c"
gcc -shared -fPIC "${WORKSPACE}/libunionpreload.c" \
  -o "${APPDIR}/libunionpreload.so" \
  -ldl -DUNION_LIBNAME='"libunionpreload.so"'
strip --strip-unneeded "${APPDIR}/libunionpreload.so"

cp "${WORKSPACE}/files/AppRun" "${APPDIR}/AppRun"
cp "${WORKSPACE}/files/qemu.svg" "${APPDIR}/qemu.svg"
cp "${WORKSPACE}/files/qemu.desktop" "${APPDIR}/qemu.desktop"
chmod +x "${APPDIR}/AppRun"

# Strip only ELF files. Ignore firmware, scripts and data files.
while IFS= read -r -d '' candidate; do
  if file -b "${candidate}" | grep -q '^ELF '; then
    sudo strip --strip-unneeded "${candidate}" 2>/dev/null || true
  fi
done < <(find "${ROOT}/usr/bin" "${ROOT}/usr/lib" -type f -print0)

wget -q \
  https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage \
  -O appimagetool
chmod +x appimagetool

ARCH=x86_64 ./appimagetool -n "${APPDIR}" \
  "QEMU-${QEMU_VERSION}-x86_64.AppImage"
