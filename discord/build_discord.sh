#!/usr/bin/env bash
# 官网 Linux tar.gz 只是安装器。完整 stable 程序从官方更新清单的 full.distro 取得。
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
[[ "$(uname -m)" == x86_64 ]] || { echo '仅支持 x86_64。' >&2; exit 1; }

SOURCE="$SCRIPT_DIR/source"
APPDIR="$SCRIPT_DIR/AppDir"
DIST="$SCRIPT_DIR/dist"
ARCHIVE="$SOURCE/discord-official.tar.gz"
MANIFEST="$SOURCE/manifest.json"
DISTRO="$SOURCE/discord.distro"
HOST="$SOURCE/host"

###### 准备构建环境 ######
# 安装打包工具和官方 Electron 程序需要的图形、声音与证书依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装 GTK3 输入模块，供 AppImage 连接宿主正在运行的 IBus 或 Fcitx5。
"$SCRIPT_DIR/../common/arch/install_packages.sh" ca-certificates nss nspr gtk3 libxss libnotify alsa-lib libpulse libx11 libxcomposite libxdamage libxrandr libxcb libxkbcommon libdrm mesa libglvnd at-spi2-core cups dbus xdg-utils fontconfig ibus fcitx5-gtk brotli

# 清理 Discord 自己的临时内容。
rm -rf -- "$SOURCE" "$APPDIR" "$DIST"
mkdir -p "$SOURCE" "$APPDIR/bin" "$DIST"

###### 获取官方完整程序 ######
# 官网归档只保留桌面入口和图标，不能当作 Discord 程序。
"$SCRIPT_DIR/../common/download/download_file.sh" 'https://discord.com/api/download?platform=linux&format=tar.gz' "$ARCHIVE"
"$SCRIPT_DIR/../common/archive/extract_archive.sh" "$ARCHIVE" "$SOURCE"
[[ -f "$SOURCE/Discord/discord.desktop" && -f "$SOURCE/Discord/discord.png" ]] || {
  echo '官方归档缺少桌面入口或图标。' >&2
  exit 1
}

# 安装器曾把目录叫成 app-1.0.159，包内 build_info.json 却仍是 1.0.158。
# 不再调用 updater_bootstrap，只使用更新清单指向的完整主程序包。
"$SCRIPT_DIR/../common/download/download_file.sh" \
  'https://updates.discord.com/distributions/app/manifests/latest?channel=stable&platform=linux&arch=x64' \
  "$MANIFEST"
VERSION="$(jq -er '.full.host_version | map(tostring) | join(".")' "$MANIFEST")"
DISTRO_URL="$(jq -er '.full.url' "$MANIFEST")"
DISTRO_SHA="$(jq -er '.full.package_sha256' "$MANIFEST")"
[[ "$VERSION" =~ ^[0-9]+([.][0-9]+)+$ ]] || { echo "官方清单版本无效：$VERSION" >&2; exit 1; }
[[ "$DISTRO_URL" == https://*.discordapp.net/distro/app/stable/linux/x64/${VERSION}/full.distro ]] || {
  echo "官方完整包地址与清单版本不一致：$DISTRO_URL" >&2
  exit 1
}
"$SCRIPT_DIR/../common/download/download_file.sh" "$DISTRO_URL" "$DISTRO" "$DISTRO_SHA"

mkdir -p "$HOST"
brotli -dc "$DISTRO" | tar -x -C "$HOST"
[[ -x "$HOST/files/Discord" ]] || { echo '官方完整包缺少 Discord 程序。' >&2; exit 1; }
BUILD_INFO="$HOST/files/resources/build_info.json"
[[ -f "$BUILD_INFO" ]] || { echo '官方完整包缺少 build_info.json。' >&2; exit 1; }
ACTUAL_VERSION="$(jq -er '.version' "$BUILD_INFO")"
[[ "$ACTUAL_VERSION" == "$VERSION" ]] || {
  echo "官方清单版本是 $VERSION，但完整包内程序版本是 $ACTUAL_VERSION；停止发布。" >&2
  exit 1
}
echo "Discord 完整包版本：$ACTUAL_VERSION"

cp -a -- "$HOST/files"/. "$APPDIR/bin/"
install -Dm0644 "$SOURCE/Discord/discord.desktop" "$SOURCE/discord.desktop"
sed -i -e 's|^Exec=.*|Exec=Discord %U|' -e 's|^Icon=.*|Icon=discord|' "$SOURCE/discord.desktop"

###### 封装正式资产 ######
# quick-sharun 自动生成标准 AppRun；Discord 的主程序无需额外启动脚本。
export ARCH=x86_64 VERSION APPNAME=Discord MAIN_BIN=Discord
export ICON="$SOURCE/Discord/discord.png" DESKTOP="$SOURCE/discord.desktop"
export OUTPATH="$DIST" OUTNAME=discord.AppImage NO_STRIP=1 DEPLOY_OPENGL=1
# 将动态加载的 GTK3 输入模块及依赖一起交给 quick-sharun。
quick-sharun "$APPDIR/bin/Discord" /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so /usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so

# 在 AppImage 内生成真实的简体中文 UTF-8 locale，并设置中文语言优先级。
mkdir -p "$APPDIR/lib/locale"
localedef --no-archive -i zh_CN -f UTF-8 "$APPDIR/lib/locale/zh_CN.utf8"
cat >> "$APPDIR/.env" <<'LOCALE'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LOCPATH=${SHARUN_DIR}/lib/locale
LOCALE
quick-sharun --make-appimage

# 只有完整程序封装成功后，才写入 Release 所用的动态版本。
[[ -s "$DIST/discord.AppImage" ]] || { echo 'Discord AppImage 未生成。' >&2; exit 1; }
printf '%s\n' "$VERSION" > "$DIST/version.txt"

# CI 发布前移除同名旧资产；共享上传步骤的 --clobber 遇到已有资产时返回 422。
if [[ -n "${GH_TOKEN:-}" && -n "${GITHUB_REPOSITORY:-}" ]]; then
  if gh release view latest --repo "$GITHUB_REPOSITORY" --json assets --jq '.assets[].name' | grep -Fxq 'discord.AppImage'; then
    gh release delete-asset latest discord.AppImage --repo "$GITHUB_REPOSITORY" --yes
  fi
fi
