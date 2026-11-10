#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装 AUR 软件包、运行依赖及 DEB 解包工具。
"$SCRIPT_DIR/../common/arch/install_packages.sh" "discord" dpkg gtk3 nss alsa-lib systemd-libs wayland libappindicator-gtk3 libpulse libnotify libxss cups ibus fcitx5-gtk xdg-utils brotli

# 清掉上次的打包目录。
"$SCRIPT_DIR/../common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir dist work
mkdir -p AppDir/bin


# 下载官方当前 DEB。
"$SCRIPT_DIR/../common/download/download_file.sh" "https://discord.com/api/download?platform=linux&format=deb" work/app.deb

# 解包官方 DEB。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" work/app.deb work/unpacked

# 整个程序目录原样放进 AppDir/bin。
cp -a "work/unpacked/usr/share/discord/." AppDir/bin/

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 成品里的应用名。
export APPNAME="Discord"
# 包里的真实程序名。
export MAIN_BIN="Discord"
# 让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS="discord"
# 使用系统里装好的图标。
export ICON="/usr/share/icons/hicolor/256x256/apps/discord.png"
# 使用系统里装好的桌面入口文件。
export DESKTOP="/usr/share/applications/discord.desktop"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME="discord.AppImage"
# 这是 GTK 3 程序。输入模块由 quick-sharun 自己收集。
export DEPLOY_GTK=1
# 本程序专属处理：关闭宿主 OpenGL 驱动的主动部署。
export DEPLOY_OPENGL=0
# 本程序专属处理：关闭宿主 Vulkan 驱动的主动部署。
export DEPLOY_VULKAN=0
# 本仓库兼容处理：保留程序和原生模块的符号。
export NO_STRIP=1

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" package-json "AppDir/bin/resources/build_info.json")"

# 本程序专属处理：下载官方稳定版模块清单。
"$SCRIPT_DIR/../common/download/download_file.sh" \
  'https://updates.discord.com/distributions/app/manifests/latest?channel=stable&platform=linux&arch=x64' \
  work/manifest.json

# 本程序专属处理：提取官方模块的名称、下载地址和 SHA-256。
jq -er '.modules | to_entries[] | [.key, .value.full.url, .value.full.package_sha256] | @tsv' \
  work/manifest.json > work/module-assets.tsv

# 本程序专属处理：创建官方模块存放目录。
mkdir -p work/modules

# 本程序专属处理：逐个下载并校验官方模块，再解包到对应目录。
while IFS=$'\t' read -r name url sha; do
  # 本程序专属处理：校验模块名称和官方稳定版下载地址。
  [[ "$name" =~ ^[A-Za-z0-9_-]+$ && "$url" == https://*.discordapp.net/distro/app/stable/linux/x64/${VERSION}/${name}/*/full.distro ]] || {
    echo "模块名称或下载地址不合法：$name $url" >&2
    exit 1
  }

  # 使用公共下载脚本下载模块并校验 SHA-256。
  "$SCRIPT_DIR/../common/download/download_file.sh" "$url" "work/${name}.distro" "$sha"

  # 使用公共解包脚本提取模块。
  "$SCRIPT_DIR/../common/archive/extract_archive.sh" "work/${name}.distro" "work/module-source/$name"

  # 本程序专属处理：检查模块文件是否完整解包。
  [[ -d "work/module-source/$name/files" ]] || {
    echo "模块缺少 files 目录：$name" >&2
    exit 1
  }

  # 本程序专属处理：创建模块目录并复制完整模块文件。
  mkdir -p "work/modules/$name"
  cp -a "work/module-source/$name/files"/. "work/modules/$name"/
done < work/module-assets.tsv

# 收集程序及其运行依赖。
quick-sharun AppDir/bin/Discord /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so /usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
ENV

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" "dist/discord.AppImage" "$VERSION" dist/version.txt
