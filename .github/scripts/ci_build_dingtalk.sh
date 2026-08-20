#!/usr/bin/env bash
set -Eeuo pipefail

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  file \
  patchelf \
  pax-utils \
  binutils \
  xvfb \
  xauth \
  libgl1 \
  libegl1 \
  libglu1-mesa \
  libgbm1 \
  libxss1 \
  libasound2t64 \
  libpulse0 \
  libpulse-mainloop-glib0 \
  libopus0 \
  libcups2t64 \
  libnss3 \
  libnspr4 \
  libcrypt1 \
  libgtk2.0-0t64 \
  libfcitx5-qt1 \
  libdbus-1-3 \
  libinput10 \
  libmtdev1t64 \
  libxkbcommon0 \
  libxkbcommon-x11-0 \
  libxcb1 \
  libxcb-cursor0 \
  libxcb-icccm4 \
  libxcb-image0 \
  libxcb-keysyms1 \
  libxcb-randr0 \
  libxcb-render-util0 \
  libxcb-shape0 \
  libxcb-shm0 \
  libxcb-sync1 \
  libxcb-xfixes0 \
  libxcb-xinerama0 \
  libxcomposite1 \
  libxdamage1 \
  libxrandr2 \
  libxtst6 \
  zenity

curl -fL --retry 5 \
  https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage \
  -o /tmp/appimagetool.AppImage
chmod 0755 /tmp/appimagetool.AppImage
(
  cd /tmp
  ./appimagetool.AppImage --appimage-extract >/dev/null
)
sudo rm -rf /opt/appimagetool
sudo mv /tmp/squashfs-root /opt/appimagetool
sudo tee /usr/local/bin/appimagetool >/dev/null <<'WRAPPER'
#!/bin/sh
exec /opt/appimagetool/AppRun "$@"
WRAPPER
sudo chmod 0755 /usr/local/bin/appimagetool
appimagetool --version
gh --version

docker run --rm \
  -v "$GITHUB_WORKSPACE:/work" \
  -w /work \
  ghcr.io/pkgforge-dev/archlinux:latest \
  bash -lc '
    set -Eeuo pipefail
    pacman -Syu --noconfirm --needed git base-devel sudo patchelf libarchive
    useradd -m -G wheel builduser
    echo "builduser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    git -c http.version=HTTP/1.1 clone --depth=1 \
      https://aur.archlinux.org/dingtalk-bin.git /tmp/dingtalk-bin
    chown -R builduser:builduser /tmp/dingtalk-bin

    # 这里只需要生成并提取 AUR 包，不在 Arch 容器中运行钉钉。
    # gtk2、glu、libxcrypt-compat 等运行库由后续 Ubuntu 阶段统一收集进 AppImage。
    su - builduser -c "cd /tmp/dingtalk-bin && makepkg --nodeps --noconfirm"

    package_file="$(
      find /tmp/dingtalk-bin -maxdepth 1 -type f \
        -name "dingtalk-bin-*.pkg.tar.*" \
        ! -name "dingtalk-bin-debug-*" \
        ! -name "*.sig" \
        -print -quit
    )"
    [[ -n "$package_file" && -s "$package_file" ]]

    rootfs=/tmp/dingtalk-rootfs
    rm -rf "$rootfs"
    mkdir -p "$rootfs"
    bsdtar -xf "$package_file" -C "$rootfs"

    release_dir="$rootfs/opt/dingtalk/release"
    desktop_file="$rootfs/usr/share/applications/com.alibabainc.dingtalk.desktop"
    icon_file="$rootfs/usr/share/icons/hicolor/scalable/apps/dingtalk.svg"

    [[ -x "$release_dir/com.alibabainc.dingtalk" ]]
    [[ -f "$desktop_file" ]]
    if [[ ! -f "$icon_file" ]]; then
      icon_file="$(find "$rootfs/usr/share/icons" "$rootfs/usr/share/pixmaps" \
        -type f -name "com.alibabainc.dingtalk.svg" -print -quit 2>/dev/null)"
    fi
    [[ -n "$icon_file" && -f "$icon_file" ]]

    rm -rf /work/dingtalk/source
    mkdir -p /work/dingtalk/source/release /work/dingtalk/source/meta
    cp -a "$release_dir/." /work/dingtalk/source/release/

    # 只从临时 AppImage 源目录移除旧诊断组件，不改 AUR 包或仓库源文件。
    # 它们依赖 Ubuntu 24.04 已不提供的 libpangox-1.0.so.0，且钉钉主程序不链接这些文件。
    rm -f \
      /work/dingtalk/source/release/doctor \
      /work/dingtalk/source/release/libgtkglext-x11-1.0.so* \
      /work/dingtalk/source/release/libgdkglext-x11-1.0.so*

    cp "$desktop_file" /work/dingtalk/source/meta/com.alibabainc.dingtalk.desktop
    cp "$icon_file" /work/dingtalk/source/meta/com.alibabainc.dingtalk.svg
    pacman -Qp "$package_file" | awk "{print \$2}" \
      > /work/dingtalk/source/meta/package-version
    chmod -R a+rwX /work/dingtalk/source
  '

nss_source=/usr/lib/x86_64-linux-gnu
nss_target="$GITHUB_WORKSPACE/dingtalk/source/release"
nss_manifest="$GITHUB_WORKSPACE/dingtalk/source/meta/nss-runtime-files.txt"

nss_files=(
  libfreebl3.chk
  libfreebl3.so
  libfreeblpriv3.chk
  libfreeblpriv3.so
  libnspr4.so
  libnss3.so
  libnssckbi.so
  libnssdbm3.chk
  libnssdbm3.so
  libnssutil3.so
  libplc4.so
  libplds4.so
  libsmime3.so
  libsoftokn3.chk
  libsoftokn3.so
  libssl3.so
)

printf '%s\n' "${nss_files[@]}" > "$nss_manifest"
test -s "$nss_manifest"

for nss_file in "${nss_files[@]}"; do
  test -s "$nss_source/$nss_file"
  cp -L "$nss_source/$nss_file" "$nss_target/$nss_file"
  test -s "$nss_target/$nss_file"
done

check_dependencies() {
  local target="$1"
  local dependencies

  dependencies="$(LD_LIBRARY_PATH="$nss_target" ldd "$target")"
  printf '%s\n' "$dependencies"
  if grep -F 'not found' <<<"$dependencies"; then
    echo "NSS/NSPR 组件仍存在缺失依赖：$target" >&2
    exit 1
  fi
}

check_symbol_versions() {
  local consumer="$1"
  local provider="$2"
  local prefix="$3"
  local required_versions provided_versions version

  required_versions="$(
    readelf --version-info "$consumer" 2>/dev/null \
      | awk -v prefix="$prefix" '{
          for (i = 1; i <= NF; i++)
            if ($i == "Name:" && $(i + 1) ~ ("^" prefix "_"))
              print $(i + 1)
        }' \
      | sort -u
  )"
  provided_versions="$(
    readelf --version-info "$provider" 2>/dev/null \
      | awk -v prefix="$prefix" '{
          for (i = 1; i <= NF; i++)
            if ($i == "Name:" && $(i + 1) ~ ("^" prefix "_"))
              print $(i + 1)
        }' \
      | sort -u
  )"

  while IFS= read -r version; do
    [[ -z "$version" ]] && continue
    if ! grep -Fxq "$version" <<<"$provided_versions"; then
      echo "符号版本不匹配：$(basename "$consumer") 需要 $version" >&2
      exit 1
    fi
  done <<<"$required_versions"
}

for nss_file in "${nss_files[@]}"; do
  [[ "$nss_file" == *.so ]] || continue
  check_dependencies "$nss_target/$nss_file"
  check_symbol_versions \
    "$nss_target/$nss_file" "$nss_target/libnssutil3.so" NSSUTIL
  check_symbol_versions \
    "$nss_target/$nss_file" "$nss_target/libnspr4.so" NSPR
done

bash -n dingtalk/build_dingtalk.sh
chmod 0755 dingtalk/build_dingtalk.sh
./dingtalk/build_dingtalk.sh

test -s dingtalk/dist/DingTalk.AppImage
test -s dingtalk/dist/DingTalk.AppImage.sha256
test -s dingtalk/dist/dingtalk-version.txt

test -s dingtalk/source/meta/nss-runtime-files.txt
while IFS= read -r runtime_file; do
  test -n "$runtime_file"
  test -s "dingtalk/AppDir/opt/dingtalk/release/$runtime_file"
done < dingtalk/source/meta/nss-runtime-files.txt

(
  cd dingtalk/dist
  sha256sum -c DingTalk.AppImage.sha256
)
