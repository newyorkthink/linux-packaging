#!/usr/bin/env bash
# 完整程序和模块都打进 AppImage。启动时不再跑官方下载器。
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
[[ "$(uname -m)" == x86_64 ]] || { echo '仅支持 x86_64。' >&2; exit 1; }

DOWNLOAD="$SCRIPT_DIR/../common/download/download_file.sh"
WORKDIR="$SCRIPT_DIR/source"
APP="$WORKDIR/app"
MODULES="$WORKDIR/modules"

"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# Discord 本体链接这些库；输入法、托盘和打开链接是额外要带走的。
"$SCRIPT_DIR/../common/arch/install_packages.sh" \
  gtk3 nss alsa-lib mesa systemd-libs wayland \
  libappindicator-gtk3 libpulse libnotify libxss cups \
  ibus fcitx5-gtk xdg-utils brotli

rm -rf -- "$WORKDIR" AppDir dist
mkdir -p "$APP" "$MODULES" dist AppDir/bin

"$DOWNLOAD" \
  'https://updates.discord.com/distributions/app/manifests/latest?channel=stable&platform=linux&arch=x64' \
  "$WORKDIR/manifest.json"
VERSION="$(jq -er '.full.host_version | map(tostring) | join(".")' "$WORKDIR/manifest.json")"
HOST_URL="$(jq -er '.full.url' "$WORKDIR/manifest.json")"
HOST_SHA="$(jq -er '.full.package_sha256' "$WORKDIR/manifest.json")"
[[ "$HOST_URL" == https://*.discordapp.net/distro/app/stable/linux/x64/${VERSION}/full.distro ]] || {
  echo "主程序地址与版本不一致：$HOST_URL" >&2
  exit 1
}
"$DOWNLOAD" "$HOST_URL" "$WORKDIR/host.distro" "$HOST_SHA"
brotli -dc "$WORKDIR/host.distro" | tar -x --strip-components=1 -C "$APP"
[[ -x "$APP/Discord" && -f "$APP/resources/build_info.json" ]] || {
  echo '完整包缺少 Discord 或 build_info.json。' >&2
  exit 1
}
ACTUAL_VERSION="$(jq -er '.version' "$APP/resources/build_info.json")"
[[ "$ACTUAL_VERSION" == "$VERSION" ]] || {
  echo "清单版本是 $VERSION，包内版本是 $ACTUAL_VERSION；停止发布。" >&2
  exit 1
}
echo "Discord 主程序版本：$ACTUAL_VERSION"

while IFS=$'\t' read -r name url sha; do
  [[ "$url" == https://*.discordapp.net/distro/app/stable/linux/x64/${VERSION}/${name}/*/full.distro ]] || {
    echo "模块地址不合法：$name $url" >&2
    exit 1
  }
  "$DOWNLOAD" "$url" "$WORKDIR/${name}.distro" "$sha"
  mkdir -p "$MODULES/$name"
  brotli -dc "$WORKDIR/${name}.distro" | tar -x --strip-components=1 -C "$MODULES/$name"
done < <(jq -er '.modules | to_entries[] | [.key, .value.full.url, .value.full.package_sha256] | @tsv' "$WORKDIR/manifest.json")
[[ -f "$MODULES/discord_desktop_core/index.js" && -f "$MODULES/discord_desktop_core/core.asar" ]] || {
  echo '缺少 discord_desktop_core。' >&2
  exit 1
}
jq -c '.modules | with_entries(.value = {installedVersion: .value.full.module_version})' \
  "$WORKDIR/manifest.json" > "$MODULES/installed.json"
mkdir -p "$MODULES/discord_krisp/KMS/logs"
cp -a "$APP"/. AppDir/bin/
cp -a "$MODULES"/. AppDir/share/discord-modules/
mkdir -p AppDir/share
mv AppDir/share/discord-modules "$WORKDIR/discord-modules"
mkdir -p AppDir/share
# modules are copied after quick-sharun so the launcher wrapper is left intact
mkdir -p "$WORKDIR/staged-modules"
cp -a "$MODULES"/. "$WORKDIR/staged-modules/"

cat > "$WORKDIR/discord.desktop" <<'EOF'
[Desktop Entry]
Name=Discord
Comment=All-in-one voice and text chat for gamers
Exec=Discord %U
Icon=discord
Type=Application
Categories=Network;InstantMessaging;
MimeType=x-scheme-handler/discord;
StartupWMClass=discord
EOF

export ARCH=x86_64 VERSION
export ICON="$APP/discord.png" DESKTOP="$WORKDIR/discord.desktop"
export OUTPATH="$SCRIPT_DIR/dist" OUTNAME=discord.AppImage
export DEPLOY_OPENGL=1 NO_STRIP=1
quick-sharun AppDir/bin/Discord \
  AppDir/bin/libffmpeg.so AppDir/bin/libEGL.so AppDir/bin/libGLESv2.so \
  AppDir/bin/libvulkan.so.1 AppDir/bin/libvk_swiftshader.so \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so \
  /usr/lib/libappindicator3.so* \
  /usr/lib/libpulse.so* \
  /usr/lib/libnotify.so* \
  /usr/lib/libXss.so* \
  /usr/lib/libcups.so* \
  /usr/lib/libasound.so* \
  /usr/lib/libwayland-client.so*

mkdir -p AppDir/share/discord-modules AppDir/bin
cp -a "$MODULES"/. AppDir/share/discord-modules/
cat > AppDir/bin/stage-discord-modules.src.hook <<EOF
#!/bin/false
mod_src="\${SHARUN_DIR}/share/discord-modules"
mod_dest="\${XDG_CONFIG_HOME:-\$HOME/.config}/discord/${VERSION}/modules"
if [ ! -f "\$mod_dest/installed.json" ] || ! cmp -s "\$mod_src/installed.json" "\$mod_dest/installed.json"; then
  rm -rf "\$mod_dest"
  mkdir -p "\$mod_dest"
  cp -a "\$mod_src"/. "\$mod_dest"/
fi
mkdir -p "\$mod_dest/discord_krisp/KMS/logs"
EOF

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
