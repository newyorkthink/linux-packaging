#!/usr/bin/env bash
# 官方 Linux tar.gz 现在是在线安装器；构建时先让官方安装器取得完整 stable 程序。
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
[[ "$(uname -m)" == x86_64 ]] || { echo '仅支持 x86_64。' >&2; exit 1; }

SOURCE="$SCRIPT_DIR/source"
APPDIR="$SCRIPT_DIR/AppDir"
DIST="$SCRIPT_DIR/dist"
ARCHIVE="$SOURCE/discord-official.tar.gz"
DOWNLOAD="$SOURCE/installed"

###### 准备构建环境 ######
# 安装打包工具和官方 Electron 程序需要的图形、声音与证书依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
"$SCRIPT_DIR/../common/arch/install_packages.sh" ca-certificates nss nspr gtk3 libxss libnotify alsa-lib libpulse libx11 libxcomposite libxdamage libxrandr libxcb libxkbcommon libdrm mesa libglvnd at-spi2-core cups dbus xdg-utils fontconfig

# 清理 Discord 自己的临时内容，建立官方安装器的隔离下载目录。
rm -rf -- "$SOURCE" "$APPDIR" "$DIST"
mkdir -p "$SOURCE" "$DOWNLOAD" "$APPDIR/bin" "$DIST"

###### 获取官方完整程序 ######
# 下载 Discord 官网 stable Linux 归档；这个归档本身只有在线安装器。
"$SCRIPT_DIR/../common/download/download_file.sh" 'https://discord.com/api/download?platform=linux&format=tar.gz' "$ARCHIVE"
"$SCRIPT_DIR/../common/archive/extract_archive.sh" "$ARCHIVE" "$SOURCE"
[[ -x "$SOURCE/Discord/updater_bootstrap" ]] || { echo '官方归档缺少安装器。' >&2; exit 1; }

# 调用官方 bootstrap 在构建时取得完整 stable 版本，绝不把 2 MB 安装器当作成品。
APP_DIR="$("$SOURCE/Discord/updater_bootstrap" --no-zenity "$DOWNLOAD" stable https://updates.discord.com/)"
[[ "$APP_DIR" =~ ^app-[0-9]+([.][0-9]+)+$ ]] || { echo "安装器返回无效目录：$APP_DIR" >&2; exit 1; }
VERSION="${APP_DIR#app-}"
[[ -x "$DOWNLOAD/$APP_DIR/Discord" ]] || { echo '官方安装器没有下载完整 Discord 程序。' >&2; exit 1; }

# 官方安装目录名与程序资源内声明的版本可能不同；只有真实程序版本一致才发布。
BUILD_INFO="$DOWNLOAD/$APP_DIR/resources/build_info.json"
[[ -f "$BUILD_INFO" ]] || { echo '官方下载内容缺少 build_info.json。' >&2; exit 1; }
ACTUAL_VERSION="$(jq -er '.version' "$BUILD_INFO")"
[[ "$ACTUAL_VERSION" == "$VERSION" ]] || {
  echo "官方更新目录为 $APP_DIR，但包内程序版本是 $ACTUAL_VERSION；停止发布旧版程序。" >&2
  exit 1
}

# 保留官方 Electron 可执行文件、资源和 helper 程序的相对位置。
cp -a -- "$DOWNLOAD/$APP_DIR"/. "$APPDIR/bin/"
install -Dm0644 "$SOURCE/Discord/discord.desktop" "$SOURCE/discord.desktop"
sed -i -e 's|^Exec=.*|Exec=Discord %U|' -e 's|^Icon=.*|Icon=discord|' "$SOURCE/discord.desktop"

###### 封装正式资产 ######
# quick-sharun 自动生成标准 AppRun；Discord 的主程序无需额外启动脚本。
export ARCH=x86_64 VERSION APPNAME=Discord MAIN_BIN=Discord
export ICON="$SOURCE/Discord/discord.png" DESKTOP="$SOURCE/discord.desktop"
export OUTPATH="$DIST" OUTNAME=discord.AppImage NO_STRIP=1 DEPLOY_OPENGL=1
quick-sharun "$APPDIR/bin/Discord"
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
