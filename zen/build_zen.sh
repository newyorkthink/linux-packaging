#!/usr/bin/env bash
set -Eeuo pipefail

# Zen 相关构建文件集中放在 zen/ 目录；无论从仓库哪个目录调用，都固定在脚本目录内构建。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

rm -rf AppDir dist || true

export ARCH=x86_64
export APPNAME="zen-adblocker"
export STARTUPWMCLASS="zen"
export OUTPATH=./dist
export OUTNAME="zen.AppImage"
export DEPLOY_GTK=1

# 安装 AppImage 打包工具和 Zen 官方 Linux 运行依赖。
yay -S --noconfirm \
  curl git jq binutils patchelf coreutils \
  appstream-glib desktop-file-utils util-linux zsync \
  glib2 gtk3 webkit2gtk-4.1 libsoup3 glib-networking gsettings-desktop-schemas \
  networkmanager ibus ca-certificates shared-mime-info xdg-utils \
  libsecret libnotify libayatana-appindicator \
  libx11 libxext libxi libxtst libxss libxrandr libxinerama \
  libxcomposite libxdamage libxfixes libxkbcommon libxkbcommon-x11 libxkbfile \
  at-spi2-core cairo pango fribidi fontconfig freetype2 harfbuzz \
  gdk-pixbuf2 librsvg hicolor-icon-theme adwaita-icon-theme

# 直接使用 AUR zen-adblocker-bin 已有的 desktop 和 appicon，不修改 Zen 程序本体。
AUR_DIR="/tmp/zen-adblocker-bin-aur"
rm -rf "$AUR_DIR"
git clone --depth=1 https://aur.archlinux.org/zen-adblocker-bin.git "$AUR_DIR"
export DESKTOP="$AUR_DIR/zen-adblocker.desktop"
export ICON="$AUR_DIR/appicon.png"
test -f "$DESKTOP"
test -f "$ICON"

# AUR 包将程序安装为 zen-adblocker；确保 desktop 与该入口一致。
if ! grep -Eq '^Exec=(/usr/bin/)?zen-adblocker([[:space:]]|$)' "$DESKTOP"; then
  echo "错误：AUR zen-adblocker.desktop 的 Exec 已发生变化。" >&2
  exit 1
fi

# 读取 Zen 官方最新正式 Release，直接下载官方提供的 Linux amd64 noselfupdate 二进制。
# 不克隆源码、不编译源码、不应用任何 .patch、不使用 LD_PRELOAD 修改 Zen 行为。
RELEASE_JSON="/tmp/zen-latest-release.json"
GITHUB_HEADERS=(-H 'Accept: application/vnd.github+json')
if [[ -n "${GH_TOKEN:-}" ]]; then
  GITHUB_HEADERS+=(-H "Authorization: Bearer $GH_TOKEN")
fi
curl -fsSL --retry 3 \
  "${GITHUB_HEADERS[@]}" \
  https://api.github.com/repos/irbis-sh/zen-desktop/releases/latest \
  -o "$RELEASE_JSON"

VERSION="$(jq -r '.tag_name // empty' "$RELEASE_JSON")"
ASSET_NAME="Zen_linux_amd64_noselfupdate.tar.gz"
ASSET_URL="$(jq -r --arg name "$ASSET_NAME" '.assets[] | select(.name == $name) | .browser_download_url' "$RELEASE_JSON" | head -n1)"
ASSET_DIGEST="$(jq -r --arg name "$ASSET_NAME" '.assets[] | select(.name == $name) | .digest // empty' "$RELEASE_JSON" | head -n1)"

if [[ -z "$VERSION" || -z "$ASSET_URL" ]]; then
  echo "错误：无法找到 Zen 官方 Linux amd64 noselfupdate Release 资产。" >&2
  exit 1
fi
printf 'Zen 官方正式版：%s\n' "$VERSION"
printf 'Zen 官方资产：%s\n' "$ASSET_NAME"

OFFICIAL_DIR="/tmp/zen-official"
ARCHIVE="$OFFICIAL_DIR/$ASSET_NAME"
EXTRACT_DIR="$OFFICIAL_DIR/extracted"
rm -rf "$OFFICIAL_DIR"
mkdir -p "$EXTRACT_DIR"

curl -fL --retry 3 "$ASSET_URL" -o "$ARCHIVE"

# GitHub Release 提供 sha256 digest 时必须校验，防止下载损坏或资产异常。
if [[ "$ASSET_DIGEST" == sha256:* ]]; then
  EXPECTED_SHA256="${ASSET_DIGEST#sha256:}"
  ACTUAL_SHA256="$(sha256sum "$ARCHIVE" | awk '{print $1}')"
  if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
    echo "错误：Zen 官方资产 SHA256 校验失败。" >&2
    exit 1
  fi
  printf 'Zen 官方资产 SHA256：%s\n' "$ACTUAL_SHA256"
fi

tar -xzf "$ARCHIVE" -C "$EXTRACT_DIR"
ZEN_BIN="$(find "$EXTRACT_DIR" -type f -name 'Zen' -perm -u+x -print -quit)"
if [[ -z "$ZEN_BIN" || ! -x "$ZEN_BIN" ]]; then
  echo "错误：官方压缩包中没有找到可执行文件 Zen。" >&2
  exit 1
fi

# 直接安装官方 Zen 可执行文件作为 AppImage 主入口；不修改二进制内容。
install -Dm755 "$ZEN_BIN" /usr/bin/zen-adblocker

# 收集 Zen 官方程序及其 Linux 运行库。
quick-sharun \
  /usr/bin/zen-adblocker \
  /usr/lib/libayatana-appindicator3.so.1 \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so

# Zen 的 CA 安装和系统代理设置需要调用宿主机的 pkexec / update-ca-certificates；
# 此包装器只负责把系统管理命令转发给宿主机，不修改 Zen 程序本体或网络逻辑。
cat > AppDir/bin/pkexec <<'EOF_PKEXEC'
#!/bin/sh
if [ ! -x /usr/bin/pkexec ]; then
  echo "错误：宿主机缺少 /usr/bin/pkexec。" >&2
  exit 127
fi
if [ "${1:-}" = "update-ca-certificates" ]; then
  if [ ! -x /usr/sbin/update-ca-certificates ]; then
    echo "错误：宿主机缺少 /usr/sbin/update-ca-certificates。" >&2
    exit 127
  fi
  shift
  exec /usr/bin/pkexec /usr/sbin/update-ca-certificates "$@"
fi
exec /usr/bin/pkexec "$@"
EOF_PKEXEC
chmod 755 AppDir/bin/pkexec

quick-sharun --make-appimage
