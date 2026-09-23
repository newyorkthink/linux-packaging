#!/usr/bin/env bash
# 官方 Arch discord 包已经带启动器和安装器。这里只按 mpv 那样封装 /usr/bin/discord。
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
[[ "$(uname -m)" == x86_64 ]] || { echo '仅支持 x86_64。' >&2; exit 1; }

"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
"$SCRIPT_DIR/../common/arch/install_packages.sh" discord libappindicator-gtk3 libpulse ibus fcitx5-gtk

rm -rf -- AppDir dist
mkdir -p dist

VERSION="$(pacman -Q discord | awk '{print $2}')"
VERSION="${VERSION#*:}"
VERSION="${VERSION%-*}"
[[ -n "$VERSION" ]] || { echo '无法确定 Discord 版本。' >&2; exit 1; }

export ARCH=x86_64 VERSION
export ICON=/usr/share/icons/hicolor/256x256/apps/discord.png
export DESKTOP=/usr/share/applications/discord.desktop
export OUTPATH="$SCRIPT_DIR/dist" OUTNAME=discord.AppImage DEPLOY_OPENGL=1

# 官方启动器会自己下载完整程序和 discord_desktop_core。
quick-sharun /usr/bin/discord /usr/share/discord/updater_bootstrap \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so \
  /usr/lib/libappindicator3.so* \
  /usr/lib/libpulse.so*

mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'LOCALE'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LOCPATH=${SHARUN_DIR}/lib/locale
LOCALE
quick-sharun --make-appimage

[[ -s dist/discord.AppImage ]] || { echo 'Discord AppImage 未生成。' >&2; exit 1; }
printf '%s\n' "$VERSION" > dist/version.txt
